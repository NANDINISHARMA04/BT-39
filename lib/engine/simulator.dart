import 'dart:math';

import 'package:flutter/cupertino.dart';

import 'adapt_alert.dart';

class Scenario {
  const Scenario(this.id, this.name, this.desc, this.icon, this.color, this.minutes, {this.hr = 66, this.spo2 = 97.4, this.temp = 36.55, this.motion = .05, this.loose = false});
  final String id, name, desc, color;
  final IconData icon;
  final int minutes;
  final double hr, spo2, temp, motion;
  final bool loose;
}

/// What can happen to the wearer. Each scenario runs for [Scenario.minutes]
/// simulated minutes and then returns to resting.
const scenarios = [
  Scenario('rest', 'Resting', 'Back to a normal, quiet day', CupertinoIcons.bed_double_fill, 'green', 0),
  Scenario('walk', 'Go for a walk', 'Heart rate rises with movement. No alert needed.', CupertinoIcons.person_crop_circle_badge_checkmark, 'blue', 12, hr: 108, spo2: 97.2, temp: 36.7, motion: .65),
  Scenario('loose', 'Loosen the band', 'Sensor loses skin contact. Data is ignored.', CupertinoIcons.waveform_path_badge_minus, 'gray', 8, loose: true),
  Scenario('stress', 'Coffee or stress', 'Mild heart-rate rise at rest. AdaptAlert learns this one.', CupertinoIcons.flame_fill, 'orange', 11, hr: 87, spo2: 97.3, temp: 36.6, motion: .06),
  Scenario('tachy', 'Heart racing at rest', 'Real event: heart rate up while oxygen falls', CupertinoIcons.heart_fill, 'red', 14, hr: 125, spo2: 93.6, temp: 36.8, motion: .05),
  Scenario('hypoxia', 'Oxygen drop', 'Critical: hits the safety floor', CupertinoIcons.drop_fill, 'purple', 10, hr: 104, spo2: 89, temp: 36.7, motion: .04),
  Scenario('fever', 'Fever', 'Temperature climbs, heart rate follows', CupertinoIcons.thermometer, 'pink', 18, hr: 90, spo2: 96.8, temp: 38.3, motion: .05),
];

Scenario scenarioById(String id) => scenarios.firstWhere((s) => s.id == id);

/// A simulated wearable band (PPG + skin temperature + accelerometer).
class BandSimulator {
  BandSimulator({int seed = 20261011}) : _rnd = Random(seed);
  final Random _rnd;
  double hr = 66, spo2 = 97.4, temp = 36.55, motion = .05;
  Scenario scenario = scenarios.first;
  int minutesLeft = 0;

  double _gauss() {
    var u = 0.0, v = 0.0;
    while (u == 0) {
      u = _rnd.nextDouble();
    }
    while (v == 0) {
      v = _rnd.nextDouble();
    }
    return sqrt(-2 * log(u)) * cos(2 * pi * v);
  }

  void start(String id) {
    scenario = scenarioById(id);
    minutesLeft = scenario.minutes;
  }

  /// Returns true when a scenario just ended.
  bool advance() {
    if (scenario.id == 'rest') return false;
    if (--minutesLeft <= 0) {
      scenario = scenarios.first;
      return true;
    }
    return false;
  }

  Reading next() {
    final s = scenario;
    if (s.loose) {
      return Reading(
        hr: (40 + _rnd.nextDouble() * 130).round(),
        spo2: (82 + _rnd.nextDouble() * 18).round(),
        temp: double.parse((temp - 1 - _rnd.nextDouble() * .6).toStringAsFixed(1)),
        motion: .12 + _rnd.nextDouble() * .25,
        contact: .15 + _rnd.nextDouble() * .15,
      );
    }
    hr += (s.hr - hr) * .3 + _gauss() * .8;
    spo2 += (s.spo2 - spo2) * .3 + _gauss() * .12;
    temp += (s.temp - temp) * .15 + _gauss() * .02;
    motion += (s.motion - motion) * .35;
    return Reading(
      hr: (hr + _gauss() * 1.2).round(),
      spo2: (spo2 + _gauss() * .3).clamp(70, 100).round(),
      temp: double.parse((temp + _gauss() * .04).toStringAsFixed(1)),
      motion: (motion + _gauss() * .03).clamp(0, 1.2).toDouble(),
      contact: .9 + _rnd.nextDouble() * .08,
    );
  }
}
