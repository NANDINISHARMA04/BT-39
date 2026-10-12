import 'package:intl/intl.dart';

import '../engine/adapt_alert.dart';
import '../l10n/l10n.dart';
import '../models/patient_models.dart';
import 'monitor.dart';
import 'patient_store.dart';

class AssistantReply {
  AssistantReply(this.text, {this.action, this.actionLabel, this.urgent = false});
  final String text;

  /// A screen the reply suggests opening: book | sos | records | insurance | alerts | insights | family.
  final String? action;
  final String? actionLabel;
  final bool urgent;
}

/// The AI Health Assistant. It answers from the user's own data: live vitals,
/// AdaptAlert alerts and what the engine learned, medicines, appointments,
/// records and insurance. It explains; it never diagnoses or changes a dose.
///
/// This version runs on the device so the demo works offline. The README shows
/// how to route the same context to a hosted language model through a backend.
class HealthAssistant {
  HealthAssistant(this.monitor, this.store);
  final MonitorController monitor;
  final PatientStore store;

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
    'बेहोश', 'लकवा', 'स्ट्रोक', 'तेज दर्द', 'बहुत दर्द', 'खून बह', 'इमरजेंसी', 'एमरजेंसी', 'आपातकाल', 'एसओएस',
    'seene mein dard', 'seene me dard', 'sine mein dard', 'sine me dard', 'chhati mein dard', 'chhati me dard', 'chati me dard',
    'chest mein dard', 'chest me dard', 'saans nahi', 'sans nahi', 'saans nahin', 'behosh',
  ];
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

  AssistantReply reply(String raw) {
    final q = raw.toLowerCase();
    final h = _norm(raw);
    final e = monitor.engine;
    final r = e.last;

    if (_has(q, ['chest pain', 'can\'t breathe', 'cannot breathe', 'breathless', 'faint', 'unconscious', 'stroke', 'severe pain', 'emergency', 'bleeding']) || _hasHi(h, _hiEmergency) || RegExp(r'\bsos\b').hasMatch(q)) {
      return AssistantReply(
        '${tr('This could be an emergency. Please don\'t wait for an alert.')}\n\n'
        '• ${tr('Call 112 now, or press SOS to call and alert {names}.', {'names': store.emergencyContacts.map((m) => m.name.split(' ').first).join(tr(' and '))})}\n'
        '• ${tr('Sit upright and rest. Don\'t drive yourself.')}\n'
        '• ${tr('If a doctor has told you to take a medicine for chest pain, follow that plan.')}\n\n'
        '${tr('Your band will keep sending your vitals to Dr. Rao.')}',
        action: 'sos',
        actionLabel: tr('Open SOS'),
        urgent: true,
      );
    }

    final hiLearn = _hasHi(h, _hiLearn);
    if (!hiLearn && (_has(q, ['why', 'last alert', 'alert']) || _hasHi(h, _hiAlert))) {
      if (e.alerts.isEmpty) return AssistantReply(tr('You have had no alerts today. AdaptAlert is watching your heart rate, oxygen and temperature against your own normal ranges.'));
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
        '${a.safety ? tr('The AI rated it {p} likely to be real. It sends alerts when it is at least {tau} sure, but this one hit a safety limit, so it was sent regardless.', args) : tr('The AI rated it {p} likely to be real. It sends alerts when it is at least {tau} sure.', args)} $status',
        action: 'alerts',
        actionLabel: tr('See alert'),
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
      if (m.isEmpty) return AssistantReply(tr('You haven\'t added any medicines. Add them under Me > Health profile.'));
      return AssistantReply(
        '${tr('Your medicines:')}\n${m.map((x) => '• ${x.name} ${x.dose}: ${trData(x.schedule)}').join('\n')}\n\n'
        '${tr('I can explain what\'s on your list, but please ask Dr. Rao before changing any dose.')}${store.profile.allergies.isEmpty ? '' : '\n${tr('Allergies on file: {list}.', {'list': store.profile.allergies.map(trData).join(', ')})}'}',
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
      final cg = store.caregiver;
      return AssistantReply(
        '${cg == null ? tr('No caregiver is set.') : tr('{name} ({relation}) is your caregiver and gets an alert if you don\'t reply to one within 10 minutes.', {'name': cg.name, 'relation': trData(cg.relation)})}\n'
        '${store.emergencyContacts.isEmpty ? tr('Emergency contacts: none.') : tr('Emergency contacts: {names}.', {'names': store.emergencyContacts.map((m) => m.name).join(', ')})}',
        action: 'family',
        actionLabel: tr('Manage family'),
      );
    }

    if (r == null || !r.good) {
      return AssistantReply(tr('I can\'t read your band clearly right now. Please check that it\'s snug on your wrist. Readings that aren\'t reliable are ignored, so they can\'t cause false alarms.'));
    }

    String vitalLine(String v) {
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

    String nowLine() => switch (r.act) {
          'Resting' => tr('You are resting right now.'),
          'Active' => tr('You are active right now.'),
          'Light activity' => tr('You are light activity right now.'),
          'Cooling down' => tr('You are cooling down right now.'),
          _ => tr('You are {act} right now.', {'act': r.act.toLowerCase()}),
        };

    if (_has(q, ['heart', 'pulse', 'bpm']) || _hasHi(h, _hiHeart)) return AssistantReply('${vitalLine('hr')}\n${nowLine()}', action: 'insights', actionLabel: tr('See trend'));
    if (_has(q, ['oxygen', 'spo2', 'saturation', 'breath']) || _hasHi(h, _hiOxygen)) return AssistantReply('${vitalLine('spo2')}\n${tr('AdaptAlert always alerts if oxygen stays at or below 91% for 2 minutes.')}', action: 'insights', actionLabel: tr('See trend'));
    if (_has(q, ['temperature', 'fever', 'temp']) || _hasHi(h, _hiTemp)) return AssistantReply(vitalLine('temp'), action: 'insights', actionLabel: tr('See trend'));

    final open = e.alerts.where((a) => a.patientFeedback == null).length;
    final summary = switch (e.status) {
      'alert' => tr('An alert is active right now.'),
      'watch' => tr('Something is a little off, and AdaptAlert is watching it.'),
      'held' => tr('A pattern you marked harmless before is happening. No alert needed.'),
      _ => tr('Everything is inside your personal normal range.'),
    };
    final today = {'sent': e.sentCount, 'held': e.held.length, 'fixed': e.fixedCount};
    return AssistantReply(
      '$summary\n\n• ${vitalLine('hr')}\n• ${vitalLine('spo2')}\n• ${vitalLine('temp')}\n\n'
      '${e.sentCount == 1 ? tr('Today: {sent} alert sent, {held} held back. A fixed-threshold monitor would have alarmed {fixed} times.', today) : tr('Today: {sent} alerts sent, {held} held back. A fixed-threshold monitor would have alarmed {fixed} times.', today)}'
      '${open > 0 ? '\n${open == 1 ? tr('{n} alert needs your reply.', {'n': open}) : tr('{n} alerts need your reply.', {'n': open})}' : ''}',
      action: open > 0 ? 'alerts' : null,
      actionLabel: open > 0 ? tr('Reply to alerts') : null,
    );
  }
}
