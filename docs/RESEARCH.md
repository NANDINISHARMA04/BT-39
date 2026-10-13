# AdaptAlert: research notes

AdaptAlert is the alert engine inside the **PulseOS** app. Material for the project report and a research paper. Numbers here come from `dart run tool/run_study.dart` (the same code as the in-app **Research Lab**; since October 2026 the study runs on the BT39 service, `api/bt39api/pulse/study.py`, a line-for-line port of the original `lib/engine/study.dart` checked against it on recorded runs), so they can be regenerated exactly.

## 1. Problem

Remote vital-sign monitors usually alert on fixed thresholds or fixed early-warning scores. In clinical monitoring most alarms are not actionable, and staff exposed to many false alarms start to ignore them ("alarm fatigue"), which has been named a patient-safety concern by The Joint Commission (Sentinel Event Alert 50, 2013) and in reviews such as Cvach (2012) and Sendelbach & Funk (2013). Home monitoring adds movement, loose sensors and everyday events like exercise or coffee, which push fixed thresholds over the line even more often.

## 2. Research gaps addressed

| Gap in existing remote-monitoring systems | How AdaptAlert addresses it | Where in the code |
|---|---|---|
| G1. One threshold for everyone | Personal normal ranges per vital and activity state (rest, light, active, cooling down) | `engine.py` on the BT39 service (originally `lib/engine/adapt_alert.dart`), stage C |
| G2. Systems never learn after deployment | Patient context answers and clinician labels update per-pattern estimates and a personal threshold τ | stage F, `patientFeedback`, `doctorLabel` |
| G3. Learning from feedback can learn to ignore real emergencies | Guarded learning: safety floor that skips the model, τ bounded to 30–75%, at most 10 points a week, "I feel unwell" and "Not sure" never reduce sensitivity | stage D, `nudgedTau` |
| G4. Black-box alerts that clinicians don't trust | Plain-language reasons, decision path, a counterfactual ("no alert below 84 bpm") and a 90% credible interval for every alert | stage G, alert detail screen |
| G5. Bad sensor data causes false alarms | Signal-quality index; unreliable windows never alert or update the baseline | stage A |
| G6. Personal models start cold | Federated prior: new patients start from label statistics pooled across earlier patients, no raw vitals shared | `study.py` on the BT39 service (originally `lib/engine/study.dart`), system E |
| G7. Results reported without uncertainty or ablations | Five-system comparison on identical events, 95% bootstrap CIs, alarm-fatigue sweep, ablation of the safeguards | Research Lab |

## 3. Method

### 3.1 Decision rule

For an anomalous window with features *f* (z-scores, activity, number of abnormal vitals, time of day), a fixed decision tree gives P_model. The patient's labels for the same pattern (bucket) give a Beta(1,1) posterior mean P_you = (r + 1) / (n + 2). They are blended by evidence:

P(real) = (1 − w)·P_model + w·P_you,  w = n / (n + k),  k = 4.

An alert is sent if P(real) ≥ τ. A clinician "false alarm" raises τ by 0.03, "confirmed real" lowers it by 0.05, within the bounds above. Safety-floor events alert without consulting the model.

### 3.2 Federated prior (cold start)

After each patient, only their per-pattern label counts (r, f) are added to a shared pool. A new patient's starting estimate for a pattern is the pooled rate, shrunk to at most 3 labels of evidence so the patient's own feedback quickly dominates. No vitals leave the device.

### 3.3 Simulation design

Each virtual patient, per day: about 2 exercise episodes, 1.5 loose-sensor episodes, 1.2 coffee/stress heart-rate rises, a 50% chance of a mild oxygen dip during sleep, and a 12% chance of a real deterioration (30% fast heart rate with falling oxygen, 25% fever, 20% critical oxygen drop at the safety floor, 25% subtle oxygen fall). Clinicians label 90% of sent alerts. All five systems see identical event streams. Confidence intervals are 95% percentile bootstrap over patients (400 resamples).

These rates are modelling assumptions, not clinical data.

## 4. Results (default settings)

Simulated study: 40 patients × 30 days, seed 7, label rate 90.0%, label noise 0.0%, real alerts dismissed 0.0%, k = 4.0.
159 real events (36 reached the safety floor).

| System | False alarms/patient/day, week 1 | Last week (95% CI) | Sensitivity (95% CI) | Critical caught | PPV | Alerts/patient/day |
|---|---|---|---|---|---|---|
| Fixed threshold | 3.90 | 3.70 (3.51–3.92) | 92.5% (88.6%–96.1%) | 100.0% | 3.2% | 3.86 |
| Personal normal | 1.71 | 1.73 (1.61–1.85) | 100.0% (100.0%–100.0%) | 100.0% | 7.2% | 1.85 |
| AdaptAlert | 0.47 | 0.11 (0.07–0.16) | 100.0% (100.0%–100.0%) | 100.0% | 39.6% | 0.34 |
| Unguarded learning (ablation) | 0.55 | 0.11 (0.07–0.16) | 100.0% (100.0%–100.0%) | 100.0% | 35.6% | 0.37 |
| AdaptAlert + federated prior | 0.06 | 0.13 (0.08–0.18) | 100.0% (100.0%–100.0%) | 100.0% | 58.2% | 0.23 |

False-alarm reduction vs fixed threshold, last week: AdaptAlert 96.9%, with federated prior 96.5%.

Alarm fatigue: share of real alerts dismissed as false alarms (mean of 5 seeds).

| Real alerts dismissed | Sensitivity, AdaptAlert | Sensitivity, unguarded | Critical caught, AdaptAlert | Critical caught, unguarded | False alarms/day, AdaptAlert |
|---|---|---|---|---|---|
| 0.0% | 100.0% | 100.0% | 100.0% | 100.0% | 0.12 |
| 10.0% | 99.0% | 99.4% | 100.0% | 100.0% | 0.09 |
| 20.0% | 98.1% | 98.0% | 100.0% | 100.0% | 0.07 |
| 30.0% | 97.2% | 96.6% | 100.0% | 100.0% | 0.06 |
| 50.0% | 93.9% | 93.2% | 100.0% | 99.2% | 0.02 |

### Findings

1. **False alarms.** AdaptAlert cut false alarms in the last week by about 97% against fixed thresholds and by about 94% against personal ranges without learning, while catching every real event in this simulation.
2. **Precision.** About 40% of AdaptAlert's alerts were real, against about 3% for fixed thresholds.
3. **Cold start.** The federated prior removed most first-week false alarms (0.47 → 0.06 per patient per day), the period when a personal model knows least.
4. **Alarm fatigue.** When patients dismiss real alerts, sensitivity on milder events falls (to about 94% at 50% dismissal). Critical events stayed at 100% with the guarded design. Learning is largely self-limiting, because held-back alerts stop generating labels, so the unguarded ablation differed only slightly here; the safety floor is kept as a guarantee that does not depend on that behaviour.

## 5. Limitations

- Results come from a simulation with assumed event rates; they show the mechanism, not clinical effectiveness.
- The live demo uses a simulated band. Sensor accuracy (MAX30102 SpO₂ in particular) must be measured against a reference oximeter.
- Patient dismissals reduce sensitivity on milder events; doctor labels override patient answers, but this trade-off needs study with real users.
- The decision tree is hand-built from clinical reasoning, not trained on data.

## 6. Suggested next steps

1. Replay real recordings (PhysioNet / MIMIC waveform data) through the engine with clinician-labelled events.
2. A small volunteer study: 5–10 people, 5–7 days, safe induced events (exercise, loose strap), with the before/after alert counts.
3. Concept-drift detection: notice when a patient's normal shifts (recovery after surgery) and tell the doctor.
4. Real federated training across hospitals, with secure aggregation.

## 7. Suggested paper outline

1. Introduction: alarm fatigue in remote monitoring.
2. Related work: early-warning scores (NEWS2), alarm fatigue studies, personalised monitoring, explainable AI, federated learning.
3. System design: architecture, the seven-stage pipeline, guarded learning, explanations.
4. Experimental setup: simulation design (section 3.3), metrics, systems A–E.
5. Results: tables and figures from the Research Lab (learning curves, alarm-fatigue chart).
6. Discussion and limitations.
7. Conclusion and future work.

## References to check and cite

Verify each against the original before citing.

- Royal College of Physicians. *National Early Warning Score (NEWS) 2.* London: RCP, 2017.
- The Joint Commission. *Sentinel Event Alert 50: Medical device alarm safety in hospitals.* 2013.
- Cvach M. Monitor alarm fatigue: an integrative review. *Biomedical Instrumentation & Technology.* 2012.
- Sendelbach S, Funk M. Alarm fatigue: a patient safety concern. *AACN Advanced Critical Care.* 2013.
- Drew BJ, et al. Insights into the problem of alarm fatigue with physiologic monitor devices. *PLoS ONE.* 2014.
- McMahan B, et al. Communication-efficient learning of deep networks from decentralized data. *AISTATS.* 2017.
- Wachter S, Mittelstadt B, Russell C. Counterfactual explanations without opening the black box. *Harvard Journal of Law & Technology.* 2018.
