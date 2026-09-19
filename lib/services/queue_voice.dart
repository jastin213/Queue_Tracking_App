import 'package:flutter_tts/flutter_tts.dart';

class QueueVoice {
  const QueueVoice._();

  static Future<void> configure(
    FlutterTts tts, {
    required bool filipino,
    double speechRate = 0.45,
  }) async {
    await tts.stop();

    if (!filipino) {
      await tts.setLanguage('en-US');
      await tts.setSpeechRate(speechRate);
      await tts.setPitch(1.0);
      return;
    }

    final selectedVoice = await _bestFilipinoVoice(tts);
    final locale = selectedVoice?['locale'] ?? 'fil-PH';
    await tts.setLanguage(locale);
    if (selectedVoice != null) {
      await tts.setVoice(selectedVoice);
    }

    // A slightly slower rate and lower pitch makes Filipino prompts clearer
    // on the common Android and browser speech engines.
    await tts.setSpeechRate((speechRate * 0.92).clamp(0.30, 0.55));
    await tts.setPitch(0.96);
  }

  static Future<Map<String, String>?> _bestFilipinoVoice(FlutterTts tts) async {
    try {
      final dynamic rawVoices = await tts.getVoices;
      if (rawVoices is! List) return null;

      final voices = rawVoices
          .whereType<Map>()
          .map(
            (voice) => {
              'name': voice['name']?.toString() ?? '',
              'locale': voice['locale']?.toString() ?? '',
            },
          )
          .where(
            (voice) => voice['name']!.isNotEmpty && voice['locale']!.isNotEmpty,
          )
          .toList();

      int score(Map<String, String> voice) {
        final locale = voice['locale']!.toLowerCase().replaceAll('_', '-');
        final name = voice['name']!.toLowerCase();
        var value = 0;
        if (locale == 'fil-ph') value += 100;
        if (locale == 'tl-ph') value += 95;
        if (locale.startsWith('fil')) value += 85;
        if (locale.startsWith('tl')) value += 80;
        if (locale == 'en-ph') value += 60;
        if (name.contains('neural') || name.contains('natural')) value += 12;
        if (name.contains('google') || name.contains('microsoft')) value += 5;
        return value;
      }

      voices.sort((a, b) => score(b).compareTo(score(a)));
      if (voices.isEmpty || score(voices.first) < 60) return null;
      return voices.first;
    } catch (_) {
      return null;
    }
  }

  static String filipinoQueueCode(String queue) {
    const digits = {
      '0': 'sero',
      '1': 'isa',
      '2': 'dalawa',
      '3': 'tatlo',
      '4': 'apat',
      '5': 'lima',
      '6': 'anim',
      '7': 'pito',
      '8': 'walo',
      '9': 'siyam',
    };
    final normalized = queue.trim().toUpperCase();
    if (normalized.isEmpty) return queue;
    final first = normalized[0] == 'G'
        ? 'dyi'
        : normalized[0] == 'D'
        ? 'di'
        : normalized[0];
    final remainder = normalized
        .substring(1)
        .split('')
        .map((character) => digits[character] ?? character)
        .join(', ');
    return remainder.isEmpty ? first : '$first, $remainder';
  }

  static String nowServingMessage(String queue, {required bool filipino}) {
    if (filipino) {
      return 'Tinatawag na po ang numerong ${filipinoQueueCode(queue)}. '
          'Maaari na po kayong pumunta sa testing area.';
    }
    return 'Now serving $queue. Please proceed to the testing area.';
  }

  static String nearTurnMessage({required bool filipino}) => filipino
      ? 'Maghanda na po. Malapit na po kayong tawagin.'
      : 'Please prepare. Your turn is near.';

  static String proceedMessage({required bool filipino}) => filipino
      ? 'Oras na po ng inyong pagsusuri. Maaari na po kayong pumunta sa testing area.'
      : 'Please proceed to the testing area.';
}
