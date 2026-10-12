bool canSpeak() => false;
bool canListen() => false;
void speak(String text, String lang) {}
void stopSpeaking() {}
void listen(String lang, void Function(String text, bool done) onText, void Function() onEnd) => onEnd();
void stopListening() {}
