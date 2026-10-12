import 'package:intl/intl.dart';

import '../engine/adapt_alert.dart';
import '../l10n/l10n.dart';
import '../models/patient_models.dart';
import 'monitor.dart';
import 'patient_store.dart';

class AssistantReply {
  AssistantReply(this.text, {this.action, this.actionLabel, this.urgent = false, this.topic, this.suggestions = const []});
  final String text;

  /// A place the reply offers to open. See [HealthAssistant.actions].
  final String? action;
  final String? actionLabel;
  final bool urgent;

  /// Which help topic answered, e.g. 'records' or 'language'. Null for
  /// answers from the person's health data.
  final String? topic;

  /// Follow-up questions to offer as buttons (English keys; show and send
  /// them with tr()).
  final List<String> suggestions;
}

/// One "where is / how do I" topic.
class _Topic {
  const _Topic(this.id, this.words, {this.ask = false, this.also});
  final String id;

  /// Any of these (English, Hindi or Hinglish) names the topic. A leading or
  /// trailing space means a word boundary.
  final List<String> words;

  /// Only when the question asks where/how ("kahan", "kaise", "open"...),
  /// so that "What medicines do I take?" still lists the medicines.
  final bool ask;

  /// When set, one of these must also be in the question.
  final List<String>? also;
}

/// The AI Health Assistant. It answers from the user's own data: live vitals,
/// AdaptAlert alerts and what the engine learned, medicines, appointments,
/// records and insurance. It also tells people where things are in the app,
/// in short steps, with a button that goes straight there. It explains; it
/// never diagnoses or changes a dose.
///
/// This version runs on the device so the demo works offline. The README shows
/// how to route the same context to a hosted language model through a backend.
class HealthAssistant {
  HealthAssistant(this.monitor, this.store);
  final MonitorController monitor;
  final PatientStore store;

  /// Every action a reply can carry; the assistant screen opens each one.
  static const actions = {
    'sos', 'records', 'healthProfile', 'insurance', 'family', 'callFamily', 'medicalId', 'book', 'findDoctor',
    'alerts', 'alertDetail', 'insights', 'howItWorks', 'research', 'me', 'language', 'accessibility', 'simulator',
  };

  /// Suggested questions (English keys; show and send them with tr()).
  static const suggestions = [
    'How am I doing today?',
    'Why did I get my last alert?',
    'What has AdaptAlert learned about me?',
    'When is my next appointment?',
    'What medicines do I take?',
    'Is my insurance claim approved?',
    'I have chest pain',
  ];

  /// Offered when a question isn't understood (English keys).
  static const helpSuggestions = [
    'Where are my reports?',
    'Where are my medicines?',
    'How do I book an appointment?',
    'How am I doing today?',
    'How do I change the language?',
    'I feel unwell',
  ];

  bool _has(String q, List<String> words) => words.any(q.contains);

  /// Makes Hindi spellings comparable: drops the nukta (ड़ → ड, ज़ → ज) and
  /// treats chandrabindu like anusvara (साँस → सांस).
  static String _norm(String s) {
    final b = StringBuffer();
    for (final r in s.toLowerCase().runes) {
      if (r >= 0x0958 && r <= 0x095F) {
        b.writeCharCode(const [0x0915, 0x0916, 0x0917, 0x091C, 0x0921, 0x0922, 0x092B, 0x092F][r - 0x0958]);
      } else if (r == 0x093C) {
        continue;
      } else if (r == 0x0901) {
        b.writeCharCode(0x0902);
      } else {
        b.writeCharCode(r);
      }
    }
    return b.toString();
  }

  /// Hindi / Hinglish keywords. Checked on the normalised question.
  bool _hasHi(String q, List<String> words) => words.any((w) => q.contains(_norm(w)));

  static const _hiEmergency = [
    'सीने में दर्द', 'सीने मे दर्द', 'सीने में तेज', 'छाती में दर्द', 'छाती मे दर्द', 'सांस नहीं', 'सांस नही', 'सांस लेने में', 'सांस फूल',
    'बेहोश', 'लकवा', 'स्ट्रोक', 'तेज दर्द', 'बहुत दर्द', 'खून बह',
    'seene mein dard', 'seene me dard', 'sine mein dard', 'sine me dard', 'chhati mein dard', 'chhati me dard', 'chati me dard',
    'chest mein dard', 'chest me dard', 'saans nahi', 'sans nahi', 'saans nahin', 'behosh',
  ];
  static const _hiEmergencyWord = ['इमरजेंसी', 'एमरजेंसी', 'आपातकाल', 'एसओएस'];
  static const _hiAlert = ['अलर्ट', 'क्यों', 'क्यूं', 'चेतावनी', 'alert kyu', 'alert kyon'];
  static const _hiLearn = ['सीखा', 'सीख', 'संवेदनशीलता', 'झूठा', 'झूठे', 'रोका', 'रोके', 'seekha', 'sikha'];
  static const _hiAppt = ['अपॉइंटमेंट', 'अपोइंटमेंट', 'अपाइंटमेंट', 'डॉक्टर', 'डाक्टर', 'बुक'];
  static const _hiBook = ['बुक', 'नया', 'नई'];
  static const _hiMeds = ['दवा', 'दवाई', 'गोली', 'खुराक', 'डोज', 'dawa', 'dawai', 'davai', 'goliyan'];
  static const _hiInsurance = ['बीमा', 'क्लेम', 'इंश्योरेंस', 'पॉलिसी', 'beema', 'bima claim'];
  static const _hiRecords = ['रिकॉर्ड', 'रिकार्ड', 'रिपोर्ट', 'जांच', 'एक्स-रे', 'एक्सरे', 'डिस्चार्ज', 'टेस्ट'];
  static const _hiFamily = ['परिवार', 'बेटी', 'बेटा', 'पत्नी', 'पति ', 'देखभाल', 'संपर्क', 'parivar'];
  static const _hiHeart = ['धड़कन', 'धडकन', 'दिल', 'नब्ज', 'पल्स', 'हार्ट', 'dhadkan', 'dhadakan', 'nabz'];
  static const _hiOxygen = ['ऑक्सीजन', 'आक्सीजन', 'ऑक्सिजन', 'ओक्सीजन', 'सांस', 'saans'];
  static const _hiTemp = ['बुखार', 'तापमान', 'टेम्परेचर', 'bukhar', 'bukhaar'];

  /// Words that make a question a "where is / how do I" question.
  static const _ask = [
    ' where ', ' wheres ', ' find ', ' open ', ' show ', ' go to ', ' take me ', ' change ', ' upload ', ' add ', ' edit ',
    ' update ', ' turn on ', ' turn off ', ' switch ', ' help me ', ' look at ', ' see ', ' view ', ' reply ', ' respond ',
    ' answer ', ' cancel ', ' reschedule ', ' book ', ' call ', ' use ', ' set up ', ' setup ', ' enable ', ' disable ',
    ' how do ', ' how can ', ' how to ', ' how does ', ' how should ', ' locate ', ' access ', ' get to ',
    'कहा', 'किधर', 'कैसे', 'खोल', 'दिखा', 'बदल', 'अपलोड', 'जोड', 'डाल', 'ढूंढ', 'ढूढ', 'मिलेग', 'मिलती', 'मिलता',
    'देखू', 'देखें', 'देखना', 'देखने', 'बुक', 'कॉल', 'फोन', 'चालू', 'बंद कर',
    ' kahan ', ' kaha ', ' kahaan ', ' kidhar ', ' kaise ', ' kese ', ' kaisey ', ' khol', ' dikha', ' badal', ' badlu',
    ' badle', ' jod', ' daal', ' dhund', ' dhoond', ' milega', ' milegi', ' milta', ' milti', ' dekh', ' chalu',
  ];

  static const _familyPeople = [
    ' family', ' parivar', 'परिवार', 'घर वाल', ' ghar wal', 'caregiver', ' daughter', ' son ', ' wife', ' husband', ' mother',
    ' father', ' mom ', ' dad ', ' mummy', ' papa', ' beti', ' beta ', 'बेटी', 'बेटा', 'बेटे', 'पत्नी', ' pati ', ' पति ',
    ' मां ', ' माँ ', 'मम्मी', 'पापा', 'पिता', ' bhai', ' भाई', ' behen', 'बहन', 'emergency contact',
  ];
  static const _doctorWords = [' doctor', ' dr ', 'डॉक्टर', 'डाक्टर', 'specialist', 'cardiolog', 'विशेषज्ञ'];

  /// First match wins, so the more specific topics come first.
  static const _topics = [
    _Topic('callFamily', _familyPeople, also: [' call', ' phone', ' ring', 'फोन', 'कॉल', ' baat', 'बात']),
    _Topic('talkDoctor', _doctorWords, also: [' talk', ' speak', ' baat', 'बात', ' video', 'वीडियो', ' consult', 'सलाह', ' salah', ' chat with', ' message']),
    _Topic('family', [' family', ' parivar', 'परिवार', ' contact', 'संपर्क', 'caregiver', 'देखभाल करने', ' ghar wal', 'घर वाल'], ask: true),
    _Topic('medicalId', ['medical id', 'मेडिकल आईडी', 'मेडिकल id', 'blood group', 'ब्लड ग्रुप', 'responder', ' id card', 'emergency card']),
    _Topic('sos', [' sos ', 'एसओएस', ' 112 ', 'emergency', 'इमरजेंसी', 'एमरजेंसी', 'आपातकाल', 'ambulance', 'एम्बुलेंस', 'एंबुलेंस'], ask: true),
    _Topic('unwell', [
      'unwell', 'not feeling well', 'not well', 'feel sick', 'feeling sick', 'feel bad', 'feeling bad', 'feel weak', 'dizzy',
      'nauseous', 'चक्कर', 'तबीयत ठीक नहीं', 'तबियत ठीक नहीं', 'तबीयत खराब', 'तबियत खराब', 'ठीक नहीं लग', 'ठीक महसूस नहीं',
      'बीमार लग', 'बीमार हू', 'कमजोरी', 'घबराहट', 'जी मिचला', ' tabiyat kharab', ' tabiyat theek nahi', ' tabiyat thik nahi',
      ' theek nahi lag', ' thik nahi lag', ' bimar hu', ' bimaar hu', ' chakkar', ' kamzori', ' ghabrahat', ' ji ghabra',
    ]),
    _Topic('held', [' held', ' hold', 'रोके', 'रोका', ' roka', ' roke', 'hidden', 'silenced', 'not sent'], ask: true),
    _Topic('records', [
      ' record', ' report', 'रिपोर्ट', 'रिकॉर्ड', 'रिकार्ड', 'lab report', 'lab result', 'lab test', 'blood test', ' x ray', ' xray', 'एक्स रे', 'एक्सरे', ' scan',
      'स्कैन', 'prescription', 'पर्चा', 'पर्ची', ' parcha', ' parchi', 'जांच', ' jaanch', ' janch', 'discharge', 'डिस्चार्ज',
      'टेस्ट', ' document', ' pdf', ' file',
    ], ask: true),
    _Topic('healthProfile', [
      ' medicine', ' medication', ' tablet', ' pill', ' dawa', ' dawai', ' davai', ' davaa', 'दवा', 'दवाई', 'गोली', 'condition',
      'बीमारी', ' bimari', ' bimaari', 'allerg', 'एलर्जी', 'health profile', 'हेल्थ प्रोफाइल', ' profile', 'प्रोफाइल', ' dose', 'खुराक',
    ], ask: true),
    _Topic('insurance', [' insurance', ' claim', ' policy', ' beema', ' bima', 'बीमा', 'क्लेम', 'पॉलिसी', 'इंश्योरेंस', 'cashless'], ask: true),
    _Topic('appointment', ['appointment', 'अपॉइंटमेंट', 'अपोइंटमेंट', 'अपाइंटमेंट', ' book', ' reschedule', ' visit', 'मुलाकात'], ask: true),
    _Topic('findDoctor', _doctorWords, ask: true),
    _Topic('alerts', [' alert', 'अलर्ट', ' alarm', 'चेतावनी'], ask: true),
    _Topic('research', ['research', 'रिसर्च', 'experiment', 'प्रयोग', ' study', 'स्टडी']),
    _Topic('howItWorks', ['adaptalert', 'adapt alert', ' the ai', ' ai ', 'एआई', 'this app', 'ये ऐप', 'यह ऐप', ' app ', 'ऐप'],
        also: [' how ', ' work', 'कैसे', 'काम', ' kaise', ' kaam', 'explain', 'समझा', ' samjha', 'what is']),
    _Topic('trends', [' trend', ' chart', ' graph', ' insight', 'ट्रेंड', 'चार्ट', 'ग्राफ', 'पिछली रीडिंग', 'पुरानी रीडिंग', 'old readings', 'past readings']),
    _Topic('language', ['language', ' bhasha', 'भाषा', ' hindi', 'हिंदी', 'हिन्दी', ' english', 'अंग्रेजी', 'इंग्लिश', ' angrezi']),
    _Topic('appearance', [' dark', 'डार्क', ' theme', 'थीम', 'appearance', 'night mode', 'नाइट मोड', 'light mode', 'brightness']),
    _Topic('notifications', ['notification', 'नोटिफिकेशन', 'सूचना', ' suchna', ' buzz', 'vibrat', ' sound', 'आवाज', ' awaaz', ' aawaz']),
    _Topic('accessibility', [
      'text size', ' font', 'bigger', 'larger', 'big text', 'small text', 'easy mode', 'easy home', 'accessib', ' zoom',
      'read aloud', 'अक्षर', ' akshar', 'बड़े अक्षर', ' bada text', ' bade akshar', 'आसान', ' aasan', ' asaan', 'दिखाई नहीं',
      ' dikhai nahi', 'पढ़ नहीं', ' padh nahi', 'छोटा', 'छोटे', ' chhota', ' chote', 'बोलकर', 'सुनाओ', ' sunao',
    ]),
    _Topic('simulator', ['simulat', 'scenario', 'सिम्युलेटर', 'सिमुलेटर', 'सिमुलेट', 'सिम्युलेट', ' demo', 'डेमो']),
    _Topic('signOut', ['sign out', 'signout', 'log out', 'logout', 'लॉग आउट', 'साइन आउट', 'बाहर निकल', ' bahar nikal']),
    _Topic('levels', [' colour', ' color', 'alert level', 'अलर्ट लेवल', ' levels', ' check in', 'warning', 'urgent', 'critical', 'हालचाल', 'चेतावनी', 'जरूरी', 'गंभीर', 'रंग', ' rang '],
        also: [' mean', ' what is', ' what are', ' what does', ' colour', ' color', ' levels', 'मतलब', 'रंग', 'लेवल', ' matlab', ' rang ', ' kya hai', 'क्या है', 'क्या होता']),
    _Topic('spo2', [' spo2', ' spo₂', ' sp02', 'saturation', 'एसपीओ2'], also: [' what', ' mean', ' kya', 'क्या', 'मतलब', ' matlab', 'explain', 'समझा']),
    _Topic('ranges', [
      'normal range', 'normal heart', 'normal pulse', 'normal oxygen', 'normal spo', 'normal temp', 'normal level', 'normal bp',
      'what is normal', 'healthy range', 'should my heart', 'should my oxygen', 'should my temp', 'सामान्य', 'नॉर्मल', ' normal kitna',
      ' normal kya', ' kitna hona', ' kitni honi', 'कितना होना', 'कितनी होनी', 'कितना होता', 'कितनी होती',
    ]),
    _Topic('band', [' band', 'बैंड', ' wrist', 'कलाई', ' strap', ' sensor', 'सेंसर', ' wearable']),
    _Topic('menu', [' help', 'what can you do', ' madad', 'मदद', 'सहायता', ' kya kar sakte', 'क्या कर सकते', ' menu']),
  ];

  static const _status = [
    ' how am i', ' how are my', ' doing', ' status', ' vitals', ' summary', ' overview', ' am i ok', ' am i fine', ' am i alright',
    ' my health', ' reading', ' how is my', ' today', 'कैसा हू', 'कैसी हू', 'कैसा है', 'कैसी है', 'सेहत', 'हालत', ' हाल ', 'रीडिंग',
    'ठीक हू', 'ठीक हैं', 'तबीयत कैसी', ' आज ', ' kaisa ', ' kaisi ', ' sehat', ' haal', ' theek hu', ' thik hu', ' tabiyat kaisi',
  ];

  /// Numbered steps: intro, then "1. …", "2. …", then an optional closing line.
  static String _steps(String intro, List<String> steps, [String? outro]) =>
      '$intro\n\n${[for (final (i, s) in steps.indexed) '${i + 1}. $s'].join('\n')}${outro == null || outro.isEmpty ? '' : '\n\n$outro'}';

  AssistantReply reply(String raw) {
    final q = raw.toLowerCase();
    final h = _norm(raw);
    // Words with spaces round them, so ' son ' can't match "reason".
    final w = ' ${h.replaceAll(RegExp(r'[^\p{L}\p{M}\p{N}]+', unicode: true), ' ')} ';
    final ask = _hasHi(w, _ask);
    final e = monitor.engine;
    final r = e.last;

    final symptom = _has(q, ['chest pain', 'can\'t breathe', 'cannot breathe', 'breathless', 'faint', 'unconscious', 'stroke', 'severe pain', 'bleeding']) || _hasHi(h, _hiEmergency);
    final emergencyWord = (_has(q, ['emergency']) || _hasHi(h, _hiEmergencyWord) || RegExp(r'\bsos\b').hasMatch(q)) && !_hasHi(w, [' contact', 'संपर्क', ' card']);
    if (symptom || (emergencyWord && !ask)) {
      return AssistantReply(
        '${tr('This could be an emergency. Please don\'t wait for an alert.')}\n\n'
        '• ${tr('Call 112 now, or press SOS to call and alert {names}.', {'names': _contactNames()})}\n'
        '• ${tr('Sit upright and rest. Don\'t drive yourself.')}\n'
        '• ${tr('If a doctor has told you to take a medicine for chest pain, follow that plan.')}\n\n'
        '${tr('Your band will keep sending your vitals to Dr. Rao.')}',
        action: 'sos',
        actionLabel: tr('Open SOS'),
        urgent: true,
      );
    }

    for (final t in _topics) {
      if (t.ask && !ask) continue;
      if (!_hasHi(w, t.words)) continue;
      if (t.also != null && !_hasHi(w, t.also!)) continue;
      return _help(t.id);
    }

    // "What has AdaptAlert learned" mentions "alert" too, so check learning first.
    final hiLearn = _hasHi(h, _hiLearn) || _has(q, ['learn', 'sensitivity', 'false alarm']);
    if (!hiLearn && (_has(q, ['why', 'last alert', 'alert']) || _hasHi(h, _hiAlert))) {
      final how = tr('To see this for any alert: open Alerts, tap the alert, then tap "See how AdaptAlert decided".');
      if (e.alerts.isEmpty) return AssistantReply('${tr('You have had no alerts today. AdaptAlert is watching your heart rate, oxygen and temperature against your own normal ranges.')}\n\n$how');
      final a = e.alerts.first;
      final status = a.doctor == DoctorLabel.confirmed
          ? tr('Dr. Rao confirmed it was real.')
          : a.doctor == DoctorLabel.rejected
              ? tr('Dr. Rao marked it as a false alarm, so similar patterns will be held back for you.')
              : tr('Dr. Rao hasn\'t reviewed it yet.');
      final args = {'p': pct(a.p), 'tau': pct(a.tau)};
      return AssistantReply(
        '${tr('Your last alert was "{title}" at {time} ({level}).', {'title': trData(a.title), 'time': hhmm(a.t), 'level': trData(a.levelLabel)})}\n\n'
        '${tr('Why it was sent:')}\n${a.reasons.map((x) => '• ${trData(x)}').join('\n')}\n\n'
        '${a.safety ? tr('The AI rated it {p} likely to be real. It sends alerts when it is at least {tau} sure, but this one hit a safety limit, so it was sent regardless.', args) : tr('The AI rated it {p} likely to be real. It sends alerts when it is at least {tau} sure.', args)} $status\n\n$how',
        action: 'alertDetail',
        actionLabel: tr('See how AdaptAlert decided'),
      );
    }

    if (hiLearn || _has(q, ['learn', 'learned', 'sensitivity', 'false alarm', 'held'])) {
      final ks = e.buckets.keys.toList();
      if (ks.isEmpty) return AssistantReply(tr('Nothing yet. When you answer an alert, or Dr. Rao reviews one, AdaptAlert learns which patterns are harmless for you.'));
      final lines = ks.map((k) {
        final p = e.bucketP(k);
        return '• ${bucketLabel(k)}: ${p >= e.tau ? tr('now {p} likely real, so it still alerts.', {'p': pct(p)}) : tr('now {p} likely real, so it is held back.', {'p': pct(p)})}';
      }).join('\n');
      final held = e.held.length;
      return AssistantReply(
        '${tr('From {n} feedback answers, AdaptAlert has learned:', {'n': e.labels})}\n$lines\n\n'
        '${tr('Your alert threshold is {tau}. It can only move between 30% and 75%, at most 10 points a week.', {'tau': pct(e.tau)})} '
        '${held == 0 ? '' : '${held == 1 ? tr('It has held back {n} alert today.', {'n': held}) : tr('It has held back {n} alerts today.', {'n': held})} '}'
        '${tr('Safety limits like oxygen at or below 91% always alert.')}',
        action: 'insights',
        actionLabel: tr('Open AI Engine'),
      );
    }

    if (_has(q, ['appointment', 'doctor', 'book', 'consult', 'visit']) || _hasHi(h, _hiAppt)) {
      final up = store.upcoming;
      if (_has(q, ['book', 'new', 'schedule']) || _hasHi(h, _hiBook) || up.isEmpty) {
        return AssistantReply(up.isEmpty ? tr('You have no upcoming appointments. Want to book one?') : tr('Sure. You can pick a doctor by speciality, language and fee.'), action: 'book', actionLabel: tr('Find a doctor'));
      }
      final a = up.first;
      final d = doctorById(a.doctorId);
      final who = store.memberName(a.forMember);
      final args = {
        'doctor': d.name,
        'specialty': trData(d.specialty),
        'date': DateFormat('EEE d MMM, h:mm a').format(a.at),
        'where': a.mode == ApptMode.video ? tr('by video') : tr('at {hospital}', {'hospital': d.hospital}),
        'who': who,
      };
      return AssistantReply(
        '${who == 'You' ? tr('Your next appointment is with {doctor} ({specialty}) on {date}, {where}, for you.', args) : tr('Your next appointment is with {doctor} ({specialty}) on {date}, {where}, for {who}.', args)}\n'
        '${tr('Reason: {reason}.', {'reason': trData(a.reason)})}'
        '${up.length > 1 ? '\n\n${tr('You have {n} more coming up.', {'n': up.length - 1})}' : ''}',
        action: 'book',
        actionLabel: tr('Manage appointments'),
      );
    }

    if (_has(q, ['medicine', 'medication', 'tablet', 'pill', 'dose']) || _hasHi(h, _hiMeds)) {
      final m = store.profile.medications;
      if (m.isEmpty) return AssistantReply(tr('You haven\'t added any medicines. Add them under Me > Health profile.'), action: 'healthProfile', actionLabel: tr('Open health profile'));
      return AssistantReply(
        '${tr('Your medicines:')}\n${m.map((x) => '• ${x.name} ${x.dose}: ${trData(x.schedule)}').join('\n')}\n\n'
        '${tr('I can explain what\'s on your list, but please ask Dr. Rao before changing any dose.')}${store.profile.allergies.isEmpty ? '' : '\n${tr('Allergies on file: {list}.', {'list': store.profile.allergies.map(trData).join(', ')})}'}',
        action: 'healthProfile',
        actionLabel: tr('Open health profile'),
      );
    }

    if (_has(q, ['insurance', 'claim', 'policy', 'cover']) || _hasHi(h, _hiInsurance)) {
      if (store.policies.isEmpty) return AssistantReply(tr('No insurance policy is saved yet.'), action: 'insurance', actionLabel: tr('Add a policy'));
      final p = store.policies.first;
      final used = store.usedOf(p);
      final cl = store.claims.where((c) => c.policyId == p.id).toList();
      final f = NumberFormat.decimalPattern('en_IN');
      return AssistantReply(
        '${p.insurer} ${p.plan}: ${tr('₹{left} left of ₹{total}, valid till {date}.', {'left': f.format(p.sumInsured - used), 'total': f.format(p.sumInsured), 'date': DateFormat('d MMM y').format(p.validTill)})}\n\n'
        '${cl.isEmpty ? tr('No claims yet.') : cl.map((c) => '• ${trData(c.title)}: ${trData(claimStatusLabel[c.status]!)}${c.approved != null ? ' (${tr('₹{amount} approved', {'amount': f.format(c.approved)})})' : ''}').join('\n')}',
        action: 'insurance',
        actionLabel: tr('Open insurance'),
      );
    }

    if (_has(q, ['record', 'report', 'lab', 'x-ray', 'xray', 'discharge']) || _hasHi(h, _hiRecords)) {
      final recs = store.records.where((x) => x.forMember == 'self').take(4);
      return AssistantReply('${tr('Your latest records:')}\n${recs.map((x) => '• ${trData(x.title)} (${trData(x.category)}, ${DateFormat('d MMM').format(x.date)})${x.notes.isEmpty ? '' : ': ${trData(x.notes)}'}').join('\n')}', action: 'records', actionLabel: tr('Open records'));
    }

    if (_has(q, ['family', 'daughter', 'wife', 'caregiver', 'contact']) || _hasHi(h, _hiFamily)) {
      return AssistantReply(_familyLines(), action: 'family', actionLabel: tr('Manage family'));
    }

    final heart = _has(q, ['heart', 'pulse', 'bpm']) || _hasHi(h, _hiHeart);
    final oxygen = _has(q, ['oxygen', 'spo2', 'saturation', 'breath']) || _hasHi(h, _hiOxygen);
    final temp = _has(q, ['temperature', 'fever', 'temp']) || _hasHi(h, _hiTemp);
    final status = _hasHi(w, _status);
    if (!heart && !oxygen && !temp && !status) return _fallback();

    if (r == null || !r.good) {
      return AssistantReply(tr('I can\'t read your band clearly right now. Please check that it\'s snug on your wrist. Readings that aren\'t reliable are ignored, so they can\'t cause false alarms.'));
    }

    String nowLine() => switch (r.act) {
          'Resting' => tr('You are resting right now.'),
          'Active' => tr('You are active right now.'),
          'Light activity' => tr('You are light activity right now.'),
          'Cooling down' => tr('You are cooling down right now.'),
          _ => tr('You are {act} right now.', {'act': r.act.toLowerCase()}),
        };

    if (heart) return AssistantReply('${_vitalLine('hr')}\n${nowLine()}', action: 'insights', actionLabel: tr('See trend'));
    if (oxygen) return AssistantReply('${_vitalLine('spo2')}\n${tr('AdaptAlert always alerts if oxygen stays at or below 91% for 2 minutes.')}', action: 'insights', actionLabel: tr('See trend'));
    if (temp) return AssistantReply(_vitalLine('temp'), action: 'insights', actionLabel: tr('See trend'));

    final open = e.alerts.where((a) => a.patientFeedback == null).length;
    final summary = switch (e.status) {
      'alert' => tr('An alert is active right now.'),
      'watch' => tr('Something is a little off, and AdaptAlert is watching it.'),
      'held' => tr('A pattern you marked harmless before is happening. No alert needed.'),
      _ => tr('Everything is inside your personal normal range.'),
    };
    final today = {'sent': e.sentCount, 'held': e.held.length, 'fixed': e.fixedCount};
    return AssistantReply(
      '$summary\n\n• ${_vitalLine('hr')}\n• ${_vitalLine('spo2')}\n• ${_vitalLine('temp')}\n\n'
      '${e.sentCount == 1 ? tr('Today: {sent} alert sent, {held} held back. A fixed-threshold monitor would have alarmed {fixed} times.', today) : tr('Today: {sent} alerts sent, {held} held back. A fixed-threshold monitor would have alarmed {fixed} times.', today)}'
      '${open > 0 ? '\n${open == 1 ? tr('{n} alert needs your reply.', {'n': open}) : tr('{n} alerts need your reply.', {'n': open})}' : ''}',
      action: open > 0 ? 'alerts' : null,
      actionLabel: open > 0 ? tr('Reply to alerts') : null,
    );
  }

  String _contactNames() => store.emergencyContacts.map((m) => m.name.split(' ').first).join(tr(' and '));

  String _familyLines() {
    final cg = store.caregiver;
    return '${cg == null ? tr('No caregiver is set.') : tr('{name} ({relation}) is your caregiver and gets an alert if you don\'t reply to one within 10 minutes.', {'name': cg.name, 'relation': trData(cg.relation)})}\n'
        '${store.emergencyContacts.isEmpty ? tr('Emergency contacts: none.') : tr('Emergency contacts: {names}.', {'names': store.emergencyContacts.map((m) => m.name).join(', ')})}';
  }

  /// One line about a vital sign compared with the person's own normal.
  /// Only call when the latest reading is good.
  String _vitalLine(String v) {
    final r = monitor.engine.last!;
    final z = r.z[v]!;
    final word = z.abs() < 1.5 ? tr('normal for you') : (z > 0 ? tr('above your normal') : tr('below your normal'));
    return switch (v) {
      'hr' => r.ctx == 'rest'
          ? tr('Heart rate {hr} bpm, {word} (usual {usual} when resting).', {'hr': r.r.hr, 'word': word, 'usual': r.mu['hr']!.round()})
          : tr('Heart rate {hr} bpm, {word} (usual {usual} when active).', {'hr': r.r.hr, 'word': word, 'usual': r.mu['hr']!.round()}),
      'spo2' => tr('Oxygen {spo2}%, {word} (usual {usual}%).', {'spo2': r.r.spo2, 'word': word, 'usual': r.mu['spo2']!.round()}),
      _ => tr('Temperature {temp} °C, {word} (usual {usual} °C).', {'temp': r.r.temp.toStringAsFixed(1), 'word': word, 'usual': r.mu['temp']!.toStringAsFixed(1)}),
    };
  }

  bool get _goodReading => monitor.engine.last?.good ?? false;

  /// The answer for a "where is / how do I" topic.
  AssistantReply _help(String id) {
    final tapMe = tr('Tap Me at the bottom of the screen.');
    AssistantReply help(String text, String? action, String? label, {bool urgent = false, List<String> suggestions = const []}) =>
        AssistantReply(text, action: action, actionLabel: label, urgent: urgent, topic: id, suggestions: suggestions);
    switch (id) {
      case 'records':
        return help(
          _steps(tr('Your reports and medical records are kept in Me → Medical records.'), [tapMe, tr('Tap Medical records.'), tr('To add a report, tap + at the top and choose a photo or PDF.')]),
          'records',
          tr('Open medical records'),
        );
      case 'healthProfile':
        final n = store.profile.medications.length;
        return help(
          _steps(tr('Your medicines, conditions and allergies are in Me → Health profile.'), [tapMe, tr('Tap Health profile.'), tr('Add or change a medicine, then tap Save.')],
              n == 0 ? '' : (n == 1 ? tr('You have {n} medicine saved.', {'n': n}) : tr('You have {n} medicines saved.', {'n': n}))),
          'healthProfile',
          tr('Open health profile'),
        );
      case 'insurance':
        return help(
          _steps(tr('Your insurance policies and claims are in Me → Insurance & claims.'), [tapMe, tr('Tap Insurance & claims.'), tr('Tap a claim to see its status, or tap + to add a policy or claim.')]),
          'insurance',
          tr('Open insurance'),
        );
      case 'family':
        return help(
          _steps(tr('Your family, emergency contacts and caregiver are in Me → Family.'), [tapMe, tr('Tap Family.'), tr('Tap a person to call them, or to make them your caregiver or emergency contact.')], _familyLines()),
          'family',
          tr('Open family'),
        );
      case 'callFamily':
        final who = store.caregiver ?? store.emergencyContacts.firstOrNull ?? store.family.where((m) => m.phone.isNotEmpty).firstOrNull;
        if (who == null || who.phone.isEmpty) {
          return help(tr('No family member with a phone number is saved yet. Add one in Me → Family.'), 'family', tr('Open family'));
        }
        return help(
          '${tr('{name} ({relation}) can be called on {phone}.', {'name': who.name, 'relation': trData(who.relation), 'phone': who.phone})}\n\n'
          '${tr('Tap the button below to call. In an emergency, call 112 first.')}',
          'callFamily',
          tr('Call {name}', {'name': who.name.split(' ').first}),
          suggestions: const ['Where is the SOS button?', 'I feel unwell'],
        );
      case 'medicalId':
        return help(
          _steps(tr('Your Medical ID shows your blood group, allergies, medicines and emergency contacts to anyone helping you.'), [tapMe, tr('Under Emergency, tap Medical ID.')],
              tr('Your blood group: {bg}.', {'bg': store.profile.bloodGroup})),
          'medicalId',
          tr('Open Medical ID'),
        );
      case 'sos':
        return help(
          _steps(tr('The red SOS button is on the Today screen. You can also find it in Me → Emergency SOS.'),
              [tr('Tap SOS.'), tr('Press and hold the big button for 3 seconds.'), tr('It calls 112 and alerts {names}.', {'names': _contactNames()})]),
          'sos',
          tr('Open SOS'),
          urgent: true,
        );
      case 'unwell':
        final vitals = _goodReading ? '\n\n${tr('Your band right now:')}\n• ${_vitalLine('hr')}\n• ${_vitalLine('spo2')}\n• ${_vitalLine('temp')}' : '';
        return help(
          '${tr('I\'m sorry you\'re not feeling well.')}\n\n'
          '• ${tr('If you have chest pain, trouble breathing, or feel faint, call 112 or press SOS now.')}\n'
          '• ${tr('Otherwise, sit down, rest, and drink some water.')}\n'
          '• ${tr('You can talk to a doctor by video.')}$vitals',
          'findDoctor',
          tr('Talk to a doctor'),
          suggestions: const ['I have chest pain', 'Call my family', 'How am I doing today?'],
        );
      case 'held':
        return help(
          _steps(tr('Alerts that AdaptAlert held back (it didn\'t buzz you) are kept in Alerts → Held back.'), [tr('Tap Alerts at the bottom of the screen.'), tr('Tap Held back at the top.')],
              tr('Safety limits always alert, even for patterns that are usually held back.')),
          'alerts',
          tr('Open alerts'),
        );
      case 'appointment':
        return help(
          _steps(tr('Appointments are in the Care tab.'), [
            tr('Tap Care at the bottom of the screen.'),
            tr('To book: tap the search bar, pick a doctor, then pick a time.'),
            tr('To change one: find your appointment, then tap Reschedule or Cancel.'),
          ]),
          'book',
          tr('Open Care'),
        );
      case 'findDoctor':
        return help(
          _steps(tr('You can find a doctor in the Care tab.'), [
            tr('Tap Care at the bottom of the screen.'),
            tr('Tap the search bar, or a speciality like Heart.'),
            tr('Tap a doctor to see fees and times, then tap Book appointment.'),
          ]),
          'findDoctor',
          tr('Find a doctor'),
        );
      case 'talkDoctor':
        return help(
          _steps(tr('To talk to a doctor, book a video visit.'), [
            tr('Tap the button below to find a doctor.'),
            tr('Pick a doctor who offers Video, then pick a time.'),
            tr('At the time of the visit, open Care and tap Join call.'),
          ], tr('If it is urgent, call 112 or press SOS.')),
          'findDoctor',
          tr('Find a doctor'),
        );
      case 'alerts':
        return help(
          _steps(tr('Your alerts are in the Alerts tab.'), [
            tr('Tap Alerts at the bottom of the screen.'),
            tr('Alerts waiting for you are under Needs reply. Tap how you feel. Your answer helps AdaptAlert learn.'),
            tr('To see why an alert was sent, tap See how AdaptAlert decided.'),
          ]),
          'alerts',
          tr('Open alerts'),
        );
      case 'research':
        return help(
          _steps(tr('The Research Lab runs a 30-day study on simulated patients and compares AdaptAlert with other alarm systems.'),
              [tr('Tap Insights at the bottom of the screen.'), tr('Scroll down and tap Open the Research Lab.')]),
          'research',
          tr('Open the Research Lab'),
        );
      case 'howItWorks':
        return help(
          '${tr('AdaptAlert learns your own normal heart rate, oxygen and temperature. It alerts when something is unusual for you, not just for everyone.')}\n\n'
          '${tr('When you or your doctor answer an alert, it learns which patterns are harmless, so you get fewer false alarms. Safety limits always alert.')}',
          'howItWorks',
          tr('See how AdaptAlert works'),
        );
      case 'trends':
        return help(
          _steps(tr('Your charts and trends are in the Insights tab.'), [tr('Tap Insights at the bottom of the screen.'), tr('Choose Heart rate, Oxygen or Temperature at the top.')]),
          'insights',
          tr('Open Insights'),
        );
      case 'language':
        return help(
          _steps(tr('You can switch between English and Hindi at any time.'), [tapMe, tr('Under Preferences, find Language and choose English or हिन्दी.')],
              tr('Or tap the button below to switch now.')),
          'language',
          hindi ? tr('Switch to English') : tr('Switch to हिन्दी'),
        );
      case 'appearance':
        return help(
          _steps(tr('You can choose a light or dark screen.'), [tapMe, tr('Under Preferences, find Appearance.'), tr('Choose Light, Dark, or Auto (follows your phone).')]),
          'me',
          tr('Open Me'),
        );
      case 'notifications':
        return help(
          _steps(tr('You can turn alert notifications on or off.'), [tapMe, tr('Under Alerts, turn Notifications on or off.')]),
          'me',
          tr('Open Me'),
        );
      case 'accessibility':
        return help(
          _steps(tr('You can make the text bigger, use an easier home screen, and have alerts read aloud.'),
              [tr('Tap the button below, or open Me → Accessibility.'), tr('Choose a text size and turn on the options you like.')],
              tr('In this chat, tap the speaker at the top to hear answers read aloud.')),
          'accessibility',
          tr('Open text size & easy mode'),
        );
      case 'simulator':
        return help(
          _steps(tr('The simulator plays a pretend situation on the band, like a fast heart rate or low oxygen, so you can see how alerts work. It is for demos only.'),
              [tr('Tap the button below (or Me → Band simulator).'), tr('Pick a scenario and watch the Today screen.')]),
          'simulator',
          tr('Simulate a scenario'),
        );
      case 'signOut':
        return help(
          _steps(tr('To sign out:'), [tapMe, tr('Scroll to the bottom and tap Sign out (or Leave Demo Mode).')], tr('Your data stays on this device for next time.')),
          'me',
          tr('Open Me'),
        );
      case 'levels':
        return help(
          '${tr('Alerts have 4 levels:')}\n'
          '• ${tr('Check-in (teal): something small changed. Answer when you can.')}\n'
          '• ${tr('Warning (orange): keep an eye on it and rest. Your caregiver is told.')}\n'
          '• ${tr('Urgent (red): needs attention soon. Your doctor is told.')}\n'
          '• ${tr('Critical (red): a safety limit was reached. Get help now. Your emergency contacts are alerted.')}\n\n'
          '${tr('Green on the Today screen means everything is normal for you.')}',
          'alerts',
          tr('Open alerts'),
        );
      case 'spo2':
        return help(
          '${tr('SpO₂ means how much oxygen your blood is carrying. It is shown as a percentage.')}\n\n'
          '${tr('Healthy is 95% to 100%. If it stays at or below 91% for 2 minutes, AdaptAlert always alerts.')}'
          '${_goodReading ? '\n\n${tr('Yours right now: {spo2}%.', {'spo2': monitor.engine.last!.r.spo2})}' : ''}',
          'insights',
          tr('See trend'),
        );
      case 'ranges':
        final r = monitor.engine.last;
        return help(
          '${tr('Normal ranges for most adults at rest:')}\n'
          '• ${tr('Heart rate: 60 to 100 beats a minute.')}\n'
          '• ${tr('Oxygen (SpO₂): 95% to 100%. Below 92% needs a doctor.')}\n'
          '• ${tr('Temperature: 36.1 to 37.2 °C. 38 °C or more is a fever.')}\n\n'
          '${tr('AdaptAlert also learns your own normal, which may be a little different.')}'
          '${_goodReading ? '\n\n${tr('Right now: heart rate {hr} bpm, oxygen {spo2}%, temperature {temp} °C.', {'hr': r!.r.hr, 'spo2': r.r.spo2, 'temp': r.r.temp.toStringAsFixed(1)})}' : ''}',
          'insights',
          tr('See trend'),
        );
      case 'band':
        return help(
          _steps(tr('Your wrist band reads your heart rate, oxygen and temperature every minute and sends them to the app. If the readings look wrong:'), [
            tr('Wear the band snug, one finger above the wrist bone.'),
            tr('Keep your hand still for a minute.'),
            tr('Wipe the sensor on the back with a dry cloth.'),
          ], _goodReading ? tr('Right now your band is reading well.') : tr('Right now the band signal is weak, so readings are being ignored.')),
          'insights',
          tr('See trend'),
        );
      default:
        return _fallback(menu: true);
    }
  }

  /// When the question isn't understood: offer things to tap instead.
  AssistantReply _fallback({bool menu = false}) => AssistantReply(
        '${menu ? '' : '${tr('Sorry, I didn\'t understand that.')}\n\n'}'
        '${tr('I can tell you where things are in the app, explain your health readings and alerts, and help in an emergency.')}\n\n'
        '${tr('Tap a question below, or ask in your own words, like "Where are my reports?"')}',
        topic: menu ? 'menu' : 'unknown',
        suggestions: helpSuggestions,
      );
}
