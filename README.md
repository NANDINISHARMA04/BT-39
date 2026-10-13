# PulseOS

**Health alerts that learn you.**

PulseOS is a health-monitoring app for patients, doctors and nurses. It runs on phones (Android and iOS) and in the browser, and it is built on a small server called the **BT39 service**. Three ideas sit at its heart:

- **AdaptAlert**, an alert engine that learns what is normal *for each person*, explains every alert in plain words, and learns from the answers people give it.
- **An AI chat** that answers questions from the person's own records, in English or Hindi, and shows exactly which records it used.
- **One app for everyone**: a patient app, and a doctor-and-nurse app, chosen at sign-in.

> This is a student research prototype (a B.Tech CSE major project). It is **not a medical device**. Every patient, doctor, clinic and insurer in it is made up.

## Why we built it

Most health monitors alert when a number crosses a fixed line, for example "heart rate above 100". A walk, a coffee or a loose sensor sets them off just the same. After enough false alarms, patients and doctors stop looking, and that is why many remote-monitoring trials fail.

AdaptAlert does three things differently. It learns what is normal for *you*, not for an average person. After every alert it asks "what was happening?" and remembers the answer, so it alerts less for patterns that turned out harmless for you. And it never ignores real danger: a hard safety floor always alerts, whatever it has learned.

## Screenshots

Everything below runs in **Demo Mode**, which needs no account. On the welcome page, tap *Patient*, *Doctor* or *Nurse* under "Just looking? Try without an account".

### For patients

<table>
<tr>
<td align="center"><img src="docs/screenshots/01-welcome.webp" width="230"><br><sub>Welcome, in English or Hindi</sub></td>
<td align="center"><img src="docs/screenshots/02-today.webp" width="230"><br><sub>Today: live vitals from the band</sub></td>
<td align="center"><img src="docs/screenshots/03-simulate.webp" width="230"><br><sub>Simulator: pick what happens next</sub></td>
</tr>
<tr>
<td align="center"><img src="docs/screenshots/04-alerts.webp" width="230"><br><sub>Alerts: fixed monitor vs AdaptAlert</sub></td>
<td align="center"><img src="docs/screenshots/05-alert-card.webp" width="230"><br><sub>Tell it what was happening</sub></td>
<td align="center"><img src="docs/screenshots/06-why-alert.webp" width="230"><br><sub>Why this alert: what the band saw</sub></td>
</tr>
<tr>
<td align="center"><img src="docs/screenshots/07-signals.webp" width="230"><br><sub>Which signals drove it</sub></td>
<td align="center"><img src="docs/screenshots/08-insights.webp" width="230"><br><sub>Insights: trends and your normal range</sub></td>
<td align="center"><img src="docs/screenshots/09-pipeline.webp" width="230"><br><sub>The live seven-stage engine</sub></td>
</tr>
<tr>
<td align="center"><img src="docs/screenshots/10-study.webp" width="230"><br><sub>30-day simulated study</sub></td>
<td align="center"><img src="docs/screenshots/11-care.webp" width="230"><br><sub>Care: appointments and doctors</sub></td>
<td align="center"><img src="docs/screenshots/12-me.webp" width="230"><br><sub>Me: records, insurance, family</sub></td>
</tr>
<tr>
<td align="center"><img src="docs/screenshots/13-assistant.webp" width="230"><br><sub>AI Health Assistant with help topics</sub></td>
<td align="center"><img src="docs/screenshots/14-chat-answer.webp" width="230"><br><sub>An answer that cites your records</sub></td>
<td align="center"><img src="docs/screenshots/15-sos.webp" width="230"><br><sub>Emergency SOS</sub></td>
</tr>
</table>

### For doctors and nurses

<table>
<tr>
<td align="center"><img src="docs/screenshots/20-doctor-today.webp" width="230"><br><sub>Doctor's Today: who needs you now</sub></td>
<td align="center"><img src="docs/screenshots/21-ward.webp" width="230"><br><sub>Ward: beds sorted by NEWS2 risk</sub></td>
<td align="center"><img src="docs/screenshots/24-bed.webp" width="230"><br><sub>A bed, with NEWS2 points per vital</sub></td>
</tr>
<tr>
<td align="center"><img src="docs/screenshots/25-bed-ask.webp" width="230"><br><sub>Acknowledge, resolve, label, ask</sub></td>
<td align="center"><img src="docs/screenshots/26-staff-ask.webp" width="230"><br><sub>"Is this sepsis?" answered from the bed's data</sub></td>
<td align="center"><img src="docs/screenshots/28-doctor-ask.webp" width="230"><br><sub>Ask across every patient you can see</sub></td>
</tr>
<tr>
<td align="center"><img src="docs/screenshots/22-patients.webp" width="230"><br><sub>Patients</sub></td>
<td align="center"><img src="docs/screenshots/27-patient-record.webp" width="230"><br><sub>A patient record with live vitals</sub></td>
<td align="center"><img src="docs/screenshots/23-schedule.webp" width="230"><br><sub>Schedule, including patient bookings</sub></td>
</tr>
<tr>
<td align="center"><img src="docs/screenshots/29-nurse-shift.webp" width="230"><br><sub>Nurse's shift: timed tasks and handover</sub></td>
<td align="center"><img src="docs/screenshots/30-research-lab.webp" width="230"><br><sub>Research Lab: rerun the experiments</sub></td>
<td align="center"></td>
</tr>
</table>

### Languages, dark mode and accessibility

<table>
<tr>
<td align="center"><img src="docs/screenshots/16-today-hi.webp" width="230"><br><sub>Every screen in Hindi</sub></td>
<td align="center"><img src="docs/screenshots/17-chat-hi.webp" width="230"><br><sub>The chat answers in Hindi too</sub></td>
<td align="center"><img src="docs/screenshots/18-today-dark.webp" width="230"><br><sub>Dark mode</sub></td>
</tr>
<tr>
<td align="center"><img src="docs/screenshots/19-accessibility.webp" width="230"><br><sub>Larger text, spoken and flashing alerts</sub></td>
<td align="center"></td>
<td align="center"></td>
</tr>
</table>

## What is in the app

**Patient app** (tabs: Today, Alerts, Insights, Care, Me)

- **Today**: live heart rate with a pulse waveform, oxygen, temperature, activity, signal quality and your personal normal range. A simulator lets you act out a walk, a loose band, coffee, a real event, an oxygen drop or a fever.
- **Alerts**: each alert gives plain reasons, a "likely real" score and feedback buttons (I was active, Sensor was loose, I feel unwell, Not sure). Alerts the engine chose to hold back are listed too. "See how AdaptAlert decided" shows the chart, the signals, the blend formula and who was told.
- **Insights**: trends with your normal band, alert load per hour, the engine's seven stages live, your sensitivity, what it has learned, and a 30-day simulated study.
- **Care**: book, reschedule and cancel appointments (video or clinic), search doctors by speciality, rating, fee, language or distance, and book a follow-up straight from an alert.
- **Me**: health profile and medicines, a records vault (PDFs and photos, shared with a doctor), insurance policies and claims with a status timeline, family members and a caregiver who is told when you do not answer, Emergency SOS and Medical ID, appearance, units, notifications and language.
- **AI Health Assistant**: a round Help button on every page. Ask "Why did I get my last alert?", "When is my next appointment?" or "report kahan hai?" and get an answer from your own data with a button that takes you there. Big help topics, a microphone to speak, and answers read aloud.
- **Emergency SOS**: hold to activate, call 112, alert your contacts, share location and live vitals. A safety-floor alert starts SOS on its own.
- **Guided demo with a voice-over**, in English or Hindi, that plays the whole story: walk, loose band, coffee alert, doctor rejects it, held back, real event, safety floor.
- **Accessibility**: larger and bold text, an easy home with four big buttons, screen flashes for hearing loss, spoken alerts for low vision, reduce motion, and words next to every colour.
- **Research Lab**: rerun the study with your own settings, with ablations, label noise, alarm fatigue and 95% confidence intervals, and copy the results as text for a paper.

**Doctor and nurse app** (tabs on phones, a sidebar on laptops)

- **Today** (doctor): alerts to review, appointments left, high-risk beds, unacknowledged alerts and a "needs you now" list.
- **My shift** (nurse): timed tasks such as vitals rounds, medicines and dressings, who ticked them off, and a handover note for the next shift.
- **Patients**: search and filter; anyone who signs up as a patient appears here. Each record shows live or last vitals, AdaptAlert status, conditions, allergies, medicines, visits, alerts, shared records and notes. Doctors write notes and prescriptions (with an allergy warning); nurses write nursing notes. A prescription reaches the patient's own medicine list.
- **Schedule**: a week of appointments, including the ones patients booked themselves. Mark seen, no-show or cancel; book a follow-up.
- **Ward**: beds sorted by risk with a live **NEWS2** score, the early-warning score hospitals use that adds points for each abnormal vital. A pulsing border marks unacknowledged emergencies. Each bed has NEWS2 points per vital, a two-minute trace, demo scenarios and a chat.
- **Alerts**: acknowledge, resolve with a note, and label *Real* or *False alarm*, which teaches the engine. **Ward rules** shows how often each rule was right, so the noisiest ones can be tuned first.
- **Ask**: the same AI chat, on Today, on every patient and on every bed, answering only from the patients that person can see.

## How AdaptAlert decides

Every simulated minute of band data goes through seven stages. In plain words: check the reading is trustworthy, work out what you were doing, compare with *your* normal, check the hard limits, look for a pattern, decide, explain.

| Stage | What it does |
|---|---|
| A. Signal quality | Scores skin contact, plausible values, sudden jumps and motion. Unreliable data never alerts and never changes your normal. |
| B. Activity | Resting, light activity, active, or cooling down, from the motion sensor. |
| C. Personal normal | A slowly updating average and spread per vital and activity. The *z-score* says how unusual a reading is for you: how many "usual spreads" (standard deviations) it sits from your average. |
| D. Safety floor | Oxygen (SpO₂, the oxygen level in the blood) at or below 91% for 2 minutes, resting heart rate at or above 131 or at or below 40, temperature at or above 39.1 °C or at or below 35.0 °C. Always alerts. Learning cannot switch it off. |
| E. Anomaly check | One vital outside your range for 3 minutes, or two vitals off together. |
| F. Decision | Blends a small, readable decision tree with your own history, then compares with your threshold. |
| G. Explanation | Plain words, for example "Heart rate 98 bpm, 48% above your usual resting 66 bpm for 2 min, while you were still." |

The decision is a blend: **P(real) = (1 − w) × P_model + w × P_you**. P_model is the tree's estimate for this pattern. P_you comes from the answers you and your doctor gave for the same pattern before. The weight w = n / (n + 4) grows with the number of answers n, so your history counts more the more it knows. An alert is sent when P(real) reaches your threshold **τ**, which starts at 50%, stays between 30% and 75%, and moves at most 10 points a week. A doctor's "false alarm" raises it a little; "confirmed real" lowers it more. "I feel unwell" and "Not sure" never make the app less sensitive.

Escalation goes you → caregiver (for warnings, or if you do not reply in 10 minutes) → doctor → SOS for critical alerts.

**30-day simulated study.** 40 virtual patients, 30 days, three systems compared with the same decision code the app uses. With the default seed, false alarms in week 5 fell from about 3.7 per patient per day (fixed thresholds) to about 0.1 (AdaptAlert), and every real event was caught. The event mix is an assumption made for the simulation, not clinical data. `docs/RESEARCH.md` has the full write-up.

## The AI chat, and how it stays cheap

The chat uses **retrieval-augmented generation**, usually shortened to RAG. In plain words: before the AI writes anything, the service looks up the few facts in *your* records that matter for the question, hands only those to a language model, and asks it to answer from them and nothing else. Every sentence carries a small number that points at the record it came from.

How the service does it:

- **Facts, not documents.** Each record (an alert, an appointment, a claim, a medicine, a ward bed) becomes a short fact with a stable *key* and fresh *text*. Only the key is turned into an embedding, so a record can change every minute without any new AI work.
- **Embeddings, made locally.** An embedding is a list of 384 numbers that captures what a sentence means, so similar sentences land near each other. The service makes them itself with a small open model (`bge-small`), never by calling a paid API.
- **Content-addressed vectors.** Each embedding is stored under a hash of its text. Two patients with the same kind of fact share one vector, and an edit only re-embeds the facts that changed. In our tests 95% of vectors were reused, and a day of edits cost 4 embeddings instead of 23.
- **Live numbers are never embedded.** The band right now, today's schedule, the nurse's tasks and the ward are added as short blocks of text at answer time.
- **Retrieval** ranks facts by meaning (cosine similarity), gives a bonus for matching words, and lets the app's own rules point at the most likely kind of fact. On a test set of questions it found the right fact first 92% of the time.
- **Hindi and Hinglish.** The embedding model only reads English, so common Hindi and Hinglish words are glossed before searching, and the model answers in the language you asked in.
- **Safety first.** Emergency words such as "chest pain" or "सीने में दर्द" show the SOS button before the AI says a word. The chat never diagnoses and never gives doses.
- **Never stuck.** If the model is busy or the budget is used up, a free rule-based answer comes instead.
- **A cache for repeated questions.** Answers are kept for three days, keyed by the exact facts they used, so the same question with the same records costs nothing, and near-duplicates are matched too. Cached answers are only reused when the facts match, so one person's answer can never reach another.
- **A hard budget.** The whole service may spend **$0.20 a day** on the language model (Qwen 3.7 Flash through OpenRouter). Each call reserves a small amount first, so a burst of questions cannot slip past the limit, and the total survives restarts. One model answer costs about $0.00004.
- **Privacy.** Question text is never logged; the service keeps only numbers (how long, how many facts, cache hit or not).

## How it is built

The app is a thin client: it shows what the service sends and passes taps back. Everything that decides, scores, simulates or stores lives on the service.

| On the BT39 service (Python) | In the app (Flutter) |
|---|---|
| The simulated band and the AdaptAlert engine, one per patient account, saved so learning survives closing the app | Screens, charts, colours and animations |
| The 30-day study and the Research Lab experiments | Hindi translation, number and date formats |
| Accounts and roles, sign-up for every role | Voice-over, speech, accessibility settings |
| Patient records: profile, family, appointments, free slots, records, insurance, claims | The phone dialler and the file picker |
| Care-team records: patients, notes, prescriptions, visits, nurse tasks, handovers | Typing animations and haptics |
| The AI chat, SOS steps and caregiver messages | |
| Demo Mode: a fresh private copy for each visitor, deleted when they leave | |

- **App**: Flutter 3.47, Provider for state, an iOS-style design in light and dark, bundled Noto Sans Devanagari for Hindi.
- **Service**: FastAPI on Render's free plan (it sleeps after 15 idle minutes, so the first open can take about a minute), Supabase Postgres for data with row-level security on, local embeddings with fastembed, and OpenRouter for the language model. Code and contract: [bt39-monitor-service](https://github.com/gxc-siddhartha/bt39-monitor-service), `api/bt39api/pulse/`, documented in its `docs/pulseos.md`.
- **Streaming**: chat answers arrive line by line (one small JSON object per line: a header, then text pieces, then a footer with the sources and the cost), so words appear as they are written.
- **Same results as before**: the service's Python code was replayed against the app's original Dart code (10,000 band minutes, the study, the demo ward, the assistant in both languages) and gives the same numbers and words.

## Run it

You need Flutter 3.41 or newer.

```bash
flutter pub get
flutter run                  # phone or emulator
flutter run -d chrome        # web
flutter test                 # 292 tests, every screen in English and Hindi, no network needed
flutter build apk --release
./tool/build_web.sh          # web build into deploy/web
```

The app talks to `https://bt39-monitor-service.onrender.com` by default (`lib/config.dart`; the Supabase key there is the public one). Three demo accounts exist, with made-up data only:

| Role | Email | Password |
|---|---|---|
| Patient | patient@pulseos.app | patient123 |
| Doctor | doctor@pulseos.app | doctor123 |
| Nurse | nurse@pulseos.app | nurse123 |

You can also sign up as any role, or tap *Try without an account*. To point the app at your own service or Supabase project:

```bash
flutter run --dart-define=BT39_API=http://localhost:8000 --dart-define=SUPABASE_URL=https://<project>.supabase.co --dart-define=SUPABASE_KEY=<publishable key>
```

**Web hosting.** `deploy/web` holds a ready-made build and `vercel.json` points Vercel at it, so importing this repository on vercel.com and pressing Deploy is enough. After a change, run `./tool/build_web.sh`, commit and push.

**iPhone.** With Xcode and a free Apple ID: open `ios/Runner.xcworkspace`, pick your team under Signing, then `flutter run` with the phone plugged in. Turn on Developer Mode on the phone and trust your Apple ID under VPN & Device Management.

**Five-minute demo.** Patient demo › Today › sliders icon. *Go for a walk*: no alert. *Loosen the band*: data ignored. *Coffee or stress*: an alert; mark it a false alarm as the doctor, run it again and it is held back. *Heart racing at rest*: an urgent alert with reasons. *Oxygen drop*: safety floor and the auto-SOS countdown. Then Insights, and the Doctor demo for the ward.

## Languages and voice

- Every string goes through `tr()` in `lib/l10n/l10n.dart`; Hindi lives in `lib/l10n/hi/`, keyed by the English text. `python3 tool/check_hi.py <files>` lists anything untranslated, and `test/hindi_test.dart` opens every screen in Hindi and fails on a missing translation or an overflow.
- The guided demo's voice-over (`assets/voice/`) was recorded with the open-source Kokoro text-to-speech model; `tool/make_voice.py` records it again from `tool/voice_script.json`. `demo-videos/` has the recorded demo in both languages.

## Project layout

```
lib/
  engine/     the engine's state as the service sends it, scenario names, study results, NEWS2 labels
  l10n/       tr(), the language switch, Hindi strings
  services/   calls to the service, auth and Demo Mode, the guided demo, voice-over, the band feed,
              patient and care-team stores, the chat stream and its controller
  screens/    auth, research (Research Lab), patient (today, alerts, insights, care, me, assistant, sos …),
              staff (today, shift, patients, schedule, ward, bed, ask …)
  widgets/    iOS components, vitals widgets, charts, chat bubbles and the chat view
  theme/      colours for light and dark
test/         service calls against a fake service, every screen in both languages, a live guided-demo test
tool/         build_web.sh, check_hi.py, make_voice.py, run_study.dart
docs/         RESEARCH.md, screenshots/
deploy/web    the built web app
```

## What is simulated, and known limits

- **The wearable band** is simulated on the service. It stands in for a real band with heart rate, oxygen, temperature and motion sensors, which would post readings to the same engine.
- **Record files** are not uploaded, only their details. **SOS messages** and location sharing are recorded on the service rather than sent; *Call 112* opens the real dialler. **Doctors, clinics and insurer updates** are example data.
- A doctor or nurse who signs up can see every patient. That is fine for a demo and not for real health data, so **use made-up data only**.
- The app needs an internet connection, and the free server can take a minute to wake up.
- Phone builds were not tried for the latest version; it was tested in the browser. Real ward beds (for signed-in staff) still use the older doctor chat; demo beds use the new one.

## Credits

NEWS2 tables: Royal College of Physicians (2017). Backend: the BT39 monitor service. Everyone in the app is fictional.
