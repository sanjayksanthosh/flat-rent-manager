import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/flat_model.dart';
import '../supabase_config.dart';

/// Raised when the database rejects a sign-in (bad password, locked, disabled).
class AuthFailure implements Exception {
  final String message;
  AuthFailure(this.message);

  @override
  String toString() => message;
}

class ApiService {
  /// Id of the signed-in app user, used to stamp `user_id` on new rows.
  static int? currentUserId;

  static SupabaseClient get _client => SupabaseConfig.client;

  static void warmUp() {
    // Managed Supabase; no cold-starts
  }

  // --- Auth (username + password, verified inside Postgres) ---
  Future<Map<String, dynamic>> login(String username, String password) async {
    final res = await _client.rpc('app_login', params: {
      'p_username': username.trim(),
      'p_password': password,
    });
    final data = Map<String, dynamic>.from(res as Map);

    // app_login reports failures in the payload so the attempt counter it
    // writes is not rolled back by an exception.
    if (data['ok'] != true) {
      throw AuthFailure(data['error'] as String? ?? 'Login failed');
    }

    final token = data['token'] as String;
    final user = Map<String, dynamic>.from(data['user'] as Map);

    SupabaseConfig.useToken(token);
    currentUserId = (user['id'] as num).toInt();

    return {'token': token, 'user': user};
  }

  Future<void> logout() async {
    try {
      await _client.rpc('app_logout');
    } catch (_) {
      // The session may already be gone; clearing it locally is enough.
    }
    SupabaseConfig.useToken(null);
    currentUserId = null;
  }

  Future<Map<String, dynamic>> getMe() async {
    final res = await _client.rpc('app_me');
    final user = Map<String, dynamic>.from(res as Map);
    currentUserId = (user['id'] as num).toInt();
    return user;
  }

  Future<void> changePassword({required String currentPassword, required String newPassword}) async {
    await _client.rpc('app_change_password', params: {
      'p_current': currentPassword,
      'p_new': newPassword,
    });
  }

  // --- Admin: Users ---
  Future<List<dynamic>> getUsers() async {
    final data = await _client.rpc('app_admin_list_users');
    return (data as List).cast<dynamic>();
  }

  Future<Map<String, dynamic>> createUser({required String username, required String name, required String password, required String role}) async {
    final res = await _client.rpc('app_admin_create_user', params: {
      'p_username': username.trim(),
      'p_password': password,
      'p_name': name.trim(),
      'p_role': role,
    });
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> updateUser(dynamic id, {String? name, String? role, String? password}) async {
    final res = await _client.rpc('app_admin_update_user', params: {
      'p_id': id,
      'p_name': name,
      'p_role': role,
      'p_password': password,
      'p_is_active': null,
    });
    return Map<String, dynamic>.from(res as Map);
  }

  Future<void> deleteUser(dynamic id) async {
    await _client.rpc('app_admin_delete_user', params: {'p_id': id});
  }

  // --- Buildings ---
  Future<List<Building>> getBuildings() async {
    final data = await _client.from('buildings').select().order('id');
    return (data as List).map((e) => Building.fromMap(Map<String, dynamic>.from(e))).toList();
  }

  Future<Building> createBuilding(Building b) async {
    final map = b.toMap();
    map.remove('id');
    map['user_id'] = currentUserId!;
    final res = await _client.from('buildings').insert(map).select().single();
    return Building.fromMap(Map<String, dynamic>.from(res));
  }

  Future<Building> updateBuilding(Building b) async {
    final map = b.toMap();
    map['updatedAt'] = DateTime.now().toIso8601String();
    final res = await _client.from('buildings').update(map).eq('id', b.id!).select().single();
    return Building.fromMap(Map<String, dynamic>.from(res));
  }

  Future<void> deleteBuilding(int id) async {
    await _client.from('buildings').delete().eq('id', id);
  }

  // --- Flats ---
  Future<List<Flat>> getFlats({int? buildingId}) async {
    dynamic data;
    try {
      var q = _client.from('flats').select('*, buildings("buildingName")');
      if (buildingId != null) q = q.eq('buildingId', buildingId);
      data = await q.order('id');
    } catch (_) {
      var q = _client.from('flats').select('*');
      if (buildingId != null) q = q.eq('buildingId', buildingId);
      data = await q.order('id');
    }

    return (data as List).map((e) {
      final m = Map<String, dynamic>.from(e);
      if (m['buildings'] is Map) {
        m['buildingName'] = m['buildings']['buildingName'];
      }
      return Flat.fromMap(m);
    }).toList();
  }

  Future<List<Flat>> getFlatsByBuilding(int buildingId) async {
    return getFlats(buildingId: buildingId);
  }

  Future<Flat> getFlat(int id) async {
    Map<String, dynamic> m;
    try {
      final res = await _client.from('flats').select('*, buildings("buildingName")').eq('id', id).single();
      m = Map<String, dynamic>.from(res);
      if (m['buildings'] is Map) {
        m['buildingName'] = m['buildings']['buildingName'];
      }
    } catch (_) {
      final res = await _client.from('flats').select('*').eq('id', id).single();
      m = Map<String, dynamic>.from(res);
    }
    return Flat.fromMap(m);
  }

  Future<Flat> createFlat(Flat f) async {
    final map = f.toMap();
    map.remove('id');
    map.remove('buildingName');
    map.remove('tenant');
    map['user_id'] = currentUserId!;
    final res = await _client.from('flats').insert(map).select().single();
    return Flat.fromMap(Map<String, dynamic>.from(res));
  }

  Future<Flat> updateFlat(Flat f) async {
    final map = f.toMap();
    map.remove('buildingName');
    map.remove('tenant');
    map['updatedAt'] = DateTime.now().toIso8601String();
    final res = await _client.from('flats').update(map).eq('id', f.id!).select().single();
    return Flat.fromMap(Map<String, dynamic>.from(res));
  }

  Future<void> deleteFlat(int id) async {
    await _client.from('flats').delete().eq('id', id);
  }

  // --- Tenants ---
  Future<List<Tenant>> getTenants() async {
    final data = await _client.from('tenants').select().order('id');
    return (data as List).map((e) => Tenant.fromMap(Map<String, dynamic>.from(e))).toList();
  }

  Future<Tenant> getTenant(int id) async {
    final res = await _client.from('tenants').select().eq('id', id).single();
    return Tenant.fromMap(Map<String, dynamic>.from(res));
  }

  Future<Tenant> createTenant(Tenant t) async {
    final map = t.toMap();
    map.remove('id');
    map.remove('leases');
    map['user_id'] = currentUserId!;
    final res = await _client.from('tenants').insert(map).select().single();
    return Tenant.fromMap(Map<String, dynamic>.from(res));
  }

  Future<Tenant> updateTenant(Tenant t) async {
    final map = t.toMap();
    map.remove('leases');
    map['updatedAt'] = DateTime.now().toIso8601String();
    final res = await _client.from('tenants').update(map).eq('id', t.id!).select().single();
    return Tenant.fromMap(Map<String, dynamic>.from(res));
  }

  Future<void> deleteTenant(int id) async {
    await _client.from('tenants').delete().eq('id', id);
  }

  // --- Leases ---
  Future<List<Lease>> getLeases() async {
    dynamic data;
    try {
      data = await _client.from('leases').select('*, tenants(name, phone, address), flats("flatNumber", "buildingId", buildings("buildingName"))').order('id');
    } catch (_) {
      data = await _client.from('leases').select('*').order('id');
    }

    return (data as List).map((e) {
      final m = Map<String, dynamic>.from(e);
      if (m['tenants'] is Map) {
        m['tenantName'] = m['tenants']['name'];
        m['tenantPhone'] = m['tenants']['phone'];
        m['tenantAddress'] = m['tenants']['address'];
      }
      if (m['flats'] is Map) {
        m['flatNumber'] = m['flats']['flatNumber'];
        m['buildingId'] = m['flats']['buildingId'];
        if (m['flats']['buildings'] is Map) {
          m['buildingName'] = m['flats']['buildings']['buildingName'];
        }
      }
      return Lease.fromMap(m);
    }).toList();
  }

  Future<Lease> getLease(int id) async {
    Map<String, dynamic> m;
    try {
      final res = await _client.from('leases').select('*, tenants(name, phone, address), flats("flatNumber", "buildingId", buildings("buildingName"))').eq('id', id).single();
      m = Map<String, dynamic>.from(res);
      if (m['tenants'] is Map) {
        m['tenantName'] = m['tenants']['name'];
        m['tenantPhone'] = m['tenants']['phone'];
        m['tenantAddress'] = m['tenants']['address'];
      }
      if (m['flats'] is Map) {
        m['flatNumber'] = m['flats']['flatNumber'];
        m['buildingId'] = m['flats']['buildingId'];
        if (m['flats']['buildings'] is Map) {
          m['buildingName'] = m['flats']['buildings']['buildingName'];
        }
      }
    } catch (_) {
      final res = await _client.from('leases').select('*').eq('id', id).single();
      m = Map<String, dynamic>.from(res);
    }
    return Lease.fromMap(m);
  }

  Future<Lease> getLeaseByFlat(int flatId) async {
    final res = await _client.from('leases').select('*').eq('flatId', flatId).filter('moveOutDate', 'is', null).maybeSingle();
    if (res == null) throw Exception('No active lease found for flat $flatId');
    return Lease.fromMap(Map<String, dynamic>.from(res));
  }

  Future<Lease> createLease(Lease l) async {
    final map = l.toMap();
    map.remove('id');
    map.remove('tenantName');
    map.remove('tenantPhone');
    map.remove('tenantAddress');
    map.remove('flatNumber');
    map.remove('buildingName');
    map.remove('buildingId');
    map['user_id'] = currentUserId!;
    final res = await _client.from('leases').insert(map).select().single();
    await _client.from('flats').update({'status': 'occupied'}).eq('id', l.flatId);
    return Lease.fromMap(Map<String, dynamic>.from(res));
  }

  Future<Lease> updateLeaseRent(int leaseId, double monthlyRent) async {
    final res = await _client.from('leases').update({
      'monthlyRent': monthlyRent,
      'updatedAt': DateTime.now().toIso8601String(),
    }).eq('id', leaseId).select().single();
    return Lease.fromMap(Map<String, dynamic>.from(res));
  }

  Future<Lease> moveOut(int leaseId, String moveOutDate) async {
    final res = await _client.from('leases').update({
      'moveOutDate': moveOutDate,
      'updatedAt': DateTime.now().toIso8601String(),
    }).eq('id', leaseId).select().single();
    final flatId = res['flatId'];
    if (flatId != null) {
      await _client.from('flats').update({'status': 'vacant'}).eq('id', flatId);
    }
    return Lease.fromMap(Map<String, dynamic>.from(res));
  }

  Future<void> deleteLease(int id) async {
    await _client.from('leases').delete().eq('id', id);
  }

  // --- Payments ---
  Future<List<RentPayment>> getPayments({int? month, int? year, int? buildingId, String? status, int? leaseId}) async {
    dynamic data;
    try {
      var q = _client.from('rent_payments').select('*, leases("tenantId", "flatId", tenants(name), flats("flatNumber", "buildingId", buildings("buildingName")))');
      if (month != null) q = q.eq('month', month);
      if (year != null) q = q.eq('year', year);
      if (leaseId != null) q = q.eq('leaseId', leaseId);
      if (status != null && status != 'all') q = q.eq('status', status);
      data = await q.order('id', ascending: false);
    } catch (_) {
      var q = _client.from('rent_payments').select('*');
      if (month != null) q = q.eq('month', month);
      if (year != null) q = q.eq('year', year);
      if (leaseId != null) q = q.eq('leaseId', leaseId);
      if (status != null && status != 'all') q = q.eq('status', status);
      data = await q.order('id', ascending: false);
    }

    return (data as List).map((e) {
      final m = Map<String, dynamic>.from(e);
      if (m['leases'] is Map) {
        m['tenantId'] = m['leases']['tenantId'];
        m['flatId'] = m['leases']['flatId'];
        if (m['leases']['tenants'] is Map) {
          m['tenantName'] = m['leases']['tenants']['name'];
        }
        if (m['leases']['flats'] is Map) {
          m['flatNumber'] = m['leases']['flats']['flatNumber'];
          m['buildingId'] = m['leases']['flats']['buildingId'];
          if (m['leases']['flats']['buildings'] is Map) {
            m['buildingName'] = m['leases']['flats']['buildings']['buildingName'];
          }
        }
      }
      return RentPayment.fromMap(m);
    }).where((p) {
      if (buildingId != null && p.buildingId != null && p.buildingId != buildingId) return false;
      return true;
    }).toList();
  }

  Future<RentPayment> createPayment(RentPayment p) async {
    final map = p.toMap();
    map.remove('id');
    map.remove('tenantName');
    map.remove('flatNumber');
    map.remove('buildingName');
    map['user_id'] = currentUserId!;
    final res = await _client.from('rent_payments').insert(map).select().single();
    return RentPayment.fromMap(Map<String, dynamic>.from(res));
  }

  Future<List<dynamic>> getDueSummary() async {
    try {
      final leases = await getLeases();
      final active = leases.where((l) => l.moveOutDate == null).toList();
      final summary = <Map<String, dynamic>>[];
      for (final l in active) {
        final p = await getPayments(leaseId: l.id);
        double paid = 0;
        for (var pay in p) {
          paid += pay.amountPaid;
        }
        final due = (l.monthlyRent - paid).clamp(0.0, double.infinity);
        summary.add({
          'leaseId': l.id,
          'tenantName': l.tenantName,
          'flatNumber': l.flatNumber,
          'buildingName': l.buildingName,
          'monthlyRent': l.monthlyRent,
          'dueAmount': due,
        });
      }
      return summary;
    } catch (_) {
      return [];
    }
  }

  Future<List<dynamic>> getMonthlyReport({int? buildingId, required int month, required int year, String status = 'all', String search = ''}) async {
    final payments = await getPayments(month: month, year: year, buildingId: buildingId, status: status == 'all' ? null : status);
    final list = payments.map((p) => p.toMap()).toList();
    if (search.isEmpty) return list;
    final s = search.toLowerCase();
    return list.where((m) {
      final name = (m['tenantName'] ?? '').toString().toLowerCase();
      final flat = (m['flatNumber'] ?? '').toString().toLowerCase();
      return name.contains(s) || flat.contains(s);
    }).toList();
  }

  Future<List<dynamic>> getLeaseExpiry(int days) async {
    final leases = await getLeases();
    final now = DateTime.now();
    final cutoff = now.add(Duration(days: days));
    return leases.where((l) {
      if (l.moveOutDate != null) return false;
      final end = DateTime.tryParse(l.leaseEnd);
      if (end == null) return false;
      return end.isAfter(now) && end.isBefore(cutoff);
    }).map((l) => l.toMap()).toList();
  }

  Future<Map<String, dynamic>> getOccupancy() async {
    try {
      final flats = await getFlats();
      final total = flats.length;
      final occupied = flats.where((f) => f.status == 'occupied').length;
      final vacant = total - occupied;
      final rate = total == 0 ? 0 : (occupied / total * 100).round();
      return {
        'totalFlats': total,
        'occupiedFlats': occupied,
        'vacantFlats': vacant,
        'occupancyRate': rate,
      };
    } catch (_) {
      return {'totalFlats': 0, 'occupiedFlats': 0, 'vacantFlats': 0, 'occupancyRate': 0};
    }
  }
}
