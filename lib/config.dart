/// Build-time settings, passed with `--dart-define` (see README).
///
/// With no Supabase key the app runs in Demo Mode only: every screen works
/// on-device with simulated data and nothing leaves the phone.
class AppConfig {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://rwoscuilmsvasohkmphu.supabase.co',
  );

  /// The Supabase publishable (anon) key. Public by design, but not committed.
  static const supabaseKey = String.fromEnvironment('SUPABASE_KEY');

  /// The BT39 monitor service (FastAPI) base URL.
  static const bt39Api = String.fromEnvironment(
    'BT39_API',
    defaultValue: 'https://bt39-monitor-service.onrender.com',
  );

  static bool get supabaseEnabled => supabaseKey.isNotEmpty;
}
