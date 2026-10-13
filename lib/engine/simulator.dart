import 'package:flutter/cupertino.dart';

/// A thing that can happen to the wearer, as the simulator sheet lists it.
///
/// The simulated band runs on the PulseOS service; the app only names the
/// scenarios and tells the service which one to play. Each scenario runs for
/// [minutes] simulated minutes and then returns to resting.
class Scenario {
  const Scenario(this.id, this.name, this.desc, this.icon, this.color, this.minutes);
  final String id, name, desc, color;
  final IconData icon;
  final int minutes;
}

const scenarios = [
  Scenario('rest', 'Resting', 'Back to a normal, quiet day', CupertinoIcons.bed_double_fill, 'green', 0),
  Scenario('walk', 'Go for a walk', 'Heart rate rises with movement. No alert needed.', CupertinoIcons.person_crop_circle_badge_checkmark, 'blue', 12),
  Scenario('loose', 'Loosen the band', 'Sensor loses skin contact. Data is ignored.', CupertinoIcons.waveform_path_badge_minus, 'gray', 8),
  Scenario('stress', 'Coffee or stress', 'Mild heart-rate rise at rest. AdaptAlert learns this one.', CupertinoIcons.flame_fill, 'orange', 11),
  Scenario('tachy', 'Heart racing at rest', 'Real event: heart rate up while oxygen falls', CupertinoIcons.heart_fill, 'red', 14),
  Scenario('hypoxia', 'Oxygen drop', 'Critical: hits the safety floor', CupertinoIcons.drop_fill, 'purple', 10),
  Scenario('fever', 'Fever', 'Temperature climbs, heart rate follows', CupertinoIcons.thermometer, 'pink', 18),
];

Scenario scenarioById(String id) => scenarios.firstWhere((s) => s.id == id);
