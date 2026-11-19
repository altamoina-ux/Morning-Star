import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qiminghat_tablet/core/speech.dart';
import 'package:qiminghat_tablet/core/text_reader.dart';

import 'helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(mockTts);
  test('long Chinese text preserves content and surrogate pairs', () {
    final source = List.filled(80, '前方标牌写着欢迎光临。😀').join();
    final chunks = speechChunks(source);
    expect(chunks.join(), source);
    expect(chunks.every((c) => c.length <= 240), isTrue);
    for (final c in chunks) {
      expect(c.runes.contains(0xfffd), isFalse);
    }
  });
  test('OCR success reads text, no text does not trigger speech', () async {
    var hasText = true;
    final speech = RecordingSpeech();
    final api = mockApi(
      (_, _) => jsonBody({
        'text': hasText ? '你好，启明帽。' : '未发现文字',
        'has_text': hasText,
        'truncated': false,
      }),
    );
    final reader = TextReader(api, speech, autoRead: () => true);
    await reader.recognize(Uint8List.fromList([255, 216]));
    expect(reader.text, '你好，启明帽。');
    expect(speech.said, ['你好，启明帽。']);
    hasText = false;
    await reader.recognize(Uint8List.fromList([255, 216]));
    expect(reader.text, isEmpty);
    expect(speech.said.length, 1);
    reader.dispose();
    speech.dispose();
    api.dispose();
  });
  test('cancel ignores late OCR results and never restarts speech', () async {
    final pending = Completer<void>();
    final reached = Completer<void>();
    final speech = RecordingSpeech();
    final api = mockApi((_, _) async {
      reached.complete();
      await pending.future;
      return jsonBody({'text': '迟到的结果', 'has_text': true, 'truncated': false});
    });
    final reader = TextReader(api, speech, autoRead: () => true);
    final work = reader.recognize(Uint8List.fromList([255, 216]));
    await reached.future;
    reader.cancel();
    pending.complete();
    await work;
    expect(reader.busy, isFalse);
    expect(reader.text, isEmpty);
    expect(speech.said, isEmpty);
    reader.dispose();
    speech.dispose();
    api.dispose();
  });
  test('OCR failures end loading; manual reading mode retains text', () async {
    var fail = true;
    final speech = RecordingSpeech();
    final api = mockApi(
      (_, _) => fail
          ? jsonBody({'detail': '模型忙，请稍后重试'}, status: 429)
          : jsonBody({'text': '只显示文字', 'has_text': true, 'truncated': true}),
    );
    final reader = TextReader(api, speech, autoRead: () => false);
    await reader.recognize(Uint8List(2));
    expect(reader.busy, isFalse);
    expect(reader.error, contains('模型忙'));
    fail = false;
    await reader.recognize(Uint8List(2));
    expect(reader.text, '只显示文字');
    expect(reader.status, contains('未完整'));
    expect(speech.said, isEmpty);
    reader.dispose();
    speech.dispose();
    api.dispose();
  });
  test('stop while engine preparation is pending prevents speech', () async {
    final started = Completer<void>();
    final release = Completer<void>();
    var said = 0;
    var block = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_tts'), (
          call,
        ) async {
          if (call.method == 'isLanguageAvailable') return true;
          if (call.method == 'stop' && block) {
            started.complete();
            await release.future;
          }
          if (call.method == 'speak') said++;
          return 1;
        });
    final speech = SpeechOutput();
    await speech.initialize(.45);
    block = true;
    final work = speech.speak('不应该播出');
    await started.future;
    block = false;
    await speech.stop();
    release.complete();
    await work;
    expect(said, 0);
    expect(speech.speaking, isFalse);
    speech.dispose();
  });
}
