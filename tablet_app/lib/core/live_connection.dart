import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/io.dart';

import 'api.dart';

class LiveConnection extends ChangeNotifier {
  LiveConnection(this.api);
  final QimingApi api;
  final _events = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get events => _events.stream;
  IOWebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _retry;
  Timer? _heartbeat;
  bool _active = false;
  bool _disposed = false;
  int _attempt = 0;
  int _generation = 0;
  DateTime? _lastReceived;
  String status = '未连接';
  bool get connected => status == '已连接';

  void start() {
    if (_active || _disposed || api.token == null) return;
    _active = true;
    _connect();
  }

  Future<void> _connect() async {
    if (!_active || _disposed) return;
    final generation = ++_generation;
    status = _attempt == 0 ? '连接中' : '重连中（$_attempt）';
    notifyListeners();
    final channel = IOWebSocketChannel.connect(
      api.socketUri,
      headers: {'Authorization': 'Bearer ${api.token}'},
      connectTimeout: const Duration(seconds: 8),
    );
    _channel = channel;
    _subscription = channel.stream.listen(
      (data) {
        if (generation != _generation || !_active) return;
        _lastReceived = DateTime.now();
        try {
          final value = jsonDecode(data as String);
          if (value is Map && !_events.isClosed) {
            _events.add(Map<String, dynamic>.from(value));
          }
        } catch (_) {
          /* Ignore malformed events, keep the socket alive. */
        }
      },
      onError: (Object error) {
        _lost(generation);
      },
      onDone: () {
        if (generation != _generation) return;
        if (channel.closeCode == 4401) {
          stop();
          api.onUnauthorized?.call();
        } else {
          _lost(generation);
        }
      },
    );
    try {
      await channel.ready;
      if (!_active || generation != _generation) {
        channel.sink.close();
        return;
      }
      _attempt = 0;
      _lastReceived = DateTime.now();
      status = '已连接';
      notifyListeners();
      _heartbeat?.cancel();
      _heartbeat = Timer.periodic(const Duration(seconds: 20), (_) {
        if (DateTime.now().difference(_lastReceived!).inSeconds > 50) {
          _lost(generation);
        } else {
          channel.sink.add(jsonEncode({'type': 'ping'}));
        }
      });
    } catch (_) {
      _lost(generation);
    }
  }

  void _lost(int generation) {
    if (generation != _generation || !_active || _disposed) return;
    _generation++;
    _heartbeat?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    status = '连接中断，等待重试';
    notifyListeners();
    final delay = [1, 2, 4, 8, 16, 30][_attempt.clamp(0, 5)];
    _attempt++;
    _retry?.cancel();
    _retry = Timer(Duration(seconds: delay), _connect);
  }

  void stop() {
    _active = false;
    _generation++;
    _retry?.cancel();
    _heartbeat?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    status = '已暂停';
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    stop();
    _events.close();
    super.dispose();
  }
}
