import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'api.dart';
import 'speech.dart';

class TextReader extends ChangeNotifier {
  TextReader(this.api, this.speech, {required this.autoRead});
  final QimingApi api;
  final SpeechOutput speech;
  final bool Function() autoRead;
  bool busy = false;
  String text = '';
  String status = '对准文字后拍照，识别结果会显示在这里。';
  String? error;
  CancelToken? _cancel;
  int _generation = 0;
  bool _disposed = false;

  Future<void> recognize(Uint8List bytes) async {
    if (busy || _disposed) return;
    final generation = ++_generation;
    _cancel = CancelToken();
    busy = true;
    text = '';
    error = null;
    status = '正在识字，首次加载模型可能需要数分钟…';
    notifyListeners();
    try {
      await speech.stop();
      if (generation != _generation) return;
      if (bytes.length > 6 * 1024 * 1024) {
        throw const ApiFailure('照片超过 6 MB，请降低摄像头分辨率。');
      }
      final result = await api.map(
        '/api/ocr/read',
        method: 'POST',
        data: bytes,
        cancelToken: _cancel,
        timeout: const Duration(seconds: 310),
      );
      if (generation != _generation || _disposed) return;
      if (result['text'] is! String || result['has_text'] is! bool) {
        throw const ApiFailure('识字接口格式异常。');
      }
      text = result['has_text'] == true
          ? (result['text'] as String).trim()
          : '';
      status = text.isEmpty
          ? '未识别到文字，请对焦并改善光线后重试。'
          : result['truncated'] == true
          ? '识别完成，结果可能未完整。建议分区域拍照。'
          : '识别完成';
      if (text.isNotEmpty && autoRead()) unawaited(speech.speak(text));
    } on DioException catch (failure) {
      if (generation == _generation &&
          !_disposed &&
          !CancelToken.isCancel(failure)) {
        error = failure.message;
      }
    } catch (failure) {
      if (generation == _generation && !_disposed) {
        error = failure.toString();
        status = '识别未完成';
      }
    } finally {
      if (generation == _generation && !_disposed) {
        busy = false;
        notifyListeners();
      }
    }
  }

  void cancel() {
    _generation++;
    _cancel?.cancel('Cancelled by user');
    final wasBusy = busy;
    busy = false;
    if (wasBusy) status = '已取消本次结果接收；电脑端已开始的模型任务可能仍在结束中。';
    unawaited(speech.stop());
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    cancel();
    super.dispose();
  }
}
