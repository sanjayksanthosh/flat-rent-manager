import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/api_service.dart';
import '../services/data_store.dart';
import '../supabase_config.dart';

/// Session state for the database-backed login.
///
/// The only credential kept on the device is the opaque session token returned
/// by `app_login`. It is stored in SharedPreferences and replayed on startup;
/// the server decides whether it is still valid.
class AuthProvider extends ChangeNotifier {
  static const String _tokenKey = 'auth.session.token';

  final ApiService _api = ApiService();
  final DataStore _store = DataStore();

  Map<String, dynamic>? _user;
  String? _token;
  bool _restoring = true;

  Map<String, dynamic>? get user => _user;
  String? get token => _token;
  bool get restoring => _restoring;
  bool get isLoggedIn => _token != null && _user != null;
  bool get isAdmin => _user?['role'] == 'admin';
  bool get mustChangePassword => _user?['mustChangePassword'] == true;

  String get username => _user?['username'] as String? ?? '';

  String get displayName {
    final name = _user?['name'] as String?;
    return (name == null || name.isEmpty) ? username : name;
  }

  Future<void> restore() async {
    _restoring = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_tokenKey);

      if (saved != null && saved.isNotEmpty) {
        SupabaseConfig.useToken(saved);
        _token = saved;

        // Throws when the token was revoked or has expired.
        final me = await _api.getMe();
        _applyUser(me);
      }
    } catch (_) {
      await _clearSession();
    }

    _restoring = false;
    notifyListeners();
  }

  Future<String?> login(String username, String password) async {
    if (username.trim().isEmpty || password.isEmpty) {
      return 'Username and password are required';
    }

    try {
      final res = await _api.login(username, password);
      _token = res['token'] as String;
      _applyUser(Map<String, dynamic>.from(res['user'] as Map));

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, _token!);

      notifyListeners();
      return null;
    } on AuthFailure catch (e) {
      return e.message;
    } on PostgrestException catch (e) {
      return e.message;
    } catch (e) {
      return 'Cannot reach the server. Check your connection and try again.';
    }
  }

  Future<void> logout() async {
    await _api.logout();
    await _clearSession();
    notifyListeners();
  }

  /// Changes the password of the signed-in user and refreshes the profile.
  Future<String?> changePassword(String currentPassword, String newPassword) async {
    try {
      await _api.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      final me = await _api.getMe();
      _applyUser(me);
      notifyListeners();
      return null;
    } on PostgrestException catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not change the password. Try again.';
    }
  }

  void _applyUser(Map<String, dynamic> me) {
    _user = me;
    _store.activateForUser('${me['id']}', username);
  }

  Future<void> _clearSession() async {
    _token = null;
    _user = null;
    ApiService.currentUserId = null;
    SupabaseConfig.useToken(null);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
    } catch (_) {}
  }
}
