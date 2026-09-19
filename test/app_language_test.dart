import 'package:flutter_test/flutter_test.dart';
import 'package:queue_tracking_app/services/app_language.dart';
import 'package:queue_tracking_app/services/queue_voice.dart';

void main() {
  tearDown(() {
    appLanguageNotifier.value = englishLanguage;
  });

  test('English keeps the original interface text', () {
    appLanguageNotifier.value = englishLanguage;

    expect(appText('Queue Status'), 'Queue Status');
    expect(appText('Now Serving: G001'), 'Now Serving: G001');
  });

  test('Filipino translates shared and dynamic interface text', () {
    appLanguageNotifier.value = filipinoLanguage;

    expect(appText('Queue Status'), 'Status ng Pila');
    expect(appText('Voice Settings'), 'Mga Setting ng Boses');
    expect(appText('Welcome, Jastin'), 'Maligayang pagdating, Jastin');
    expect(appText('Position 3 in line'), 'Pang-3 sa pila');
    expect(appText('Now Serving: G001'), 'Kasalukuyang tinatawag: G001');
    expect(appText('5 mins'), '5 minuto');
  });

  test('Filipino queue voice spells codes naturally', () {
    expect(
      QueueVoice.filipinoQueueCode('G010'),
      'dyi, sero, isa, sero',
    );
    expect(
      QueueVoice.nowServingMessage('D002', filipino: true),
      'Tinatawag na po ang numerong di, sero, sero, dalawa. '
      'Maaari na po kayong pumunta sa testing area.',
    );
    expect(
      QueueVoice.nearTurnMessage(filipino: true),
      'Maghanda na po. Malapit na po kayong tawagin.',
    );
  });
}
