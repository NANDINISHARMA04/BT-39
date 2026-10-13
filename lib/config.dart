/// Build-time settings, passed with `--dart-define` (see README).
///
/// The app is a thin client: every decision, simulation and record lives on
/// the PulseOS service (the BT39 monitor service), including Demo Mode. The
/// only settings are where that service is and which Supabase project signs
/// people in. Both have public defaults, so the app runs with no flags.
class AppConfig {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://rwoscuilmsvasohkmphu.supabase.co',
  );

  /// The Supabase publishable (anon) key. Public by design: it only names the
  /// project, and row-level security decides what a signed-in person can read.
  /// Pass `--dart-define=SUPABASE_KEY=...` to use another project.
  static const supabaseKey = String.fromEnvironment(
    'SUPABASE_KEY',
    defaultValue: 'sb_publishable_Nh8lioG55N6r4-0h9JvEcw_V8mKq0Ta',
  );

  /// The BT39 monitor service (FastAPI) base URL. The PulseOS routes are under
  /// `/v1/pulse` on it.
  static const bt39Api = String.fromEnvironment(
    'BT39_API',
    defaultValue: 'https://bt39-monitor-service.onrender.com',
  );

  /// False only when the key is blanked on purpose with `--dart-define=SUPABASE_KEY=`.
  static bool get supabaseEnabled => supabaseKey.isNotEmpty;
}
