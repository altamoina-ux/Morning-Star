import 'dart:async';

import 'package:flutter/foundation.dart';

import 'api.dart';
import 'live_connection.dart';
import 'preferences.dart';
import 'speech.dart';

class AppController extends ChangeNotifier {
  AppController(this.preferences, this.speech);
  final AppPreferences preferences;
  final SpeechOutput speech;
  QimingApi? api;
  LiveConnection? live;
  bool loading = true;
  bool loggedIn = false;
  String username = '';
  String? notice;
  bool _expiring = false;
  bool _disposed = false;
  late final String sourceId = preferences.sourceId;

  Future<void> initialize() async {
    try {
      final server = preferences.server;
      if (server.isNotEmpty) {
        _useServer(server);
        api!.token = await preferences.readToken(server);
        if (api!.token != null) {
          username = preferences.username;
          loggedIn = true;
          try {
            await api!.map('/api/auth/session');
          } on ApiFailure catch (error) {
            if (error.status != 401) notice = '已恢复会话；${error.message}';
          }
        }
      }
    } catch (_) {
      notice = '无法恢复本地设置，请重新填写服务器地址并登录。';
      loggedIn = false;
    } finally {
      loading = false;
      _notify();
    }
    if (loggedIn) live?.start();
    unawaited(speech.initialize(preferences.rate));
  }

  void _useServer(String server) {
    live?.dispose();
    api?.dispose();
    api = QimingApi(server)..onUnauthorized = _expire;
    live = LiveConnection(api!);
  }

  Future<void> connect(String value) async {
    final url = normalizeServerUrl(value);
    final candidate = QimingApi(url);
    try {
      final result = await candidate.map('/api/health', authenticated: false);
      if (result['ok'] != true) throw const ApiFailure('地址可访问，但不是启明帽后端。');
      await candidate.map('/api/auth/captcha', authenticated: false);
    } finally {
      candidate.dispose();
    }
    await preferences.clearSession();
    await preferences.setServer(url);
    _useServer(url);
    loggedIn = false;
    notice = null;
    _notify();
  }

  Future<void> login({
    required String name,
    required String password,
    required String captchaId,
    required String captcha,
    required bool remember,
  }) async {
    final data = await api!.map(
      '/api/auth/login',
      method: 'POST',
      authenticated: false,
      data: {
        'username': name.trim(),
        'password': password,
        'captcha_id': captchaId,
        'captcha': captcha.trim(),
        'remember': remember,
      },
    );
    final token = data['token'];
    final user = data['user'];
    if (token is! String || user is! Map || user['username'] is! String) {
      throw const ApiFailure('登录接口格式不正确，请重启电脑后端。');
    }
    if (remember) {
      await preferences.saveSession(
        api!.baseUrl,
        token,
        user['username'] as String,
      );
    } else {
      await preferences.clearSession();
    }
    api!.token = token;
    username = user['username'] as String;
    loggedIn = true;
    notice = null;
    _notify();
    live!.start();
  }

  void _expire() {
    if (_expiring || !loggedIn || _disposed) return;
    _expiring = true;
    loggedIn = false;
    api?.token = null;
    live?.stop();
    unawaited(speech.stop());
    notice = '登录已过期，请重新登录。';
    unawaited(preferences.clearSession().catchError((Object _) {}));
    _notify();
    _expiring = false;
  }

  Future<void> logout() async {
    try {
      await api?.map('/api/auth/logout', method: 'POST');
    } catch (_) {
      /* Offline logout. */
    }
    live?.stop();
    await speech.stop();
    api?.token = null;
    loggedIn = false;
    username = '';
    try {
      await preferences.clearSession();
    } catch (_) {
      notice = '本机凭证清理失败，请重试退出或清除 App 数据。';
    }
    _notify();
  }

  Future<void> changeServer() async {
    await logout();
    live?.dispose();
    live = null;
    api?.dispose();
    api = null;
    notice = null;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    live?.dispose();
    api?.dispose();
    speech.dispose();
    super.dispose();
  }
}
