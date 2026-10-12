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
| Secure authentication: separate **log in and sign up for patients, doctors and nurses** (role-specific fields such as registration number, speciality, ward and shift), salted SHA-256 password hashes on the device, Supabase when a key is set, plus **Demo Mode** that needs no account | Welcome › Log in / Sign up |
| **Guided demo with a voice guide**: plays the whole AdaptAlert story (walk, loose band, coffee alert, doctor rejects, held back, real event, safety floor) with captions read aloud by the browser, then asks you to log in or sign up | Welcome › Watch the demo with voice |
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

## How AdaptAlert works

Every reading window (one simulated minute) goes through seven stages. The code is in `lib/engine/adapt_alert.dart`.

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

**30-day simulated study** (Insights tab, `lib/engine/study.dart`): 40 virtual patients compared on three systems, using the same decision code as the app. With the default seed, false alarms in week 5 fell from about 3.6 per patient per day (fixed thresholds) to about 0.06 (AdaptAlert), and every real event was caught. The event mix and rates are assumptions made for the simulation, not clinical data.

## Run it

You need Flutter 3.41 or newer. It was built and tested with Flutter 3.47.7.

```bash
flutter pub get
flutter run                 # phone or emulator
flutter run -d chrome       # web
flutter test                # 22 tests: engine, NEWS2, storage, auth, guided demo, every screen
dart run tool/run_study.dart # prints the research results as Markdown
flutter build apk --release
flutter build web --release --no-web-resources-cdn   # works offline, good for a viva
```

With no settings, accounts are stored on the device. Three demo accounts always exist:

| Role | Email | Password |
|---|---|---|
| Patient | patient@pulseos.app | patient123 |
| Doctor | doctor@pulseos.app | doctor123 |
| Nurse | nurse@pulseos.app | nurse123 |

You can also sign up as any role, or tap *Try without an account*. The demo patient is **Nandini Sharma**. A demo session is not remembered: reopening the site starts at the welcome page.

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

## Connect real accounts and the BT39 service (optional)

Pass settings at build time:

```bash
flutter run \
  --dart-define=SUPABASE_KEY=<publishable key> \
  --dart-define=SUPABASE_URL=https://rwoscuilmsvasohkmphu.supabase.co \
  --dart-define=BT39_API=https://bt39-monitor-service.onrender.com
```

- `SUPABASE_URL` and `BT39_API` default to the BT39 project. The publishable key isn't in the repository: copy it from Supabase › Project Settings › API.
- **Patients** can create an account by email. **Doctors and nurses** sign in with an account that has a row in the BT39 `staff` table. They then get the real live stream (`GET /v1/live`), alerts from Supabase with Realtime, acknowledge and resolve, and the doctor chat (`POST /v1/chat`).
- For the web build, add its exact origin to the service's `APP_ORIGIN` and to Supabase's Site URL and Redirect URLs (see the BT39 README, sections 2 and 5).
- The free Render plan sleeps after 15 minutes. The ward shows "Connecting…" for about a minute while it wakes.

## Research paper

`docs/RESEARCH.md` has the problem, the research gaps it addresses, the method, the simulation design, results tables, limitations and a paper outline. The numbers come from `lib/engine/study.dart`; rerun them with `dart run tool/run_study.dart` or the Research Lab. They are from simulated patients, and the references must be checked before submission.

## What is simulated in this version

- **The wearable band.** `BandSimulator` stands in for an ESP32 band (MAX30102 for HR and SpO₂, MLX90614 for temperature, MPU6050 for motion). To use real hardware, replace it with a BLE source that produces the same `Reading` objects; the engine doesn't change.
- **Patient-side data** (profile, appointments, records, insurance, family) is stored on the device with `shared_preferences`, separately for each account. Record files are not uploaded to a server.
- **The AI Health Assistant** runs on the device and answers only from your data. It never diagnoses or gives doses. To use a hosted language model, send the same context to it through a backend (never put an API key in the app).
- **SOS messages** to contacts and the location are simulated. *Call 112* opens the real phone dialer.
- **Doctors, clinics and insurer updates** are example data.

## Project layout

```
lib/
  engine/      adapt_alert.dart (7-stage engine), simulator.dart (band), study.dart (30-day study), news2.dart
  services/    session.dart (auth), tour.dart (guided demo), narrator.dart (voice), clinical_store.dart (doctor and nurse data), monitor.dart, patient_store.dart, assistant.dart, bt39_client.dart, staff_controller.dart
  models/      patient_models.dart
  screens/     auth/ (welcome, role_auth), research/ (Research Lab), patient/ (alert_detail, how_it_works, today, alerts, insights, care, doctors, appointment_editor, records, insurance, family, me, assistant, sos), staff/
  widgets/     common.dart (iOS components), vitals.dart (waveform, rings, gauge), charts.dart
  theme/       ios_theme.dart (iOS colours, light and dark)
test/          engine, NEWS2, storage, monitor story, and a test that opens every screen
```

## Credits

NEWS2 tables: Royal College of Physicians (2017). Backend: the BT39 monitor service. All people in the app are fictional.
