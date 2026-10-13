// Prints the default experiment and the alarm-fatigue sweep as Markdown.
// The study runs on the PulseOS service now (the same code as the live engine).
//
// Run: dart run tool/run_study.dart
// Another service: PULSE_API=http://localhost:8000/v1/pulse dart run tool/run_study.dart
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

Future<void> main() async {
  final base = Platform.environment['PULSE_API'] ?? 'https://bt39-monitor-service.onrender.com/v1/pulse';
  // The default setup, and the sweep over 40 patients and 5 seeds (what this tool printed before).
  final body = jsonEncode({'config': <String, Object>{}, 'noise': {'patients': 40, 'seeds': 5}, 'markdown': true});
  final http.Response res;
  try {
    // The free service may be asleep; waking it can take a minute.
    res = await http.post(Uri.parse('$base/study'), headers: {'Content-Type': 'application/json'}, body: body).timeout(const Duration(seconds: 120));
  } catch (e) {
    stderr.writeln('The service at $base could not be reached: $e');
    exit(1);
  }
  final reply = jsonDecode(utf8.decode(res.bodyBytes));
  if (res.statusCode != 200 || reply is! Map || reply['markdown'] is! String) {
    stderr.writeln('The service answered ${res.statusCode}: ${reply is Map ? reply['message'] : res.body}');
    exit(1);
  }
  stdout.write(reply['markdown']);
}
