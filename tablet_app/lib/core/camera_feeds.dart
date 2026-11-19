import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'api.dart';

class CameraSource {
  const CameraSource(this.id, this.label, this.online);
  final String id;
  final String label;
  final bool online;
}

/// Only fetches the selected preview, with one request at a time.
class CameraFeeds extends ChangeNotifier {
  CameraFeeds(
    this.api,
    this.localSource, {
    this.pollInterval = const Duration(milliseconds: 500),
    this.freshnessLimit = const Duration(seconds: 3),
  }) : source = localSource;

  final QimingApi api;
  final String localSource;
  final Duration pollInterval;
  final Duration freshnessLimit;
  final sources = <String, CameraSource>{};
  String source;
  Uint8List? image;
  String status = '';
  String? sourcesError;
  bool _active = true;
  bool _enabled = false;
  bool _disposed = false;
  bool _refreshing = false;
  int _generation = 0;
  Timer? _pollTimer;
  Timer? _sourcesTimer;
  Timer? _staleTimer;
  CancelToken? _cancel;
  CancelToken? _sourcesCancel;

  bool get isLocal => source == localSource;
  bool get watching => !isLocal && _enabled && _active;

  void start() {
    if (_disposed || !_active || _sourcesTimer != null) return;
    unawaited(refreshSources());
    _sourcesTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      unawaited(refreshSources());
    });
  }

  Future<void> refreshSources() async {
    if (_disposed || !_active || _refreshing) return;
    _refreshing = true;
    final cancel = _sourcesCancel = CancelToken();
    try {
      final data = await api.request(
        '/api/tablet/cameras',
        cancelToken: cancel,
      );
      if (_disposed || !_active || cancel.isCancelled) return;
      if (data is! List) throw const ApiFailure('摄像头来源接口格式不正确。');
      final updated = <String, CameraSource>{};
      for (final item in data) {
        if (item is Map && item['source_id'] is String) {
          final id = item['source_id'] as String;
          if (id != localSource) {
            updated[id] = CameraSource(
              id,
              item['label'] is String ? item['label'] as String : id,
              item['online'] == true,
            );
          }
        }
      }
      sources
        ..clear()
        ..addAll(updated);
      sourcesError = null;
    } catch (error) {
      if (!_disposed && _active && !cancel.isCancelled) {
        sourcesError = error.toString();
      }
    } finally {
      if (identical(_sourcesCancel, cancel)) _refreshing = false;
      _notify();
    }
  }

  void select(String id) {
    if (_disposed || id == source) return;
    source = id;
    _enabled = !isLocal;
    _restart();
  }

  void pause() {
    _enabled = false;
    _restart();
  }

  void resume() {
    if (_disposed || isLocal) return;
    _enabled = true;
    _restart();
  }

  void setActive(bool active) {
    if (_disposed || active == _active) return;
    _active = active;
    if (active) {
      start();
    } else {
      _sourcesTimer?.cancel();
      _sourcesTimer = null;
      _sourcesCancel?.cancel();
      _sourcesCancel = null;
      _refreshing = false;
    }
    _restart();
  }

  void _restart() {
    _generation++;
    _pollTimer?.cancel();
    _staleTimer?.cancel();
    _cancel?.cancel();
    image = null;
    status = isLocal
        ? ''
        : watching
        ? '正在连接选中的摄像头…'
        : '远端画面已暂停';
    _notify();
    if (watching) unawaited(_poll(_generation));
  }

  Future<void> _poll(int generation) async {
    if (_disposed || !watching || generation != _generation) return;
    final cancel = _cancel = CancelToken();
    try {
      final data = await api.request(
        '/api/tablet/cameras/${Uri.encodeComponent(source)}/frame',
        responseType: ResponseType.bytes,
        cancelToken: cancel,
        timeout: const Duration(seconds: 3),
      );
      if (_disposed || generation != _generation || !watching) return;
      if (data is! List<int> || data.isEmpty || data.length >= 2_000_000) {
        throw const ApiFailure('摄像头没有返回有效画面。');
      }
      image = Uint8List.fromList(data);
      status = '正在观看实时画面';
      _staleTimer?.cancel();
      _staleTimer = Timer(freshnessLimit, () {
        if (!_disposed && generation == _generation && watching) {
          image = null;
          status = '画面已中断，正在重新连接…';
          _notify();
        }
      });
    } catch (error) {
      if (_disposed || generation != _generation || cancel.isCancelled) return;
      image = null;
      _staleTimer?.cancel();
      status = error is ApiFailure && error.status == 410
          ? source == 'local_camera'
                ? '等待电脑网页摄像头画面，请先在电脑网页端启动摄像头。'
                : '该摄像头未开启或已停止上传，正在等待新画面。'
          : '画面连接失败：$error';
    } finally {
      if (!_disposed && generation == _generation && watching) {
        _notify();
        _pollTimer = Timer(pollInterval, () => unawaited(_poll(generation)));
      }
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _pollTimer?.cancel();
    _sourcesTimer?.cancel();
    _staleTimer?.cancel();
    _cancel?.cancel();
    _sourcesCancel?.cancel();
    image = null;
    super.dispose();
  }
}
