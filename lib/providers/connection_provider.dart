import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/utils/proxy_utils.dart';
import '../models/proxy_model.dart';
import '../services/health_check_service.dart';
import '../services/local_proxy_server.dart';
import '../services/proxifly_api_service.dart';
import '../services/proxy_connection_service.dart';
import '../services/storage_service.dart';
import '../services/system_proxy_service.dart';
import 'proxy_list_provider.dart';
import 'settings_provider.dart';

enum ConnectionStatus { disconnected, connecting, connected, switching }

class ConnectionProvider extends ChangeNotifier {
  ConnectionProvider({
    required ProxyListProvider proxyListProvider,
    required SettingsProvider settings,
    required StorageService storage,
    required ProxyConnectionService connectionService,
    required ProxiflyApiService apiService,
  })  : _proxyList = proxyListProvider,
        _settings = settings,
        _storage = storage,
        _connectionService = connectionService,
        _apiService = apiService;

  final ProxyListProvider _proxyList;
  final SettingsProvider _settings;
  final StorageService _storage;
  final ProxyConnectionService _connectionService;
  final ProxiflyApiService _apiService;

  HealthCheckService? _healthCheck;
  final LocalProxyServer _localProxy = LocalProxyServer();

  ConnectionStatus _status = ConnectionStatus.disconnected;
  ProxyModel? _activeProxy;
  String? _externalIp;
  DateTime? _connectedAt;
  int _switchCount = 0;
  int _failCount = 0;
  final List<String> _notifications = [];

  ConnectionStatus get status => _status;
  ProxyModel? get activeProxy => _activeProxy;
  String? get externalIp => _externalIp;
  int get switchCount => _switchCount;
  int get failCount => _failCount;
  List<String> get notifications => List.unmodifiable(_notifications);
  bool get isConnected => _status == ConnectionStatus.connected;
  bool get isConnecting =>
      _status == ConnectionStatus.connecting ||
      _status == ConnectionStatus.switching;

  /// Returns true when the local SOCKS5 bridge is active.
  bool get isBridgeRunning => _localProxy.isRunning;

  /// Returns a human-readable description of the active bridge, e.g.
  /// "127.0.0.1:1080 → 163.198.212.187:8000", or null when not running.
  String? get bridgeDescription {
    if (!_localProxy.isRunning || _activeProxy == null) return null;
    return '127.0.0.1:${_localProxy.localPort} → ${_activeProxy!.address}';
  }

  Duration get uptime {
    if (_connectedAt == null) return Duration.zero;
    return DateTime.now().difference(_connectedAt!);
  }

  String get uptimeFormatted => ProxyUtils.formatUptime(uptime);

  /// Connect to the given proxy (or pick the best available one).
  Future<void> connect([ProxyModel? proxy]) async {
    _setStatus(ConnectionStatus.connecting);

    final target = proxy ?? _pickBestProxy();
    if (target == null) {
      _addNotification('No proxies available. Loading list…');
      await _proxyList.loadProxies(country: _settings.preferredCountry);
      final next = _pickBestProxy();
      if (next == null) {
        _setStatus(ConnectionStatus.disconnected);
        _addNotification('Could not find a working proxy.');
        return;
      }
      return connect(next);
    }

    final ok = await _connectionService.connect(target);
    if (!ok) {
      _addNotification('Failed to connect to ${target.address}. Trying next…');
      return _failoverToNext(target);
    }

    _activeProxy = target;
    _connectedAt = DateTime.now();
    _setStatus(ConnectionStatus.connected);
    _startHealthCheck();
    unawaited(_refreshExternalIp());

    if (_settings.enableSystemProxy) {
      // Start local SOCKS5 bridge (no-auth) that forwards to the remote proxy
      final bridgeOk = await _localProxy.start(
        remoteHost: target.ip,
        remotePort: target.port,
        username: target.username,
        password: target.password,
      );

      if (bridgeOk) {
        _addNotification(
            'Local proxy bridge started on 127.0.0.1:${_localProxy.localPort}');
        final sysOk = await SystemProxyService.enableProxy(
            '127.0.0.1', _localProxy.localPort);
        if (sysOk) {
          _addNotification(
              'System proxy enabled: 127.0.0.1:${_localProxy.localPort}');
        }
      } else {
        // Fallback: use the remote proxy directly in the registry
        final sysOk =
            await SystemProxyService.enableProxy(target.ip, target.port);
        if (sysOk) {
          _addNotification(
              'System proxy enabled for ${target.ip}:${target.port}');
        }
      }
    }
  }

  void disconnect() {
    _stopHealthCheck();
    _localProxy.stop();
    _connectionService.disconnect();
    _activeProxy = null;
    _externalIp = null;
    _connectedAt = null;
    _setStatus(ConnectionStatus.disconnected);
    notifyListeners();
    unawaited(SystemProxyService.disableProxy());
  }

  /// Called by the health-check service when the active proxy has died.
  Future<void> _onProxyDead() async {
    final dead = _activeProxy;
    _failCount++;
    final msg =
        '[${_timestamp()}] Proxy ${dead?.address ?? 'unknown'} died. Switching…';
    _addNotification(msg);
    await _storage.appendSwitchLog(msg);
    await _failoverToNext(dead);
  }

  Future<void> _failoverToNext(ProxyModel? deadProxy) async {
    _setStatus(ConnectionStatus.switching);
    _stopHealthCheck();

    ProxyModel? next;
    try {
      next = _proxyList.nextAliveProxy(excludeProxy: deadProxy);
    } catch (_) {
      // No proxies available — reload
      _addNotification('All proxies dead. Reloading list from API…');
      await _proxyList.loadProxies(country: _settings.preferredCountry);
      try {
        next = _proxyList.nextAliveProxy(excludeProxy: deadProxy);
      } catch (_) {
        _addNotification('Could not find any working proxy.');
        _setStatus(ConnectionStatus.disconnected);
        return;
      }
    }

    _switchCount++;
    final msg =
        '[${_timestamp()}] Switched to ${next.address}';
    _addNotification(msg);
    await _storage.appendSwitchLog(msg);
    await connect(next);
  }

  void _startHealthCheck() {
    _stopHealthCheck();
    _healthCheck = HealthCheckService(
      intervalSeconds: _settings.healthCheckInterval,
      maxFailures: _settings.maxFailures,
      onProxyDead: _onProxyDead,
    );
    if (_activeProxy != null) {
      _healthCheck!.start(_activeProxy!);
    }
  }

  void _stopHealthCheck() {
    _healthCheck?.stop();
    _healthCheck = null;
  }

  Future<void> _refreshExternalIp() async {
    final ip = await _apiService.getExternalIp();
    _externalIp = ip;
    notifyListeners();
  }

  ProxyModel? _pickBestProxy() {
    final alive = _proxyList.proxies
        .where((p) => p.status != ProxyStatus.dead)
        .toList()
      ..sort((a, b) {
        if (a.latencyMs == null) return 1;
        if (b.latencyMs == null) return -1;
        return a.latencyMs!.compareTo(b.latencyMs!);
      });
    return alive.isNotEmpty ? alive.first : _proxyList.proxies.firstOrNull;
  }

  void _setStatus(ConnectionStatus status) {
    _status = status;
    notifyListeners();
  }

  void _addNotification(String msg) {
    _notifications.insert(0, msg);
    if (_notifications.length > 50) _notifications.removeLast();
    notifyListeners();
  }

  String _timestamp() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _stopHealthCheck();
    _localProxy.stop();
    super.dispose();
  }
}
