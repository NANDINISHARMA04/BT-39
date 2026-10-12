import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'config.dart';
import 'l10n/l10n.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (AppConfig.supabaseEnabled) {
    await Supabase.initialize(url: AppConfig.supabaseUrl, publishableKey: AppConfig.supabaseKey);
  }
  await loadLang();
  runApp(const BT39App());
}
