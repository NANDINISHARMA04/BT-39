# PulseOS

**Smart health monitoring that learns.** Powered by **AdaptAlert**, its self-learning alert engine. A Flutter app (Android, iOS and web) with an iOS-style design, built around a self-learning, explainable alert engine that cuts false alarms without missing real emergencies.

> Student research prototype (B.Tech CSE major project). Not a medical device. Patients, doctors and clinics in the app are fictional.

## The problem it solves

Most health monitors alert on fixed thresholds (for example "heart rate above 100"). Those rules never get smarter. Patients and doctors get so many false alarms that they stop trusting the alerts, which is why many remote-monitoring trials fail.

AdaptAlert asks after every alert: *what was happening?* It remembers the answer, learns each person's normal, and alerts less for patterns that turned out harmless for that person. Hard safety limits always alert, whatever the feedback says.

## What's in the app

There are two apps in one, chosen at sign-in.

**Patient app** (five tabs: Today, Alerts, Insights, Care, Me)

| Feature | Where |
|---|---|
| Secure authentication: separate **log in and sign up for patients, doctors and nurses** (role-specific fields such as registration number, speciality, ward and shift), accounts on the BT39 service with Supabase sign-in, plus **Demo Mode** that needs no account | Welcome › Log in / Sign up |
| **Guided demo with a voice-over** in English or Hindi: plays the whole AdaptAlert story (walk, loose band, coffee alert, doctor rejects, held back, real event, safety floor) with captions and a recorded natural voice, then asks you to log in or sign up | Welcome › Watch the demo with voice |
| **Help assistant** for everyone, especially older people: ask "where are my reports?", "how do I change the language?", "report kahan hai?" in English, Hindi or Hinglish and get short steps plus a button that goes straight there; big help topics; speak your question with the microphone; answers can be read aloud. A round **Help** button sits on every patient page | Help button, Today › AI Health Assistant |
| **Accessibility** for older and disabled people: larger and bold text, **easy home** (one big status card, giant vitals and four big buttons: Ask for help, Call family, My medicines, SOS), **flash alerts** for hearing loss, **spoken alerts** for low vision, reduce motion, and Normal/High/Low words so colour is never the only signal | Me › Accessibility |
| **English and हिन्दी** everywhere: every screen, the AdaptAlert explanations, the health assistant (which also understands simple Hindi questions) and the demo voice. Switch on the welcome page or in Me | Welcome, Me |
| **Alert detail "How AdaptAlert decided"**: what the band saw, which signals drove it (SDs from your normal), model vs your history with a confidence interval, the blend formula and threshold, counterfactuals (what would have changed the decision) and who was told | Alerts › See how AdaptAlert decided |
| **How it works** explainer and the AdaptAlert hero card (fixed monitor vs sent vs held back) | Alerts |
| **Research Lab**: run the 5-system experiment with your own settings, ablation, label-noise and alarm-fatigue sweeps, bootstrap CIs, copy results as Markdown for the paper | Welcome › Research Lab, Insights |
| Health dashboard with real-time insights: live heart rate with a pulse waveform, oxygen, temperature, activity, signal quality and the personal normal range | Today |
| **AdaptAlert** self-learning alerts: plain-language reasons, "likely real" score, feedback buttons (I was active / Sensor was loose / I feel unwell / Not sure), doctor confirm or reject, held-back alerts | Alerts |
| Health analytics with charts: trends with the personal-normal band, alert load per hour, the live 7-stage AI pipeline, the sensitivity gauge, learned patterns, and a 30-day simulated study | Insights |
| Appointment booking with full CRUD: book, reschedule, cancel, delete; free slots per doctor; video or clinic; book a follow-up straight from an alert | Care |
| Doctor discovery and filtering: search, speciality, video, available today, rating, language, sort by rating, fee or distance | Care › Search |
| Medical records vault: upload (PDF and photos, up to 10 MB), categories, per-member filter, search, edit, share with doctor, delete | Me › Medical records |
| Insurance tracking and claims: policies with cover left, claims with a status timeline, attach records, simulated insurer updates | Me › Insurance & claims |
| Family profile management: members, caregiver (gets unanswered alerts), emergency contacts, per-member appointments and records | Me › Family |
| AI Health Assistant: answers from your own data (vitals, alerts, what AdaptAlert learned, medicines, appointments, records, insurance) and sends emergencies to SOS | Today › AI Health Assistant |
| Emergency access and SOS: hold-to-activate, call 112, alert emergency contacts, share location and live vitals, Medical ID, and **auto-SOS** on a safety-floor alert | SOS button, Me › Emergency |
| User profile and preferences: health profile, medicines, appearance (auto/light/dark), °C/°F, notifications, caregiver escalation, language | Me |

**Doctor and nurse app** (tabs on phones, a sidebar on laptops)

| Feature | Who | Where |
|---|---|---|
| **Today** dashboard: AdaptAlert alerts to review, appointments left, high-risk ward patients, unacknowledged alerts, "needs you now" list, next appointments | Doctor | Today |
| **My shift**: timed nursing tasks (vitals rounds, medicines, home video check, dressings) with who ticked them off, live counts, and a **handover note** for the next shift | Nurse | Shift |
| **Patients**: search and filter; patients who sign up on the same device appear automatically. Each patient page has live or last vitals, AdaptAlert status, conditions, allergies, medicines, visits, alerts, shared records, and notes | Both | Patients |
| **Notes and prescriptions**: doctors write notes, consultation notes and prescriptions (with an allergy warning); nurses write nursing notes. A prescription for a patient with an account also appears in the patient's own medicine list | Both | Patient › Note / Prescribe |
| **Schedule**: a week of appointments, including ones patients booked in the patient app; mark seen with a consultation note, no-show or cancel; book a follow-up | Doctor | Schedule |
| **Ward**: 12 beds sorted by risk, live NEWS2, a pulsing border on unacknowledged emergencies; bed detail with NEWS2 points and chat | Both | Ward |
| **Alerts**: acknowledge, resolve with a note, label *Real* or *False alarm* | Both | Alerts |
| **AdaptAlert review**: the home patient's alerts with her own feedback; marking them real or false teaches AdaptAlert | Both | AdaptAlert review / Home band |
| **Ward rules**: how often each ward rule was right, so the noisiest rules can be tuned first | Both | Ward rules |

## Where the work happens

The app shows what the BT39 service sends and sends what you do. Everything else runs on the service ([bt39-monitor-service](https://github.com/gxc-siddhartha/bt39-monitor-service), `api/bt39api/pulse/`, contract in its `docs/pulseos.md`):

| On the service | In the app |
|---|---|
| The simulated band and the AdaptAlert engine (one per patient account, saved, so learning survives closing the app) | Screens, charts and colours |
| The 30-day study and the Research Lab experiments | Translation into Hindi (`tr`) and number and date formats |
| Accounts and roles, sign-up for every role | Voice-over, speech, accessibility settings |
| Patient records: profile, family, appointments, free slots, records, insurance and claims | The phone dialler (Call 112, call family) and the file picker |
| Care-team records: patients, notes, prescriptions, visits, nurse tasks, handovers | Typing animations and haptics |
| The health assistant, the doctor's demo chat, SOS and caregiver steps | |
| Demo Mode: each visitor gets a fresh copy (own band, 11-bed ward, example data), deleted when they leave | |

The service's Python code was checked against this app's original Dart code: recorded runs (10,000 band minutes, the 30-day study, the demo ward, the assistant in English and Hindi) give the same numbers and the same words. So the app needs an internet connection; on the free plan the service can take about a minute to wake up.

## How AdaptAlert works

Every reading window (one simulated minute) goes through seven stages. The code runs on the service (`api/bt39api/pulse/engine.py`), ported from this app's original `lib/engine/adapt_alert.dart`.

| Stage | What it does |
|---|---|
| A. Signal quality | Scores skin contact, plausible values, sudden jumps and motion. Unreliable data never alerts and never changes your normal. |
| B. Activity | Resting, light activity, active, or cooling down after activity (from the accelerometer). |
| C. Personal normal | A slowly updating mean and spread per vital and activity state. The z-score says how unusual a reading is *for you*. |
| D. Safety floor | SpO₂ ≤ 91% for 2 min, resting HR ≥ 131 or ≤ 40, temperature ≥ 39.1 or ≤ 35.0 °C. Always alerts. Learning can't switch it off. |
| E. Anomaly check | A vital outside your range for 3 minutes, or two vitals off together. |
| F. Decision | P(real) = (1 − w)·P_model + w·P_you. The model is a small readable decision tree. P_you comes from your labels for the same pattern, with w = n / (n + 4). Sends when P(real) ≥ τ. |
| G. Explanation | Plain words: "Heart rate 98 bpm, 48% above your usual resting 66 bpm for 2 min, while you were still." |

The personal threshold τ starts at 50%, stays between 30% and 75%, and moves at most 10 points a week. A doctor's "false alarm" raises it a little, "confirmed real" lowers it more. "I feel unwell" and "Not sure" never make the app less sensitive. Escalation: you → caregiver (warnings, or no reply in 10 minutes) → doctor → SOS for critical alerts.

**30-day simulated study** (Insights tab, run on the service by `api/bt39api/pulse/study.py`): 40 virtual patients compared on three systems, using the same decision code as the app. With the default seed, false alarms in week 5 fell from about 3.6 per patient per day (fixed thresholds) to about 0.06 (AdaptAlert), and every real event was caught. The event mix and rates are assumptions made for the simulation, not clinical data.

## Run it

You need Flutter 3.41 or newer. It was built and tested with Flutter 3.47.7.

```bash
flutter pub get
flutter run                 # phone or emulator
flutter run -d chrome       # web
flutter test                # client, every screen, Hindi (no network: a fake service answers)
dart run tool/run_study.dart # asks the service for the research results as Markdown
flutter build apk --release
flutter build web --release --no-web-resources-cdn
PULSE_API=http://localhost:8000/v1/pulse flutter test test/live   # the guided demo against a running service
```

The app talks to `https://bt39-monitor-service.onrender.com` and the BT39 Supabase project by default (`lib/config.dart`; the Supabase key there is the public "publishable" key). Three demo accounts exist on the service:

| Role | Email | Password |
|---|---|---|
| Patient | patient@pulseos.app | patient123 |
| Doctor | doctor@pulseos.app | doctor123 |
| Nurse | nurse@pulseos.app | nurse123 |

You can also sign up as any role, or tap *Try without an account*. The demo patient is **Jai**. A demo session is not remembered: reopening the site starts at the welcome page.

**Use made-up data only.** A doctor or nurse who signs up can see every patient at once (the same as on one phone before, but now across all phones). That is fine for a demo, not for real health data.

### Demo script (5 minutes)

1. **Patient demo › Today.** Live vitals and the pulse waveform. Tap the sliders icon to open the simulator.
2. **Go for a walk.** Heart rate rises, but there's no alert. Alerts shows the fixed-threshold monitor would have alarmed.
3. **Loosen the band.** "Check your band" appears and the data is ignored.
4. **Coffee or stress.** An alert is sent. Open it and tap *False alarm* (demo control for the doctor). Run Coffee or stress again: it is **held back** and shows under Alerts › Held back.
5. **Heart racing at rest.** An urgent alert with reasons. Tap *Book a follow-up*.
6. **Oxygen drop.** Safety floor, critical alert and the auto-SOS countdown.
7. **Insights.** Show the live pipeline, the sensitivity gauge, what it learned and the 30-day study chart.
8. Sign out and open the **Doctor** demo: the ward, a bed, NEWS2 points, and acknowledging and labelling alerts.

## Put it online (Vercel)

`deploy/web` holds a ready-made build of the web app, so Vercel only serves files and doesn't need Flutter. `vercel.json` already points Vercel at it.

1. On https://vercel.com, sign in with GitHub, choose **Add New → Project** and import this repository.
2. Leave every setting as it is (Vercel reads `vercel.json`) and press **Deploy**.
3. After a change to the app, run `./tool/build_web.sh`, then commit and push `deploy/web`. Vercel redeploys on every push.

## Run it on an iPhone

You need a Mac with Xcode (free from the App Store) and a free Apple ID.

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
brew install cocoapods
open ios/Runner.xcworkspace     # Signing & Capabilities: pick your Apple ID as Team
flutter run                     # with the iPhone plugged in and unlocked
```

On the iPhone, turn on Settings → Privacy & Security → Developer Mode, and trust your Apple ID under Settings → General → VPN & Device Management. With a free Apple ID the app runs for 7 days, then `flutter run` installs it again.

## Accounts and the BT39 service

The defaults point at the BT39 project. To use another service or project, pass settings at build time:

```bash
flutter run \
  --dart-define=BT39_API=http://localhost:8000 \
  --dart-define=SUPABASE_URL=https://<project>.supabase.co \
  --dart-define=SUPABASE_KEY=<publishable key>
```

- **Everyone** signs up on the service (`POST /v1/pulse/signup`) and logs in with Supabase. Patients see their own records on any phone. Doctors and nurses get the real ward (`GET /v1/live`), alerts with Realtime, acknowledge and resolve, the doctor chat (`POST /v1/chat`) and every patient's records.
- What crosses between phones now really does: a booking with Dr. Kavya Rao shows in `doctor@pulseos.app`'s schedule, a prescription reaches the patient's medicine list, and a doctor's review of Jai's alert reaches `patient@pulseos.app`.
- The free Render plan sleeps after 15 minutes. The app shows "Waking up the server" for up to a minute.

## Languages and voice-over

- Text goes through `tr()` in `lib/l10n/l10n.dart`; Hindi lives in `lib/l10n/hi/*.dart`, keyed by the English text. `python3 tool/check_hi.py <files>` lists text without a Hindi translation, and `test/hindi_test.dart` opens every screen in Hindi and fails on any missing translation or overflow.
- The demo voice-over (`assets/voice/en`, `assets/voice/hi`) was recorded with the open-source Kokoro text-to-speech model. Edit `tool/voice_script.json` and run `tool/make_voice.py` to record it again (instructions at the top of the script).
- Hindi text uses the bundled Noto Sans Devanagari font, so it works offline.
- `demo-videos/` has the guided demo recorded with its voice-over in English and in Hindi, ready to send or play in a presentation.

## Research paper

`docs/RESEARCH.md` has the problem, the research gaps it addresses, the method, the simulation design, results tables, limitations and a paper outline. The numbers come from the study, which now runs on the service with the same results as the original `lib/engine/study.dart`; rerun them with `dart run tool/run_study.dart` or the Research Lab. They are from simulated patients, and the references must be checked before submission.

## What is simulated in this version

- **The wearable band.** The service's band simulator stands in for an ESP32 band (MAX30102 for HR and SpO₂, MLX90614 for temperature, MPU6050 for motion). A real band would post its readings to the service, which feeds the same engine.
- **Patient-side data** (profile, appointments, records, insurance, family) is saved on the service for each account. Record files are not uploaded, only their details.
- **The AI Health Assistant** runs on the service and answers only from your data, with the same rules as before. It never diagnoses or gives doses.
- **SOS messages** to contacts and the location are simulated and recorded on the service (there is no SMS provider). *Call 112* opens the real phone dialer.
- **Doctors, clinics and insurer updates** are example data.

## Project layout

```
lib/
  engine/      adapt_alert.dart (the engine's state as the service sends it), simulator.dart (scenario names and icons), study.dart (study results), news2.dart (labels)
  l10n/        l10n.dart (tr, language switch), msg.dart (shows the service's messages in your language), hi/ (Hindi strings)
  services/    pulse_api.dart (calls to the service), session.dart (auth, Demo Mode), tour.dart (guided demo), narrator.dart (voice-over), monitor.dart (the band, live), patient_store.dart, clinical_store.dart, assistant.dart, bt39_client.dart, staff_controller.dart
  models/      patient_models.dart
  screens/     auth/ (welcome, role_auth), research/ (Research Lab), patient/ (alert_detail, how_it_works, today, alerts, insights, care, doctors, appointment_editor, records, insurance, family, me, assistant, sos), staff/
  widgets/     common.dart (iOS components), vitals.dart (waveform, rings, gauge), charts.dart
  theme/       ios_theme.dart (iOS colours, light and dark)
test/          client/ (service calls, mirror, stores), every screen and every screen in Hindi against a fake service, live/ (guided demo against a real service)
```

## Credits

NEWS2 tables: Royal College of Physicians (2017). Backend: the BT39 monitor service. All people in the app are fictional.
