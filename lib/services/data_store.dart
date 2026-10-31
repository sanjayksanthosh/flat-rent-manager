import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/flat_model.dart';

class DataStore {
  static final DataStore _instance = DataStore._internal();
  factory DataStore() => _instance;
  DataStore._internal();

  List<Building> _buildings = [];
  List<Flat> _flats = [];
  List<Tenant> _tenants = [];
  List<Lease> _leases = [];
  List<RentPayment> _payments = [];
  List<Map<String, dynamic>> _pendingOps = [];
  List<Map<String, dynamic>> _amenitiesCatalog = [];
  int _bSeq = 0, _fSeq = 0, _tSeq = 0, _lSeq = 0, _pSeq = 0;
  bool _loaded = false;
  bool _prefsOk = true;
  String _namespace = 'default';
  Future<void> _persistQueue = Future.value();

  String _k(String key) => '${_namespace}_$key';

  void activateForUser(String userId, String username) {
    _namespace = '$userId';
    _buildings = [];
    _flats = [];
    _tenants = [];
    _leases = [];
    _payments = [];
    _pendingOps = [];
    _amenitiesCatalog = [];
    _bSeq = 0; _fSeq = 0; _tSeq = 0; _lSeq = 0; _pSeq = 0;
    _loaded = false;
    _prefsOk = true;
  }

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    if (!_prefsOk) { _loaded = true; return; }
    try {
      final prefs = await SharedPreferences.getInstance();
      _buildings = _decodeList(prefs.getString(_k('buildings')), Building.fromMap);
      _flats = _decodeList(prefs.getString(_k('flats')), Flat.fromMap);
      _tenants = _decodeList(prefs.getString(_k('tenants')), Tenant.fromMap);
      _leases = _decodeList(prefs.getString(_k('leases')), Lease.fromMap);
      _payments = _decodeList(prefs.getString(_k('payments')), RentPayment.fromMap);
      _pendingOps = _decodeListRaw(prefs.getString(_k('pendingOps')));
      _amenitiesCatalog = _decodeListRaw(prefs.getString(_k('amenitiesCatalog')));
      _bSeq = prefs.getInt(_k('bSeq')) ?? _buildings.fold(0, (m, b) => b.id != null && b.id! > m ? b.id! : m);
      _fSeq = prefs.getInt(_k('fSeq')) ?? _flats.fold(0, (m, f) => f.id != null && f.id! > m ? f.id! : m);
      _tSeq = prefs.getInt(_k('tSeq')) ?? _tenants.fold(0, (m, t) => t.id != null && t.id! > m ? t.id! : m);
      _lSeq = prefs.getInt(_k('lSeq')) ?? _leases.fold(0, (m, l) => l.id != null && l.id! > m ? l.id! : m);
      _pSeq = prefs.getInt(_k('pSeq')) ?? _payments.fold(0, (m, p) => p.id != null && p.id! > m ? p.id! : m);
    } catch (_) { _prefsOk = false; }
    _loaded = true;
  }

  List<T> _decodeList<T>(String? json, T Function(Map<String, dynamic>) fromMap) {
    if (json == null || json.isEmpty) return [];
    return (jsonDecode(json) as List).map((e) => fromMap(e as Map<String, dynamic>)).toList();
  }

  List<Map<String, dynamic>> _decodeListRaw(String? json) {
    if (json == null || json.isEmpty) return [];
    return (jsonDecode(json) as List).cast<Map<String, dynamic>>();
  }

  Future<void> _persist() async {
    if (!_prefsOk) return;
    // Chain writes so overlapping saves don't race each other.
    final ns = _namespace;
    final previous = _persistQueue;
    final next = previous.then((_) => _writeNow(ns));
    _persistQueue = next.catchError((_) {});
    return next;
  }

  Future<void> _writeNow(String ns) async {
    if (!_prefsOk || ns != _namespace) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      // Write all keys in one parallel batch instead of one await per key.
      await Future.wait<Object?>([
        prefs.setString(_k('buildings'), jsonEncode(_buildings.map((b) => b.toMap()).toList())),
        prefs.setString(_k('flats'), jsonEncode(_flats.map((f) => f.toMap()).toList())),
        prefs.setString(_k('tenants'), jsonEncode(_tenants.map((t) => t.toMap()).toList())),
        prefs.setString(_k('leases'), jsonEncode(_leases.map((l) => l.toMap()).toList())),
        prefs.setString(_k('payments'), jsonEncode(_payments.map((p) => p.toMap()).toList())),
        prefs.setString(_k('pendingOps'), jsonEncode(_pendingOps)),
        prefs.setString(_k('amenitiesCatalog'), jsonEncode(_amenitiesCatalog)),
        prefs.setInt(_k('bSeq'), _bSeq),
        prefs.setInt(_k('fSeq'), _fSeq),
        prefs.setInt(_k('tSeq'), _tSeq),
        prefs.setInt(_k('lSeq'), _lSeq),
        prefs.setInt(_k('pSeq'), _pSeq),
      ]);
    } catch (_) { _prefsOk = false; }
  }

  // --- Buildings ---
  Future<List<Building>> getBuildings() async { await _ensureLoaded(); return List.unmodifiable(_buildings); }
  Future<Building?> getBuilding(int id) async { await _ensureLoaded(); try { return _buildings.firstWhere((b) => b.id == id); } catch (_) { return null; } }
  Future<Building> insertBuilding(Building b) async {
    await _ensureLoaded();
    final n = Building(id: ++_bSeq, buildingName: b.buildingName, address: b.address, area: b.area, caretakerName: b.caretakerName, caretakerPhone: b.caretakerPhone, securityPhone: b.securityPhone);
    _buildings.add(n); _addPendingOp('insert', 'building', n.toMap()); await _persist(); return n;
  }
  Future<void> updateBuilding(Building b) async { await _ensureLoaded(); final i = _buildings.indexWhere((x) => x.id == b.id); if (i != -1) { _buildings[i] = b; _addPendingOp('update', 'building', b.toMap()); await _persist(); } }
  Future<void> deleteBuilding(int id) async { await _ensureLoaded(); _buildings.removeWhere((b) => b.id == id); _addPendingOp('delete', 'building', {'id': id}); await _persist(); }

  // --- Flats ---
  Future<List<Flat>> getFlats({int? buildingId}) async {
    await _ensureLoaded();
    if (buildingId != null) return _flats.where((f) => f.buildingId == buildingId).toList();
    return List.unmodifiable(_flats);
  }
  Future<Flat?> getFlat(int id) async { await _ensureLoaded(); try { return _flats.firstWhere((f) => f.id == id); } catch (_) { return null; } }
  Future<Flat> insertFlat(Flat f) async {
    await _ensureLoaded();
    final n = Flat(id: ++_fSeq, buildingId: f.buildingId, flatNumber: f.flatNumber, floor: f.floor, monthlyRent: f.monthlyRent, status: f.status);
    _flats.add(n); _addPendingOp('insert', 'flat', n.toMap()); await _persist(); return n;
  }
  Future<void> updateFlat(Flat f) async { await _ensureLoaded(); final i = _flats.indexWhere((x) => x.id == f.id); if (i != -1) { _flats[i] = f; _addPendingOp('update', 'flat', f.toMap()); await _persist(); } }
  Future<void> deleteFlat(int id) async { await _ensureLoaded(); _flats.removeWhere((f) => f.id == id); _addPendingOp('delete', 'flat', {'id': id}); await _persist(); }

  // --- Tenants ---
  Future<List<Tenant>> getTenants() async { await _ensureLoaded(); return List.unmodifiable(_tenants); }
  Future<Tenant?> getTenant(int id) async { await _ensureLoaded(); try { return _tenants.firstWhere((t) => t.id == id); } catch (_) { return null; } }
  Future<Tenant> insertTenant(Tenant t) async {
    await _ensureLoaded();
    final n = Tenant(id: ++_tSeq, name: t.name, phone: t.phone, phone2: t.phone2, ksebNo: t.ksebNo, address: t.address, idProof: t.idProof, documents: t.documents, amenities: t.amenities);
    _tenants.add(n); _addPendingOp('insert', 'tenant', n.toMap()); await _persist(); return n;
  }
  Future<void> updateTenant(Tenant t) async { await _ensureLoaded(); final i = _tenants.indexWhere((x) => x.id == t.id); if (i != -1) { _tenants[i] = t; _addPendingOp('update', 'tenant', t.toMap()); await _persist(); } }
  Future<void> deleteTenant(int id) async { await _ensureLoaded(); _tenants.removeWhere((t) => t.id == id); _addPendingOp('delete', 'tenant', {'id': id}); await _persist(); }

  // --- Leases ---
  Future<List<Lease>> getLeases() async { await _ensureLoaded(); return List.unmodifiable(_leases); }
  Future<Lease?> getLease(int id) async { await _ensureLoaded(); try { return _leases.firstWhere((l) => l.id == id); } catch (_) { return null; } }
  Future<Lease?> getActiveLeaseByFlat(int flatId) async { await _ensureLoaded(); try { return _leases.firstWhere((l) => l.flatId == flatId && l.moveOutDate == null); } catch (_) { return null; } }
  Future<Lease> insertLease(Lease l) async {
    await _ensureLoaded();
    final flat = _flats.firstWhere((f) => f.id == l.flatId, orElse: () => Flat(buildingId: 0, flatNumber: ''));
    final bld = _buildings.firstWhere((b) => b.id == flat.buildingId, orElse: () => Building(buildingName: ''));
    final tenant = _tenants.firstWhere((t) => t.id == l.tenantId, orElse: () => Tenant(name: '', phone: ''));
    final n = Lease(id: ++_lSeq, tenantId: l.tenantId, flatId: l.flatId, leaseStart: l.leaseStart, leaseEnd: l.leaseEnd, monthlyRent: l.monthlyRent, advanceMonths: l.advanceMonths, securityDeposit: l.securityDeposit, flatNumber: flat.flatNumber.isNotEmpty ? flat.flatNumber : l.flatNumber, buildingName: bld.buildingName.isNotEmpty ? bld.buildingName : l.buildingName, buildingId: flat.buildingId != 0 ? flat.buildingId : l.buildingId, tenantName: tenant.name.isNotEmpty ? tenant.name : l.tenantName, tenantPhone: tenant.phone.isNotEmpty ? tenant.phone : l.tenantPhone);
    _leases.add(n);
    final fi = _flats.indexWhere((f) => f.id == l.flatId);
    if (fi != -1) _flats[fi] = Flat(id: _flats[fi].id, buildingId: _flats[fi].buildingId, flatNumber: _flats[fi].flatNumber, floor: _flats[fi].floor, monthlyRent: _flats[fi].monthlyRent, status: 'occupied');
    _addPendingOp('insert', 'lease', n.toMap()); await _persist(); return n;
  }
  Future<void> moveOutLease(int leaseId, String date) async {
    await _ensureLoaded();
    final i = _leases.indexWhere((l) => l.id == leaseId);
    if (i != -1) {
      final old = _leases[i];
      _leases[i] = Lease(id: old.id, tenantId: old.tenantId, flatId: old.flatId, leaseStart: old.leaseStart, leaseEnd: old.leaseEnd, monthlyRent: old.monthlyRent, advanceMonths: old.advanceMonths, securityDeposit: old.securityDeposit, moveOutDate: date, flatNumber: old.flatNumber, buildingName: old.buildingName, buildingId: old.buildingId, tenantName: old.tenantName, tenantPhone: old.tenantPhone);
      final fi = _flats.indexWhere((f) => f.id == old.flatId);
      if (fi != -1) _flats[fi] = Flat(id: _flats[fi].id, buildingId: _flats[fi].buildingId, flatNumber: _flats[fi].flatNumber, floor: _flats[fi].floor, monthlyRent: _flats[fi].monthlyRent, status: 'vacant');
      _addPendingOp('moveOut', 'lease', {'id': leaseId, 'moveOutDate': date}); await _persist();
    }
  }

  // --- Payments ---
  Future<List<RentPayment>> getPayments({int? leaseId}) async {
    await _ensureLoaded();
    var r = _payments.toList();
    if (leaseId != null) r = r.where((p) => p.leaseId == leaseId).toList();
    r.sort((a, b) => b.year != a.year ? b.year - a.year : b.month - a.month);
    return r;
  }
  Future<RentPayment> insertPayment(RentPayment p) async {
    await _ensureLoaded();
    final n = RentPayment(id: ++_pSeq, leaseId: p.leaseId, month: p.month, year: p.year, amount: p.amount, amountPaid: p.amountPaid, balance: p.balance, paymentDate: p.paymentDate, paymentMethod: p.paymentMethod, status: p.status, settled: p.settled, discount: p.discount, tenantId: p.tenantId, flatId: p.flatId, buildingId: p.buildingId, tenantName: p.tenantName, flatNumber: p.flatNumber, buildingName: p.buildingName, monthlyRent: p.monthlyRent);
    _payments.add(n); _addPendingOp('insert', 'payment', n.toMap()); await _persist(); return n;
  }

  // --- Pending Ops ---
  void _addPendingOp(String action, String table, Map<String, dynamic> data) {
    _pendingOps.add({'action': action, 'table': table, 'data': data, 'timestamp': DateTime.now().toIso8601String()});
  }

  Future<List<Map<String, dynamic>>> getPendingOps() async { await _ensureLoaded(); return List.unmodifiable(_pendingOps); }

  Future<void> clearPendingOps() async { await _ensureLoaded(); _pendingOps.clear(); await _persist(); }

  Future<void> removePendingOp(int index) async { await _ensureLoaded(); if (index < _pendingOps.length) { _pendingOps.removeAt(index); await _persist(); } }

  // --- Amenities Catalog ---
  Future<List<Map<String, dynamic>>> getAmenitiesCatalog() async { await _ensureLoaded(); return List.unmodifiable(_amenitiesCatalog); }
  Future<void> addAmenityToCatalog(Map<String, dynamic> amenity) async {
    await _ensureLoaded();
    if (!_amenitiesCatalog.any((a) => a['name'] == amenity['name'])) {
      _amenitiesCatalog.add(amenity);
      await _persist();
    }
  }
  Future<void> removeAmenityFromCatalog(String name) async {
    await _ensureLoaded();
    _amenitiesCatalog.removeWhere((a) => a['name'] == name);
    await _persist();
  }

  // --- Bulk save from API ---
  Future<void> saveAllFromApi(List<Building> buildings, List<Flat> flats, List<Tenant> tenants, List<Lease> leases, List<RentPayment> payments) async {
    await _ensureLoaded();
    _buildings = buildings;
    _flats = flats;
    _tenants = tenants;
    _leases = leases;
    _payments = payments;
    _bSeq = _buildings.fold(_bSeq, (m, b) => b.id != null && b.id! > m ? b.id! : m);
    _fSeq = _flats.fold(_fSeq, (m, f) => f.id != null && f.id! > m ? f.id! : m);
    _tSeq = _tenants.fold(_tSeq, (m, t) => t.id != null && t.id! > m ? t.id! : m);
    _lSeq = _leases.fold(_lSeq, (m, l) => l.id != null && l.id! > m ? l.id! : m);
    _pSeq = _payments.fold(_pSeq, (m, p) => p.id != null && p.id! > m ? p.id! : m);
    await _persist();
  }
}
