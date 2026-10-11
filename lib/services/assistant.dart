import 'package:intl/intl.dart';

import '../engine/adapt_alert.dart';
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

  AssistantReply reply(String raw) {
    final q = raw.toLowerCase();
    final e = monitor.engine;
    final r = e.last;

    if (_has(q, ['chest pain', 'can\'t breathe', 'cannot breathe', 'breathless', 'faint', 'unconscious', 'stroke', 'severe pain', 'emergency', 'bleeding'])) {
      return AssistantReply(
        'This could be an emergency. Please don\'t wait for an alert.\n\n'
        '• Call 112 now, or press SOS to call and alert ${store.emergencyContacts.map((m) => m.name.split(' ').first).join(' and ')}.\n'
        '• Sit upright and rest. Don\'t drive yourself.\n'
        '• If a doctor has told you to take a medicine for chest pain, follow that plan.\n\n'
        'Your band will keep sending your vitals to Dr. Rao.',
        action: 'sos',
        actionLabel: 'Open SOS',
        urgent: true,
      );
    }

    if (_has(q, ['why', 'last alert', 'alert'])) {
      if (e.alerts.isEmpty) return AssistantReply('You have had no alerts today. AdaptAlert is watching your heart rate, oxygen and temperature against your own normal ranges.');
      final a = e.alerts.first;
      final status = a.doctor == DoctorLabel.confirmed
          ? 'Dr. Rao confirmed it was real.'
          : a.doctor == DoctorLabel.rejected
              ? 'Dr. Rao marked it as a false alarm, so similar patterns will be held back for you.'
              : 'Dr. Rao hasn\'t reviewed it yet.';
      return AssistantReply(
        'Your last alert was "${a.title}" at ${hhmm(a.t)} (${a.levelLabel}).\n\n'
        'Why it was sent:\n${a.reasons.map((x) => '• $x').join('\n')}\n\n'
        'The AI rated it ${pct(a.p)} likely to be real. It sends alerts when it is at least ${pct(a.tau)} sure${a.safety ? ', but this one hit a safety limit, so it was sent regardless' : ''}. $status',
        action: 'alerts',
        actionLabel: 'See alert',
      );
    }

    if (_has(q, ['learn', 'learned', 'sensitivity', 'false alarm', 'held'])) {
      final ks = e.buckets.keys.toList();
      if (ks.isEmpty) return AssistantReply('Nothing yet. When you answer an alert, or Dr. Rao reviews one, AdaptAlert learns which patterns are harmless for you.');
      final lines = ks.map((k) {
        final p = e.bucketP(k);
        return '• ${bucketLabel(k)}: now ${pct(p)} likely real, so it ${p >= e.tau ? 'still alerts' : 'is held back'}.';
      }).join('\n');
      return AssistantReply(
        'From ${e.labels} feedback answers, AdaptAlert has learned:\n$lines\n\n'
        'Your alert threshold is ${pct(e.tau)}. It can only move between 30% and 75%, at most 10 points a week. '
        '${e.held.isEmpty ? '' : 'It has held back ${e.held.length} alert${e.held.length == 1 ? '' : 's'} today. '}Safety limits like oxygen at or below 91% always alert.',
        action: 'insights',
        actionLabel: 'Open AI Engine',
      );
    }

    if (_has(q, ['appointment', 'doctor', 'book', 'consult', 'visit'])) {
      final up = store.upcoming;
      if (_has(q, ['book', 'new', 'schedule']) || up.isEmpty) {
        return AssistantReply(up.isEmpty ? 'You have no upcoming appointments. Want to book one?' : 'Sure. You can pick a doctor by speciality, language and fee.', action: 'book', actionLabel: 'Find a doctor');
      }
      final a = up.first;
      final d = doctorById(a.doctorId);
      return AssistantReply(
        'Your next appointment is with ${d.name} (${d.specialty}) on ${DateFormat('EEE d MMM, h:mm a').format(a.at)}, ${a.mode == ApptMode.video ? 'by video' : 'at ${d.hospital}'}, for ${store.memberName(a.forMember) == 'You' ? 'you' : store.memberName(a.forMember)}.\nReason: ${a.reason}.'
        '${up.length > 1 ? '\n\nYou have ${up.length - 1} more coming up.' : ''}',
        action: 'book',
        actionLabel: 'Manage appointments',
      );
    }

    if (_has(q, ['medicine', 'medication', 'tablet', 'pill', 'dose'])) {
      final m = store.profile.medications;
      if (m.isEmpty) return AssistantReply('You haven\'t added any medicines. Add them under Me > Health profile.');
      return AssistantReply(
        'Your medicines:\n${m.map((x) => '• ${x.name} ${x.dose}: ${x.schedule}').join('\n')}\n\n'
        'I can explain what\'s on your list, but please ask Dr. Rao before changing any dose.${store.profile.allergies.isEmpty ? '' : '\nAllergies on file: ${store.profile.allergies.join(', ')}.'}',
      );
    }

    if (_has(q, ['insurance', 'claim', 'policy', 'cover'])) {
      if (store.policies.isEmpty) return AssistantReply('No insurance policy is saved yet.', action: 'insurance', actionLabel: 'Add a policy');
      final p = store.policies.first;
      final used = store.usedOf(p);
      final cl = store.claims.where((c) => c.policyId == p.id).toList();
      final f = NumberFormat.decimalPattern('en_IN');
      return AssistantReply(
        '${p.insurer} ${p.plan}: ₹${f.format(p.sumInsured - used)} left of ₹${f.format(p.sumInsured)}, valid till ${DateFormat('d MMM y').format(p.validTill)}.\n\n'
        '${cl.isEmpty ? 'No claims yet.' : cl.map((c) => '• ${c.title}: ${claimStatusLabel[c.status]}${c.approved != null ? ' (₹${f.format(c.approved)} approved)' : ''}').join('\n')}',
        action: 'insurance',
        actionLabel: 'Open insurance',
      );
    }

    if (_has(q, ['record', 'report', 'lab', 'x-ray', 'xray', 'discharge'])) {
      final recs = store.records.where((x) => x.forMember == 'self').take(4);
      return AssistantReply('Your latest records:\n${recs.map((x) => '• ${x.title} (${x.category}, ${DateFormat('d MMM').format(x.date)})${x.notes.isEmpty ? '' : ': ${x.notes}'}').join('\n')}', action: 'records', actionLabel: 'Open records');
    }

    if (_has(q, ['family', 'daughter', 'wife', 'caregiver', 'contact'])) {
      final cg = store.caregiver;
      return AssistantReply(
        '${cg == null ? 'No caregiver is set.' : '${cg.name} (${cg.relation}) is your caregiver and gets an alert if you don\'t reply to one within 10 minutes.'}\n'
        'Emergency contacts: ${store.emergencyContacts.isEmpty ? 'none' : store.emergencyContacts.map((m) => m.name).join(', ')}.',
        action: 'family',
        actionLabel: 'Manage family',
      );
    }

    if (r == null || !r.good) {
      return AssistantReply('I can\'t read your band clearly right now. Please check that it\'s snug on your wrist. Readings that aren\'t reliable are ignored, so they can\'t cause false alarms.');
    }

    String vitalLine(String v) {
      final z = r.z[v]!;
      final word = z.abs() < 1.5 ? 'normal for you' : (z > 0 ? 'above your normal' : 'below your normal');
      return switch (v) {
        'hr' => 'Heart rate ${r.r.hr} bpm, $word (usual ${r.mu['hr']!.round()} when ${r.ctx == 'rest' ? 'resting' : 'active'}).',
        'spo2' => 'Oxygen ${r.r.spo2}%, $word (usual ${r.mu['spo2']!.round()}%).',
        _ => 'Temperature ${r.r.temp.toStringAsFixed(1)} °C, $word (usual ${r.mu['temp']!.toStringAsFixed(1)} °C).',
      };
    }

    if (_has(q, ['heart', 'pulse', 'bpm'])) return AssistantReply('${vitalLine('hr')}\nYou are ${r.act.toLowerCase()} right now.', action: 'insights', actionLabel: 'See trend');
    if (_has(q, ['oxygen', 'spo2', 'saturation', 'breath'])) return AssistantReply('${vitalLine('spo2')}\nAdaptAlert always alerts if oxygen stays at or below 91% for 2 minutes.', action: 'insights', actionLabel: 'See trend');
    if (_has(q, ['temperature', 'fever', 'temp'])) return AssistantReply(vitalLine('temp'), action: 'insights', actionLabel: 'See trend');

    final open = e.alerts.where((a) => a.patientFeedback == null).length;
    final summary = switch (e.status) {
      'alert' => 'An alert is active right now.',
      'watch' => 'Something is a little off, and AdaptAlert is watching it.',
      'held' => 'A pattern you marked harmless before is happening. No alert needed.',
      _ => 'Everything is inside your personal normal range.',
    };
    return AssistantReply(
      '$summary\n\n• ${vitalLine('hr')}\n• ${vitalLine('spo2')}\n• ${vitalLine('temp')}\n\n'
      'Today: ${e.sentCount} alert${e.sentCount == 1 ? '' : 's'} sent, ${e.held.length} held back. A fixed-threshold monitor would have alarmed ${e.fixedCount} times.'
      '${open > 0 ? '\n$open alert${open == 1 ? ' needs' : 's need'} your reply.' : ''}',
      action: open > 0 ? 'alerts' : null,
      actionLabel: open > 0 ? 'Reply to alerts' : null,
    );
  }
}
