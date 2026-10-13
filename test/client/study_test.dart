import 'package:bt39_care/engine/study.dart';
import 'package:bt39_care/services/pulse_api.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

Map<String, dynamic> metrics({double fpd = 1.4, double last = .4, double sens = .95, double ppv = .5}) => {
      'falsePerDay': fpd,
      'falsePerDayWeek1': fpd + .2,
      'falsePerDayLastWeek': last,
      'sensitivity': sens,
      'criticalCaught': 1.0,
      'ppv': ppv,
      'alertsPerDay': 2.1,
      'falseLastWeekCI': {'lo': last - .1, 'hi': last + .1},
      'sensitivityCI': {'lo': sens - .05, 'hi': 1.0},
    };

Map<String, dynamic> studyReply({bool noise = false, bool markdown = false, Map<String, dynamic>? config}) => {
      'result': {
        'config': config ?? const StudyConfig().toJson(),
        'real_events': 150,
        'safety_events': 30,
        'series': {
          'A': [3.1, 2.9, 3.0],
          'C': [3.0, 1.0, .4],
        },
        'metrics': {
          'A': metrics(fpd: 3.0, last: 3.0, sens: 1.0, ppv: .1),
          'C': metrics(),
        },
        'reduction': {'C': .87, 'E': .91},
      },
      'noise': noise
          ? [
              {'noise': 0, 'sensC': .97, 'sensD': .97, 'critC': 1, 'critD': 1, 'falseC': .4},
              {'noise': .5, 'sensC': .9, 'sensD': .5, 'critC': 1.0, 'critD': .3, 'falseC': .5},
            ]
          : null,
      'markdown': markdown ? '| System | ... |' : null,
    };

void main() {
  test('the default study settings are the ones the app always used', () {
    expect(const StudyConfig().toJson(), {
      'patients': 40,
      'days': 30,
      'seed': 7,
      'labelRate': .9,
      'labelNoise': 0,
      'dismissRate': 0,
      'k': 4,
      'rejectStep': .03,
      'confirmStep': .05,
      'realEventRate': .12,
    });
  });

  test('copyWith changes only what it is given', () {
    final c = const StudyConfig().copyWith(patients: 60, dismissRate: .3, seed: 99);
    expect([c.patients, c.days, c.seed, c.dismissRate, c.labelRate, c.rejectStep], [60, 30, 99, .3, .9, .03]);
  });

  test('a config survives JSON, and snake_case keys read too', () {
    const c = StudyConfig(patients: 25, days: 14, seed: 3, labelRate: .5, labelNoise: .1, dismissRate: .2, k: 6, realEventRate: .2);
    final back = StudyConfig.fromJson(c.toJson());
    expect(back.toJson(), c.toJson());
    final snake = StudyConfig.fromJson({'patients': 12, 'label_rate': .4, 'dismiss_rate': .25, 'real_event_rate': .3});
    expect([snake.patients, snake.labelRate, snake.dismissRate, snake.realEventRate, snake.days], [12, .4, .25, .3, 30]);
  });

  test('the study is asked for and read back', () async {
    final svc = FakeService()..on('POST /study', studyReply(noise: true, markdown: true));
    final run = await runStudyRemote(svc.api(), const StudyConfig(seed: 11, patients: 50), noise: (patients: 30, seeds: 3), markdown: true);

    final sent = svc.to('POST /study').single.map;
    expect((sent['config'] as Map)['seed'], 11);
    expect((sent['config'] as Map)['patients'], 50);
    expect(sent['noise'], {'patients': 30, 'seeds': 3});
    expect(sent['markdown'], isTrue);

    final r = run.result;
    expect(r.realEvents, 150);
    expect(r.safetyEvents, 30);
    expect(r.days, 30);
    expect(r.patients, 40);
    expect(r.series['A'], [3.1, 2.9, 3.0]);
    expect(r.series.keys, ['A', 'C']);
    final c = r.metrics['C']!;
    expect(c.falsePerDay, 1.4);
    expect(c.falsePerDayWeek1, closeTo(1.6, 1e-9));
    expect(c.falsePerDayLastWeek, .4);
    expect(c.falsePerDayWeek5, .4, reason: 'the name the first study used');
    expect(c.sensitivity, .95);
    expect(c.criticalCaught, 1.0);
    expect(c.ppv, .5);
    expect(c.alertsPerDay, 2.1);
    expect(c.falseLastWeekCI.lo, closeTo(.3, 1e-9));
    expect(c.falseLastWeekCI.hi, closeTo(.5, 1e-9));
    expect(c.sensitivityCI.hi, 1.0);
    expect(r.reduction('C'), .87);
    expect(r.reduction('E'), .91);
    expect(systemNames['C'], 'AdaptAlert');

    expect(run.noise!.length, 2);
    expect(run.noise!.last.noise, .5);
    expect(run.noise!.last.sensD, .5);
    expect(run.noise!.first.critC, 1.0);
    expect(run.markdown, '| System | ... |');
  });

  test('without the sweep or the tables they are null, and a system the service does not score is worked out', () async {
    final svc = FakeService()..on('POST /study', studyReply());
    final run = await runStudyRemote(svc.api(), const StudyConfig());
    expect(svc.to('POST /study').single.map['noise'], isNull);
    expect(svc.to('POST /study').single.map['markdown'], isFalse);
    expect(run.noise, isNull);
    expect(run.markdown, isNull);
    expect(run.result.reduction('C'), .87);
  });

  test('a reply with no reduction block falls back to the figures', () async {
    final reply = studyReply();
    (reply['result'] as Map).remove('reduction');
    final svc = FakeService()..on('POST /study', reply);
    final r = (await runStudyRemote(svc.api(), const StudyConfig())).result;
    expect(r.reduction('C'), closeTo(1 - .4 / 3.0, 1e-9));
  });

  test('runStudy gives just the result for a seed', () async {
    final svc = FakeService()..on('POST /study', studyReply());
    final r = await runStudy(svc.api(), seed: 21);
    expect(((svc.to('POST /study').single.map['config']) as Map)['seed'], 21);
    expect(r.metrics['C']!.sensitivity, .95);
  });

  test('a study the service refuses throws with its sentence', () async {
    final svc = FakeService();
    svc.routes['POST /study'] = (_) => errorReply(429, 'busy', 'A study is already running.');
    await expectLater(
      runStudy(svc.api()),
      throwsA(isA<ApiException>().having((e) => e.status, 'status', 429).having((e) => e.message, 'message', 'A study is already running.')),
    );
  });
}
