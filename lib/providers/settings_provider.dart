import 'package:flutter/foundation.dart';

import '../core/constants/app_constants.dart';
import '../services/storage_service.dart';

class SettingsProvider extends ChangeNotifier {
  SettingsProvider(this._storage) {
    _load();
  }

  final StorageService _storage;

  late String _apiKey;
  late int _healthCheckInterval;
  late int _maxFailures;
  late String _preferredCountry;
  late bool _autoConnect;
  late bool _darkTheme;
  late bool _enableSystemProxy;

  String get apiKey => _apiKey;
  int get healthCheckInterval => _healthCheckInterval;
  int get maxFailures => _maxFailures;
  String get preferredCountry => _preferredCountry;
  bool get autoConnect => _autoConnect;
  bool get darkTheme => _darkTheme;
  bool get enableSystemProxy => _enableSystemProxy;

  void _load() {
    _apiKey = _storage.apiKey;
    _healthCheckInterval = _storage.healthCheckInterval;
    _maxFailures = _storage.maxFailures;
    _preferredCountry = _storage.preferredCountry;
    _autoConnect = _storage.autoConnect;
    _darkTheme = _storage.darkTheme;
    _enableSystemProxy = _storage.enableSystemProxy;
  }

  Future<void> setApiKey(String value) async {
    _apiKey = value;
    await _storage.setApiKey(value);
    notifyListeners();
  }

  Future<void> setHealthCheckInterval(int value) async {
    _healthCheckInterval = value;
    await _storage.setHealthCheckInterval(value);
    notifyListeners();
  }

  Future<void> setMaxFailures(int value) async {
    _maxFailures = value;
    await _storage.setMaxFailures(value);
    notifyListeners();
  }

  Future<void> setPreferredCountry(String value) async {
    _preferredCountry = value;
    await _storage.setPreferredCountry(value);
    notifyListeners();
  }

  Future<void> setAutoConnect(bool value) async {
    _autoConnect = value;
    await _storage.setAutoConnect(value);
    notifyListeners();
  }

  Future<void> setDarkTheme(bool value) async {
    _darkTheme = value;
    await _storage.setDarkTheme(value);
    notifyListeners();
  }

  Future<void> setEnableSystemProxy(bool value) async {
    _enableSystemProxy = value;
    await _storage.setEnableSystemProxy(value);
    notifyListeners();
  }

  List<String> get switchLog => _storage.switchLog;

  Future<void> clearSwitchLog() async {
    await _storage.clearSwitchLog();
    notifyListeners();
  }

  String get defaultApiKey => AppConstants.proxiflyApiKey;
}
