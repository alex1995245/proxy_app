import 'dart:io';

import 'package:socks5_proxy/socks_client.dart';

import '../models/proxy_model.dart';

/// Manages the active SOCKS5 proxy connection by installing a global
/// [HttpOverrides] that routes all HTTP/HTTPS traffic through the proxy.
class ProxyConnectionService {
  ProxyConnectionService._();

  static final ProxyConnectionService instance = ProxyConnectionService._();

  ProxyModel? _activeProxy;
  _Socks5HttpOverrides? _currentOverrides;

  ProxyModel? get activeProxy => _activeProxy;
  bool get isConnected => _activeProxy != null;

  /// Activate a SOCKS5 proxy globally for all HTTP traffic in the app.
  Future<bool> connect(ProxyModel proxy) async {
    try {
      disconnect();
      final overrides = _Socks5HttpOverrides(proxy);
      HttpOverrides.global = overrides;
      _currentOverrides = overrides;
      _activeProxy = proxy;
      return true;
    } catch (e) {
      _log('Connection error: $e');
      return false;
    }
  }

  /// Remove the global HTTP override and restore direct internet access.
  void disconnect() {
    HttpOverrides.global = null;
    _currentOverrides = null;
    _activeProxy = null;
  }

  void _log(String msg) {
    // ignore: avoid_print
    print('[ProxyConnectionService] $msg');
  }
}

/// A custom [HttpOverrides] implementation that routes requests through SOCKS5.
class _Socks5HttpOverrides extends HttpOverrides {
  _Socks5HttpOverrides(this.proxy);

  final ProxyModel proxy;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    SocksTCPClient.assignToHttpClient(client, [
      ProxySettings(
        InternetAddress(proxy.ip),
        proxy.port,
        type: SocksConnectionType.v5,
        username: proxy.username,
        password: proxy.password,
      ),
    ]);
    return client;
  }
}
