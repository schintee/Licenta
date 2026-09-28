import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AppSettings extends ChangeNotifier {
  static final AppSettings instance = AppSettings._internal();

  AppSettings._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  bool _darkMode = true;

  bool get darkMode => _darkMode;
  ThemeMode get themeMode => _darkMode ? ThemeMode.dark : ThemeMode.light;

  Future<void> load() async {
    final saved = await _storage.read(key: 'darkMode');
    _darkMode = saved == null ? true : saved == 'true';
    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    _darkMode = value;
    await _storage.write(key: 'darkMode', value: value.toString());
    notifyListeners();
  }
}