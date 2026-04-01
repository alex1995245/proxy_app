import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_constants.dart';
import '../models/proxy_model.dart';

class StorageService {
  StorageService._();

  static final StorageService instance = StorageService._();

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  SharedPreferences get _p {
    assert(_prefs != null, 'StorageService not initialized');
    return _prefs!;
  }

  // ── Settings ────────────────────────────────────────────────────────────────

  String get apiKey =>
      _p.getString(AppConstants.keyApiKey) ?? AppConstants.proxiflyApiKey;

  Future<void> setApiKey(String value) =>
      _p.setString(AppConstants.keyApiKey, value);

  int get healthCheckInterval =>
      _p.getInt(AppConstants.keyHealthCheckInterval) ??
      AppConstants.defaultHealthCheckInterval;

  Future<void> setHealthCheckInterval(int value) =>
      _p.setInt(AppConstants.keyHealthCheckInterval, value);

  int get maxFailures =>
      _p.getInt(AppConstants.keyMaxFailures) ?? AppConstants.defaultMaxFailures;

  Future<void> setMaxFailures(int value) =>
      _p.setInt(AppConstants.keyMaxFailures, value);

  String get preferredCountry =>
      _p.getString(AppConstants.keyPreferredCountry) ?? '';

  Future<void> setPreferredCountry(String value) =>
      _p.setString(AppConstants.keyPreferredCountry, value);

  bool get autoConnect => _p.getBool(AppConstants.keyAutoConnect) ?? false;

  Future<void> setAutoConnect(bool value) =>
      _p.setBool(AppConstants.keyAutoConnect, value);

  bool get darkTheme => _p.getBool(AppConstants.keyDarkTheme) ?? true;

  Future<void> setDarkTheme(bool value) =>
      _p.setBool(AppConstants.keyDarkTheme, value);

  // ── Favourite proxies ────────────────────────────────────────────────────────

  List<ProxyModel> get favoriteProxies {
    final raw = _p.getStringList(AppConstants.keyFavoriteProxies) ?? [];
    return raw.map((s) {
      try {
        return ProxyModel.fromJson(json.decode(s) as Map<String, dynamic>);
      } catch (_) {
        return null;
      }
    }).whereType<ProxyModel>().toList();
  }

  Future<void> saveFavoriteProxies(List<ProxyModel> proxies) {
    final raw = proxies.map((p) => json.encode(p.toJson())).toList();
    return _p.setStringList(AppConstants.keyFavoriteProxies, raw);
  }

  // ── Switch log ───────────────────────────────────────────────────────────────

  List<String> get switchLog =>
      _p.getStringList(AppConstants.keySwitchLog) ?? [];

  Future<void> appendSwitchLog(String entry) {
    final log = switchLog;
    log.insert(0, entry);
    if (log.length > 100) log.removeRange(100, log.length);
    return _p.setStringList(AppConstants.keySwitchLog, log);
  }

  Future<void> clearSwitchLog() =>
      _p.setStringList(AppConstants.keySwitchLog, []);
}
