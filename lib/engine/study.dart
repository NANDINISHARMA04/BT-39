import '../services/pulse_api.dart';

/// Simulated studies of alert systems on the same virtual patients.
///
/// The study runs on the PulseOS service (`POST /study`); this file holds the
/// settings the Research Lab sends and the results it gets back.
///
/// Systems compared on identical event streams:
///   A  Fixed thresholds: HR > 100, SpO₂ < 94, Temp > 37.8, no quality check
///   B  Personal normal + signal-quality check, no learning (τ fixed at 0.5)
///   C  AdaptAlert: B plus feedback learning and the safety floor
///   D  Unguarded learning (ablation): no safety floor, τ free between 0.05 and
///      0.95 with no weekly limit, so feedback alone decides
///   E  AdaptAlert with a federated prior: new patients start from pattern
///      statistics pooled from earlier patients (counts only, no raw vitals)
///
/// The event mix and rates are modelling assumptions, listed in docs/RESEARCH.md.

double _d(Object? v) => (v as num?)?.toDouble() ?? 0;
int _i(Object? v) => (v as num?)?.round() ?? 0;
Map<String, dynamic> _obj(Object? v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

/// The first of [keys] that [j] has, so replies in camelCase or snake_case both read.
Object? _pick(Map<String, dynamic> j, List<String> keys) {
  for (final k in keys) {
    if (j[k] != null) return j[k];
  }
  return null;
}

class StudyConfig {
  const StudyConfig({
    this.patients = 40,
    this.days = 30,
    this.seed = 7,
    this.labelRate = .9,
    this.labelNoise = 0,
    this.dismissRate = 0,
    this.k = 4,
    this.rejectStep = .03,
    this.confirmStep = .05,
    this.realEventRate = .12,
  });

  final int patients, days, seed;

  /// Share of sent alerts that a clinician labels.
  final double labelRate;

  /// Chance that a label is wrong (real called false, or false called real).
  final double labelNoise;

  /// Chance that a real alert is dismissed as a false alarm: alarm fatigue,
  /// the failure that makes learning from feedback dangerous.
  final double dismissRate;

  /// Personal weight constant: w = n / (n + k).
  final double k;
  final double rejectStep, confirmStep;

  /// Real deteriorations per patient per day.
  final double realEventRate;

  StudyConfig copyWith({int? patients, int? days, int? seed, double? labelRate, double? labelNoise, double? dismissRate, double? k, double? realEventRate}) => StudyConfig(
        patients: patients ?? this.patients,
        days: days ?? this.days,
        seed: seed ?? this.seed,
        labelRate: labelRate ?? this.labelRate,
        labelNoise: labelNoise ?? this.labelNoise,
        dismissRate: dismissRate ?? this.dismissRate,
        k: k ?? this.k,
        rejectStep: rejectStep,
        confirmStep: confirmStep,
        realEventRate: realEventRate ?? this.realEventRate,
      );

  Map<String, dynamic> toJson() => {
        'patients': patients,
        'days': days,
        'seed': seed,
        'labelRate': labelRate,
        'labelNoise': labelNoise,
        'dismissRate': dismissRate,
        'k': k,
        'rejectStep': rejectStep,
        'confirmStep': confirmStep,
        'realEventRate': realEventRate,
      };

  /// Reads a config the service echoed back; a missing key keeps its default.
  factory StudyConfig.fromJson(Map<String, dynamic> j) {
    const d = StudyConfig();
    double real(List<String> keys, double fallback) => _pick(j, keys) == null ? fallback : _d(_pick(j, keys));
    int whole(String key, int fallback) => j[key] == null ? fallback : _i(j[key]);
    return StudyConfig(
      patients: whole('patients', d.patients),
      days: whole('days', d.days),
      seed: whole('seed', d.seed),
      labelRate: real(['labelRate', 'label_rate'], d.labelRate),
      labelNoise: real(['labelNoise', 'label_noise'], d.labelNoise),
      dismissRate: real(['dismissRate', 'dismiss_rate'], d.dismissRate),
      k: real(['k'], d.k),
      rejectStep: real(['rejectStep', 'reject_step'], d.rejectStep),
      confirmStep: real(['confirmStep', 'confirm_step'], d.confirmStep),
      realEventRate: real(['realEventRate', 'real_event_rate'], d.realEventRate),
    );
  }
}

const systemNames = {
  'A': 'Fixed threshold',
  'B': 'Personal normal',
  'C': 'AdaptAlert',
  'D': 'Unguarded learning (ablation)',
  'E': 'AdaptAlert + federated prior',
};

class Interval {
  const Interval(this.lo, this.hi);
  final double lo, hi;
  factory Interval.fromJson(Map<String, dynamic> j) => Interval(_d(j['lo']), _d(j['hi']));
}

class SystemMetrics {
  SystemMetrics({required this.falsePerDay, required this.falsePerDayWeek1, required this.falsePerDayLastWeek, required this.sensitivity, required this.criticalCaught, required this.ppv, required this.alertsPerDay, required this.falseLastWeekCI, required this.sensitivityCI});
  final double falsePerDay, falsePerDayWeek1, falsePerDayLastWeek, sensitivity, ppv, alertsPerDay;

  /// Share of critical (safety-floor level) events that were alerted.
  final double criticalCaught;
  final Interval falseLastWeekCI, sensitivityCI;

  // Names kept for the screens and tests written against the first study.
  double get falsePerDayWeek5 => falsePerDayLastWeek;

  factory SystemMetrics.fromJson(Map<String, dynamic> j) => SystemMetrics(
        falsePerDay: _d(j['falsePerDay']),
        falsePerDayWeek1: _d(j['falsePerDayWeek1']),
        falsePerDayLastWeek: _d(j['falsePerDayLastWeek']),
        sensitivity: _d(j['sensitivity']),
        criticalCaught: _d(j['criticalCaught']),
        ppv: _d(j['ppv']),
        alertsPerDay: _d(j['alertsPerDay']),
        falseLastWeekCI: Interval.fromJson(_obj(j['falseLastWeekCI'])),
        sensitivityCI: Interval.fromJson(_obj(j['sensitivityCI'])),
      );
}

class ExperimentResult {
  ExperimentResult(this.config, this.realEvents, this.safetyEvents, this.series, this.metrics, [this.reductions = const {}]);
  final StudyConfig config;
  final int realEvents, safetyEvents;

  /// False alarms per patient for each day, per system.
  final Map<String, List<double>> series;
  final Map<String, SystemMetrics> metrics;

  /// The service's own figure for AdaptAlert (`C`) and with a federated prior (`E`).
  final Map<String, double> reductions;

  int get days => config.days;
  int get patients => config.patients;

  /// Percent fewer false alarms than the fixed-threshold monitor in the last week.
  double reduction(String s) => reductions[s] ?? (metrics['A']!.falsePerDayLastWeek == 0 ? 0 : 1 - metrics[s]!.falsePerDayLastWeek / metrics['A']!.falsePerDayLastWeek);

  factory ExperimentResult.fromJson(Map<String, dynamic> j) => ExperimentResult(
        StudyConfig.fromJson(_obj(j['config'])),
        _i(_pick(j, ['real_events', 'realEvents'])),
        _i(_pick(j, ['safety_events', 'safetyEvents'])),
        {
          for (final e in _obj(j['series']).entries) e.key: [for (final v in (e.value as List? ?? const [])) _d(v)],
        },
        {
          for (final e in _obj(j['metrics']).entries) e.key: SystemMetrics.fromJson(_obj(e.value)),
        },
        {
          for (final e in _obj(j['reduction']).entries) e.key: _d(e.value),
        },
      );
}

typedef StudyResult = ExperimentResult;
typedef StudyMetrics = SystemMetrics;

/// What happens as feedback gets worse: at each level, a share of real alerts
/// is dismissed as a false alarm (alarm fatigue). Averaged over several runs.
class NoisePoint {
  NoisePoint(this.noise, this.sensC, this.sensD, this.critC, this.critD, this.falseC);
  final double noise, sensC, sensD, critC, critD, falseC;

  factory NoisePoint.fromJson(Map<String, dynamic> j) => NoisePoint(_d(j['noise']), _d(j['sensC']), _d(j['sensD']), _d(j['critC']), _d(j['critD']), _d(j['falseC']));
}

/// One answer from the study route.
class StudyRun {
  const StudyRun(this.result, this.noise, this.markdown);
  final ExperimentResult result;

  /// The alarm-fatigue sweep, when it was asked for.
  final List<NoisePoint>? noise;

  /// The results as Markdown tables for a paper draft, when asked for.
  final String? markdown;
}

/// Runs the study on the service. Pass [noise] to add the alarm-fatigue sweep
/// (patients per run, runs per level) and [markdown] to get the tables as text.
/// The service runs one study at a time and remembers the last ones, so a
/// repeat is quick. Throws an [ApiException] when the service says no.
Future<StudyRun> runStudyRemote(PulseApi api, StudyConfig cfg, {({int patients, int seeds})? noise, bool markdown = false}) async {
  final r = await api.post('/study', {
    'config': cfg.toJson(),
    'noise': noise == null ? null : {'patients': noise.patients, 'seeds': noise.seeds},
    'markdown': markdown,
  });
  if (!r.ok) throw ApiException(r.status, r.error, r.message);
  final j = r.map;
  return StudyRun(
    ExperimentResult.fromJson(_obj(j['result'])),
    j['noise'] is List ? [for (final n in j['noise'] as List) NoisePoint.fromJson(_obj(n))] : null,
    j['markdown'] as String?,
  );
}

/// The first study's call, kept for existing screens: the default experiment
/// with the given [seed].
Future<ExperimentResult> runStudy(PulseApi api, {int seed = 7}) async => (await runStudyRemote(api, StudyConfig(seed: seed))).result;
