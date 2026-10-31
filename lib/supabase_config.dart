import 'package:supabase_flutter/supabase_flutter.dart';

/// Connection details for the Supabase project.
///
/// The app does not use Supabase Auth. Sign-in happens inside Postgres
/// (`app_login`), and every request afterwards carries the session token in the
/// [tokenHeader] header. Row level security reads that header through
/// `app.session_user_id()` to decide which rows the caller may see.
class SupabaseConfig {
  static const String url = 'https://jinlgznwppfvzpmabbgm.supabase.co';
  static const String publishableKey =
      'sb_publishable_MZE-13EEbINiJmf9fwRb3Q_Q3UVL2cX';

  static const String tokenHeader = 'x-app-token';

  static SupabaseClient get client => Supabase.instance.client;

  /// Attaches [token] to every subsequent request, or clears it when null.
  static void useToken(String? token) {
    client.headers = (token == null || token.isEmpty)
        ? const <String, String>{}
        : <String, String>{tokenHeader: token};
  }
}
