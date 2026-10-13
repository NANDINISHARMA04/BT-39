import '../l10n/msg.dart';
import 'pulse_api.dart';

class AssistantReply {
  AssistantReply(this.text, {this.action, this.actionLabel, this.urgent = false, this.topic, this.suggestions = const []});
  final String text;

  /// A place the reply offers to open. See [HealthAssistant.actions].
  final String? action;
  final String? actionLabel;
  final bool urgent;

  /// Which help topic answered, e.g. 'records' or 'language'. Null for
  /// answers from the person's health data, and 'error' when the service
  /// could not be asked.
  final String? topic;

  /// Follow-up questions to offer as buttons (English keys; show and send
  /// them with tr()).
  final List<String> suggestions;
}

/// The AI Health Assistant. The service answers from the person's own data:
/// live vitals, AdaptAlert alerts and what the engine learned, medicines,
/// appointments, records and insurance. It also tells people where things are
/// in the app, in short steps, with a button that goes straight there. It
/// explains; it never diagnoses or changes a dose.
///
/// The app sends the question to `POST /assistant` and shows the answer. The
/// answer comes as messages, so it follows the app's language.
class HealthAssistant {
  HealthAssistant(this.api);
  final PulseApi api;

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

  /// Asks the service. When it cannot answer, the reply holds the reason and
  /// has the topic 'error'.
  Future<AssistantReply> reply(String raw) async {
    final r = await api.post('/assistant', {'q': raw});
    if (!r.ok) return AssistantReply(r.message ?? '', topic: 'error');
    final j = r.map;
    final label = j['action_label'];
    return AssistantReply(
      msg(j['text']),
      action: j['action'] as String?,
      actionLabel: label == null ? null : msg(label),
      urgent: j['urgent'] == true,
      topic: j['topic'] as String?,
      suggestions: [for (final s in (j['suggestions'] as List? ?? const [])) '$s'],
    );
  }
}
