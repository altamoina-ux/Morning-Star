import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qiminghat_tablet/core/api.dart';
import 'package:qiminghat_tablet/core/speech.dart';

class TestAdapter implements HttpClientAdapter {
  TestAdapter(this.handler);
  final FutureOr<ResponseBody> Function(RequestOptions, List<int>) handler;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final body =
        await requestStream?.fold<List<int>>(
          [],
          (all, part) => all..addAll(part),
        ) ??
        [];
    return handler(options, body);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonBody(Object data, {int status = 200}) =>
    ResponseBody.fromString(
      jsonEncode(data),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

QimingApi mockApi(
  FutureOr<ResponseBody> Function(RequestOptions, List<int>) handler,
) {
  final dio = Dio()..httpClientAdapter = TestAdapter(handler);
  return QimingApi('http://192.168.1.10:8765', dio: dio)..token = 'test-token';
}

void mockTts() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('flutter_tts'),
        (call) async => call.method == 'isLanguageAvailable' ? true : 1,
      );
}

class RecordingSpeech extends SpeechOutput {
  final said = <String>[];
  int stopped = 0;
  @override
  Future<void> initialize(double rate) async {
    ready = true;
  }

  @override
  Future<void> speak(String text, {bool alert = false}) async {
    said.add(text);
  }

  @override
  Future<void> stop() async {
    stopped++;
  }
}

Map<String, dynamic> overviewFixture() => {
  'timezone': 'Asia/Shanghai',
  'generated_at': '2026-11-17T10:00:00Z',
  'mode': 'simulation',
  'devices': {'real_online': 0, 'simulation_online': 1},
  'today_alerts': {'real': 0, 'simulation': 12},
  'today_voices': {'real': 0, 'simulation': 0},
  'yolo': {'state': 'ready', 'label': '已加载'},
  'llm': {'state': 'available', 'label': '模型已安装', 'detail': 'qwen3-vl:4b'},
  'trend': List.generate(
    7,
    (i) => {'date': '2026-11-${11 + i}', 'real': 0, 'simulation': i * 2},
  ),
  'recent_alerts': [],
  'recent_voices': [],
};
