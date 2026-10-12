// Prints the default experiment and the label-noise sweep as Markdown.
// Run: dart run tool/run_study.dart
import 'package:bt39_care/engine/study.dart';

void main() {
  const cfg = StudyConfig();
  final r = runExperiment(cfg);
  // ignore: avoid_print
  print(resultsMarkdown(r, noise: noiseSweep(cfg)));
}
