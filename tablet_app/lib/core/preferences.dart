import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppPreferences {
  AppPreferences(this.values, {FlutterSecureStorage? storage})
    : storage = storage ?? const FlutterSecureStorage();
  final SharedPreferences values;
  final FlutterSecureStorage storage;
  static const defaultServer = String.fromEnvironment('API_BASE_URL');

  String get server => values.getString('server') ?? defaultServer;
  String get username => values.getString('username') ?? '';
  bool get autoRead => values.getBool('autoRead') ?? true;
  double get rate => values.getDouble('speechRate') ?? 0.45;
  Future<void> setServer(String value) => values.setString('server', value);
  Future<void> setAutoRead(bool value) => values.setBool('autoRead', value);
  Future<void> setRate(double value) => values.setDouble('speechRate', value);

  String get sourceId {
    final saved = values.getString('sourceId');
    if (saved != null && RegExp(r'^tablet_[a-f0-9]{32}$').hasMatch(saved)) {
      return saved;
    }
    final random = Random.secure();
    final id =
        'tablet_${List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
    values.setString('sourceId', id);
    return id;
  }

  Future<String?> readToken(String server) async {
    if (values.getString('tokenServer') != server) return null;
    return storage.read(key: 'sessionToken');
  }

  Future<void> saveSession(String server, String token, String username) async {
    await storage.write(key: 'sessionToken', value: token);
    await values.setString('tokenServer', server);
    await values.setString('username', username);
  }

  Future<void> clearSession() async {
    await storage.delete(key: 'sessionToken');
    await values.remove('tokenServer');
    await values.remove('username');
  }
}
