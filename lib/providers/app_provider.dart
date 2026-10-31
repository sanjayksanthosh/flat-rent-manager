import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/flat_model.dart';
import '../services/api_service.dart';
import '../services/data_store.dart';

class AppProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  final DataStore _store = DataStore();

  bool _loading = true;
  bool _refreshing = false;
  bool _isOnline = true;
  bool _hydrated = false;
  bool _syncing = false;
  int _writeVersion = 0;
  String? _sessionKey;
  Future<void>? _loadFuture;

  List<Building> _buildings = [];
  List<Flat> _flats = [];
  List<Tenant> _tenants = [];
  List<Lease> _leases = [];
  List<RentPayment> _payments = [];
  List<dynamic> _dueSummary = [];
  Map<String, dynamic> _occupancy = {};
  List<Map<String, dynamic>> _amenitiesCatalog = [];
  String? _error;

  // Fast lookups, rebuilt whenever the collections change.
  final Map<int, Building> _buildingById = {};
  final Map<int, Flat> _flatById = {};
  final Map<int, Tenant> _tenantById = {};
  final Map<int, Lease> _leaseById = {};
  final Map<int, Lease> _activeLeaseByFlat = {};
  final Map<int, List<Lease>> _leasesByFlat = {};
  final Map<int, List<Lease>> _leasesByTenant = {};
  final Map<int, List<RentPayment>> _paymentsByLease = {};
  final Map<int, ({double pendingRent, double advanceAmount})> _duesCache = {};

  bool get loading => _loading;
  bool get refreshing => _refreshing;
  bool get isOnline => _isOnline;
  String? get error => _error;
  List<Building> get buildings => _buildings;
  List<Flat> get flats => _flats;
  List<Tenant> get tenants => _tenants;
  List<Lease> get leases => _leases;
  List<RentPayment> get payments => _payments;
  List<dynamic> get dueSummary => _dueSummary;
  Map<String, dynamic> get occupancy => _occupancy;
  List<Map<String, dynamic>> get amenitiesCatalog => _amenitiesCatalog;

  int get totalBuildings => _buildings.length;
  int get totalFlats => _flats.length;
  int get occupiedFlats => _flats.where((f) => f.status == 'occupied').length;
  int get vacantFlats => _flats.where((f) => f.status == 'vacant').length;
  double get totalMonthlyRent => _leases.fold<double>(0, (s, l) => s + rentFor(l));
  double get pendingRent {
    double total = 0;
    for (var d in _dueSummary) { total += (d['dueAmount'] as num?)?.toDouble() ?? 0; }
    return total;
  }

  void clearError() { _error = null; notifyListeners(); }

  void _reindex() {
    _buildingById.clear();
    _flatById.clear();
    _tenantById.clear();
    _leaseById.clear();
    _activeLeaseByFlat.clear();
    _leasesByFlat.clear();
    _leasesByTenant.clear();
    _paymentsByLease.clear();
    _duesCache.clear();
    for (final b in _buildings) {
      if (b.id != null) _buildingById[b.id!] = b;
    }
    for (final f in _flats) {
      if (f.id != null) _flatById[f.id!] = f;
    }
    for (final t in _tenants) {
      if (t.id != null) _tenantById[t.id!] = t;
    }
    for (final l in _leases) {
      if (l.id != null) _leaseById[l.id!] = l;
      _leasesByFlat.putIfAbsent(l.flatId, () => []).add(l);
      _leasesByTenant.putIfAbsent(l.tenantId, () => []).add(l);
      if (l.moveOutDate == null) _activeLeaseByFlat[l.flatId] = l;
    }
    for (final p in _payments) {
      _paymentsByLease.putIfAbsent(p.leaseId, () => []).add(p);
    }
  }

  Future<void> _syncPendingOps() async {
    if (_syncing) return;
    _syncing = true;
    try {
      final ops = await _store.getPendingOps();
      if (ops.isEmpty) return;
      for (int i = ops.length - 1; i >= 0; i--) {
        try {
          final op = ops[i];
          final data = op['data'] as Map<String, dynamic>;
          switch ('${op['action']}_${op['table']}') {
            case 'insert_building': await _api.createBuilding(Building.fromMap(data)); break;
            case 'update_building': await _api.updateBuilding(Building.fromMap(data)); break;
            case 'delete_building': await _api.deleteBuilding(data['id'] as int); break;
            case 'insert_flat': await _api.createFlat(Flat.fromMap(data)); break;
            case 'update_flat': await _api.updateFlat(Flat.fromMap(data)); break;
            case 'delete_flat': await _api.deleteFlat(data['id'] as int); break;
            case 'insert_tenant': await _api.createTenant(Tenant.fromMap(data)); break;
            case 'update_tenant': await _api.updateTenant(Tenant.fromMap(data)); break;
            case 'delete_tenant': await _api.deleteTenant(data['id'] as int); break;
            case 'insert_lease': await _api.createLease(Lease.fromMap(data)); break;
            case 'moveOut_lease': await _api.moveOut(data['id'] as int, data['moveOutDate'] as String); break;
            case 'insert_payment': await _api.createPayment(RentPayment.fromMap(data)); break;
          }
          await _store.removePendingOp(i);
        } catch (_) {}
      }
    } finally {
      _syncing = false;
    }
  }

  /// Loads local cache first (so the UI paints instantly) and then refreshes
  /// from the server. Network calls are made in parallel.
  Future<void> loadAll() {
    final existing = _loadFuture;
    if (existing != null) return existing;
    final future = _load().whenComplete(() => _loadFuture = null);
    _loadFuture = future;
    return future;
  }

  /// Called when a user session starts. Clears another user's cached data.
  Future<void> bindSession(String key) {
    if (_sessionKey == key) return loadAll();
    _sessionKey = key;
    _buildings = [];
    _flats = [];
    _tenants = [];
    _leases = [];
    _payments = [];
    _dueSummary = [];
    _occupancy = {};
    _amenitiesCatalog = [];
    _hydrated = false;
    _loading = true;
    _refreshing = false;
    _isOnline = true;
    _error = null;
    _writeVersion = 0;
    _reindex();
    return loadAll();
  }

  Future<void> _load() async {
    if (!_hydrated) {
      // Show cached data immediately instead of a blocking spinner.
      if (_buildings.isEmpty && _flats.isEmpty && _tenants.isEmpty && _leases.isEmpty && _payments.isEmpty) {
        _loading = true;
        notifyListeners();
      }
      await _hydrate();
      final hasData = _buildings.isNotEmpty || _flats.isNotEmpty || _tenants.isNotEmpty || _leases.isNotEmpty || _payments.isNotEmpty;
      _loading = !hasData;
      notifyListeners();
    }

    _refreshing = true;
    notifyListeners();

    final versionAtStart = _writeVersion;
    try {
      final results = await Future.wait<Object>([
        _api.getBuildings(),
        _api.getFlats(),
        _api.getTenants(),
        _api.getLeases(),
        _api.getPayments(),
      ]);

      // If the user changed data while this request was in flight, keep the
      // optimistic local data instead of overwriting it with a stale snapshot.
      if (versionAtStart == _writeVersion) {
        _buildings = results[0] as List<Building>;
        _flats = results[1] as List<Flat>;
        _tenants = results[2] as List<Tenant>;
        _leases = results[3] as List<Lease>;
        _payments = results[4] as List<RentPayment>;
        _isOnline = true;
        _error = null;
        _reindex();
        _loading = false;
        notifyListeners();
      }

      // These summaries are derived from data we already have, so compute
      // them locally instead of spending two more round-trips.
      _dueSummary = _computeDueLocally();
      _occupancy = {
        'totalFlats': totalFlats,
        'occupiedFlats': occupiedFlats,
        'vacantFlats': vacantFlats,
      };
      _amenitiesCatalog = await _store.getAmenitiesCatalog();
      _isOnline = true;
      _error = null;

      // Mirror to disk without blocking the UI.
      unawaited(_store.saveAllFromApi(_buildings, _flats, _tenants, _leases, _payments));
      unawaited(_syncPendingOps());
    } catch (_) {
      if (!_hydrated) await _hydrate();
      _isOnline = false;
      _error = 'Offline — showing saved data';
      if (_dueSummary.isEmpty) _dueSummary = _computeDueLocally();
    } finally {
      _loading = false;
      _refreshing = false;
      notifyListeners();
    }
  }

  Future<void> _hydrate() async {
    if (_hydrated) return;
    _hydrated = true;
    try {
      final buildings = await _store.getBuildings();
      final flats = await _store.getFlats();
      final tenants = await _store.getTenants();
      final leases = await _store.getLeases();
      final payments = await _store.getPayments();
      if (_buildings.isEmpty && buildings.isNotEmpty) _buildings = buildings;
      if (_flats.isEmpty && flats.isNotEmpty) _flats = flats;
      if (_tenants.isEmpty && tenants.isNotEmpty) _tenants = tenants;
      if (_leases.isEmpty && leases.isNotEmpty) _leases = leases;
      if (_payments.isEmpty && payments.isNotEmpty) _payments = payments;
      _amenitiesCatalog = await _store.getAmenitiesCatalog();
      _reindex();
      _dueSummary = _computeDueLocally();
      _occupancy = {
        'totalFlats': totalFlats,
        'occupiedFlats': occupiedFlats,
        'vacantFlats': vacantFlats,
      };
    } catch (_) {}
  }

  Future<void> _mirror() async {
    await _store.saveAllFromApi(_buildings, _flats, _tenants, _leases, _payments);
  }

  void _commit(void Function() change) {
    change();
    _writeVersion++;
    _reindex();
    _dueSummary = _computeDueLocally();
    notifyListeners();
    unawaited(_mirror());
  }

  Flat _flatWithStatus(Flat f, String status) => Flat(
        id: f.id,
        buildingId: f.buildingId,
        flatNumber: f.flatNumber,
        floor: f.floor,
        monthlyRent: f.monthlyRent,
        status: status,
        buildingName: f.buildingName,
        tenant: f.tenant,
      );

  // --- Buildings ---
  Future<void> addBuilding(Building b) async {
    Building saved;
    try {
      saved = await _api.createBuilding(b);
      _isOnline = true;
    } catch (_) {
      _isOnline = false;
      saved = await _store.insertBuilding(b);
    }
    _commit(() => _buildings = [..._buildings, saved]);
  }

  Future<void> updateBuilding(Building b) async {
    try {
      await _api.updateBuilding(b);
      _isOnline = true;
    } catch (_) {
      _isOnline = false;
      await _store.updateBuilding(b);
    }
    _commit(() => _buildings = [for (final x in _buildings) if (x.id == b.id) b else x]);
  }

  Future<void> deleteBuilding(int id) async {
    try {
      await _api.deleteBuilding(id);
      _isOnline = true;
    } catch (_) {
      _isOnline = false;
      await _store.deleteBuilding(id);
    }
    _commit(() {
      _buildings = _buildings.where((b) => b.id != id).toList();
      _flats = _flats.where((f) => f.buildingId != id).toList();
    });
  }

  // --- Flats ---
  Future<void> addFlat(Flat f) async {
    Flat saved;
    try {
      saved = await _api.createFlat(f);
      _isOnline = true;
    } catch (_) {
      _isOnline = false;
      saved = await _store.insertFlat(f);
    }
    _commit(() => _flats = [..._flats, saved]);
  }

  Future<void> updateFlat(Flat f) async {
    try {
      await _api.updateFlat(f);
      _isOnline = true;
    } catch (_) {
      _isOnline = false;
      await _store.updateFlat(f);
    }
    final activeLease = f.id != null ? _activeLeaseByFlat[f.id!] : null;
    _commit(() {
      _flats = [for (final x in _flats) if (x.id == f.id) f else x];
      // The flat is the source of truth for rent. Keep the running lease in
      // sync locally so Home, Collect Rent and Reports all show one amount.
      if (activeLease != null) {
        _leases = [for (final l in _leases) if (l.id == activeLease.id) l.copyWith(monthlyRent: f.monthlyRent) else l];
      }
    });
    // Persist the new rent on the lease too (best effort).
    if (activeLease?.id != null) {
      final leaseId = activeLease!.id!;
      unawaited(() async {
        try {
          await _api.updateLeaseRent(leaseId, f.monthlyRent);
          _isOnline = true;
        } catch (_) {
          _isOnline = false;
        }
      }());
    }
  }

  Future<void> deleteFlat(int id) async {
    try {
      await _api.deleteFlat(id);
      _isOnline = true;
    } catch (_) {
      _isOnline = false;
      await _store.deleteFlat(id);
    }
    _commit(() => _flats = _flats.where((f) => f.id != id).toList());
  }

  // --- Tenants ---
  Future<Tenant> addTenant(Tenant t) async {
    Tenant saved;
    try {
      saved = await _api.createTenant(t);
      _isOnline = true;
    } catch (_) {
      _isOnline = false;
      saved = await _store.insertTenant(t);
    }
    _commit(() => _tenants = [..._tenants, saved]);
    return saved;
  }

  Future<void> updateTenant(Tenant t) async {
    // Optimistic: show the change immediately (documents can be large and
    // need a round-trip), then persist in the background.
    _commit(() => _tenants = [for (final x in _tenants) if (x.id == t.id) t else x]);
    try {
      await _api.updateTenant(t);
      _isOnline = true;
    } catch (_) {
      _isOnline = false;
      await _store.updateTenant(t);
    }
    notifyListeners();
  }

  Future<void> deleteTenant(int id) async {
    try {
      await _api.deleteTenant(id);
      _isOnline = true;
    } catch (_) {
      _isOnline = false;
      await _store.deleteTenant(id);
    }
    _commit(() => _tenants = _tenants.where((t) => t.id != id).toList());
  }

  // --- Leases ---
  Future<Lease> createLease(Lease l) async {
    Lease result;
    try {
      result = await _api.createLease(l);
      _isOnline = true;
    } catch (_) {
      _isOnline = false;
      result = await _store.insertLease(l);
    }
    _commit(() {
      _leases = [..._leases, result];
      final i = _flats.indexWhere((f) => f.id == l.flatId);
      if (i != -1) _flats[i] = _flatWithStatus(_flats[i], 'occupied');
    });
    return result;
  }

  Future<void> moveOut(int leaseId, String date) async {
    Lease? updated;
    try {
      updated = await _api.moveOut(leaseId, date);
      _isOnline = true;
    } catch (_) {
      _isOnline = false;
      await _store.moveOutLease(leaseId, date);
      Lease? old;
      for (final l in _leases) {
        if (l.id == leaseId) { old = l; break; }
      }
      if (old != null) {
        updated = Lease(
          id: old.id,
          tenantId: old.tenantId,
          flatId: old.flatId,
          leaseStart: old.leaseStart,
          leaseEnd: old.leaseEnd,
          monthlyRent: old.monthlyRent,
          advanceMonths: old.advanceMonths,
          securityDeposit: old.securityDeposit,
          moveOutDate: date,
          flatNumber: old.flatNumber,
          buildingName: old.buildingName,
          buildingId: old.buildingId,
          tenantName: old.tenantName,
          tenantPhone: old.tenantPhone,
        );
      }
    }
    final result = updated;
    _commit(() {
      if (result != null) {
        _leases = [for (final l in _leases) if (l.id == leaseId) result else l];
        final fi = _flats.indexWhere((f) => f.id == result.flatId);
        if (fi != -1) _flats[fi] = _flatWithStatus(_flats[fi], 'vacant');
      }
    });
  }

  // --- Payments ---
  Future<void> addPayment(RentPayment p) async {
    RentPayment saved;
    try {
      saved = await _api.createPayment(p);
      _isOnline = true;
    } catch (_) {
      _isOnline = false;
      saved = await _store.insertPayment(p);
    }
    _commit(() => _payments = [..._payments, saved]);
  }

  List<Map<String, dynamic>> _computeDueLocally() {
    final result = <int, Map<String, dynamic>>{};
    for (var lease in _leases.where((l) => l.moveOutDate == null)) {
      final tenant = getTenant(lease.tenantId);
      if (tenant == null) continue;
      final flat = getFlat(lease.flatId);
      if (flat == null) continue;
      final due = computeLeaseDues(lease).pendingRent;
      final rent = rentFor(lease);
      if (due > 0) {
        result[lease.tenantId] = {
          'tenantId': lease.tenantId,
          'tenantName': tenant.name,
          'flatNumber': flat.flatNumber,
          'dueAmount': due,
          'monthsDue': rent > 0 ? (due / rent).ceil() : 0,
        };
      }
    }
    return result.values.toList();
  }

  Future<void> retrySync() async {
    _error = null; notifyListeners();
    try {
      await _syncPendingOps();
      await loadAll();
    } catch (e) {
      _error = 'Sync failed — still offline';
      notifyListeners();
    }
  }

  Building? getBuilding(int id) => _buildingById[id];
  Flat? getFlat(int id) => _flatById[id];
  Tenant? getTenant(int id) => _tenantById[id];
  Lease? getLease(int id) => _leaseById[id];

  /// The rent actually charged for a lease.
  ///
  /// The flat holds the current rent the user edits; older leases may still
  /// carry a stale amount, so the flat wins whenever it has a value.
  double rentFor(Lease lease) {
    final flat = _flatById[lease.flatId];
    if (flat != null && flat.monthlyRent > 0) return flat.monthlyRent;
    return lease.monthlyRent;
  }

  Lease? getActiveLeaseByFlat(int flatId) => _activeLeaseByFlat[flatId];
  List<Lease> getLeasesByTenant(int tenantId) => _leasesByTenant[tenantId] ?? const <Lease>[];
  List<Lease> getLeasesByFlat(int flatId) => _leasesByFlat[flatId] ?? const <Lease>[];
  List<Flat> getFlatsByBuilding(int buildingId) => _flats.where((f) => f.buildingId == buildingId).toList();
  List<RentPayment> getPaymentsByLease(int leaseId) => _paymentsByLease[leaseId] ?? const <RentPayment>[];

  double _completedMonthsDue(Lease lease, int startYear, int startMonth, int monthsBeforeCurrent) {
    double due = 0;
    final rent = rentFor(lease);
    final payments = _paymentsByLease[lease.id] ?? const <RentPayment>[];
    for (int i = 0; i < monthsBeforeCurrent; i++) {
      final y = startYear + ((startMonth + i - 1) ~/ 12);
      final mm = ((startMonth + i - 1) % 12) + 1;
      final monthPmts = payments.where((p) => p.month == mm && p.year == y).toList();
      final settled = monthPmts.where((p) => p.settled).toList();
      final discounted = monthPmts.where((p) => p.discount > 0).toList();
      double monthDue;
      if (discounted.isNotEmpty) {
        monthDue = rent - discounted.first.discount;
      } else if (settled.isNotEmpty) {
        monthDue = settled.fold<double>(0, (s, p) => s + p.amount);
      } else {
        monthDue = rent;
      }
      due += monthDue < 0 ? 0 : monthDue;
    }
    return due;
  }

  ({double pendingRent, double advanceAmount}) computeLeaseDues(Lease lease) {
    final id = lease.id;
    if (id != null) {
      final cached = _duesCache[id];
      if (cached != null) return cached;
    }

    final now = DateTime.now();
    final startParts = lease.leaseStart.split('-');
    final startYear = startParts.length >= 3 ? int.tryParse(startParts[0]) ?? now.year : now.year;
    final startMonth = startParts.length >= 2 ? int.tryParse(startParts[1]) ?? 1 : 1;
    final monthsBeforeCurrent = ((now.year - startYear) * 12) + (now.month - startMonth);
    final payments = id != null ? (_paymentsByLease[id] ?? const <RentPayment>[]) : const <RentPayment>[];
    double totalCollected = payments.fold<double>(0, (s, p) => s + p.amountPaid);
    final rentDueForCompletedMonths =
        _completedMonthsDue(lease, startYear, startMonth, monthsBeforeCurrent > 0 ? monthsBeforeCurrent : 0);
    final net = totalCollected - rentDueForCompletedMonths;
    final result = net >= 0
        ? (pendingRent: 0.0, advanceAmount: net)
        : (pendingRent: -net, advanceAmount: 0.0);
    if (id != null) _duesCache[id] = result;
    return result;
  }

  Future<void> addAmenityToCatalog(Map<String, dynamic> amenity) async {
    await _store.addAmenityToCatalog(amenity);
    _amenitiesCatalog = await _store.getAmenitiesCatalog();
    notifyListeners();
  }

  Future<void> removeAmenityFromCatalog(String name) async {
    await _store.removeAmenityFromCatalog(name);
    _amenitiesCatalog = await _store.getAmenitiesCatalog();
    notifyListeners();
  }
}
