import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

List<String> speechChunks(String text, {int maxLength = 240}) {
  final result = <String>[];
  var rest = text.trim();
  while (rest.isNotEmpty) {
    var end = rest.length < maxLength ? rest.length : maxLength;
    if (end < rest.length) {
      final prefix = rest.substring(0, end);
      final stop = prefix.lastIndexOf(RegExp(r'[。！？；\n.!?]'));
      if (stop >= end ~/ 3) end = stop + 1;
      // Do not split a UTF-16 surrogate pair.
      if (rest.codeUnitAt(end - 1) >= 0xD800 &&
          rest.codeUnitAt(end - 1) <= 0xDBFF) {
        end--;
      }
    }
    final chunk = rest.substring(0, end).trim();
    if (chunk.isNotEmpty) result.add(chunk);
    rest = rest.substring(end).trimLeft();
  }
  return result;
}

class SpeechOutput extends ChangeNotifier {
  SpeechOutput({FlutterTts? engine}) : engine = engine ?? FlutterTts();
  final FlutterTts engine;
  bool ready = false;
  bool speaking = false;
  String? error;
  int _generation = 0;
  bool _disposed = false;
  DateTime _lastAlert = DateTime.fromMillisecondsSinceEpoch(0);
  Future<void>? _initializing;

  Future<void> initialize(double rate) => _initializing ??= _initialize(rate);
  Future<void> _initialize(double rate) async {
    try {
      await engine.awaitSpeakCompletion(true);
      final available = await engine.isLanguageAvailable('zh-CN');
      if (available != true && available != 1) {
        throw StateError('未找到中文语音，请在 Android 文字转语音设置中安装中文语音包。');
      }
      await engine.setLanguage('zh-CN');
      await engine.setSpeechRate(rate);
      await engine.setVolume(1);
      await engine.setPitch(1);
      ready = true;
      error = null;
    } catch (_) {
      error = '中文播报未就绪，请在平板的「文字转语音」设置中安装或启用中文语音引擎。';
      _initializing = null;
    }
    _notify();
  }

  Future<void> setRate(double rate) => engine.setSpeechRate(rate);

  Future<void> speak(String text, {bool alert = false}) async {
    if (text.trim().isEmpty || _disposed) return;
    if (!ready) {
      error ??= '中文播报未就绪，请先在设置中测试语音。';
      _notify();
      return;
    }
    if (alert &&
        (speaking || DateTime.now().difference(_lastAlert).inSeconds < 4)) {
      return;
    }
    // Reserve the generation before awaiting the engine so rapid taps cannot
    // start two utterance loops or revive speech after the Stop button.
    final current = ++_generation;
    speaking = true;
    error = null;
    if (alert) _lastAlert = DateTime.now();
    _notify();
    try {
      await engine.stop();
      if (current != _generation || _disposed) return;
      for (final chunk in speechChunks(text)) {
        if (current != _generation || _disposed) break;
        final result = await engine.speak(chunk);
        if (result == 0) throw StateError('TTS rejected speech');
      }
    } catch (_) {
      if (current == _generation) error = '播报失败，请检查中文语音包、媒体音量和音频输出。';
    } finally {
      if (current == _generation) {
        speaking = false;
        _notify();
      }
    }
  }

  Future<void> stop() async {
    _generation++;
    speaking = false;
    try {
      await engine.stop();
    } catch (_) {
      /* Engine can be unavailable. */
    }
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    engine.stop();
    super.dispose();
  }
}
