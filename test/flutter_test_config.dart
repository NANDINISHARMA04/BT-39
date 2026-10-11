import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads the real Roboto font from the Flutter SDK, so layout tests measure
/// text the way a phone does (the default test font draws every glyph as a
/// full square, which is far wider than real text).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null) {
    final dir = '$root/bin/cache/artifacts/material_fonts';
    final loader = FontLoader('Roboto');
    for (final w in ['Regular', 'Medium', 'Bold', 'Black', 'Light']) {
      final f = File('$dir/Roboto-$w.ttf');
      if (f.existsSync()) loader.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
    }
    await loader.load();
  }
  await testMain();
}
