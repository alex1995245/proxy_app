import 'dart:async';
import 'dart:io';

import '../core/constants/app_constants.dart';
import '../models/proxy_model.dart';

typedef OnProxyDead = Future<void> Function();

/// Periodically checks if the active proxy is alive.
/// After [maxFailures] consecutive failures it calls [onProxyDead].
class HealthCheckService {
  HealthCheckService({
    this.intervalSeconds = AppConstants.defaultHealthCheckInterval,
    this.maxFailures = AppConstants.defaultMaxFailures,
    required this.onProxyDead,
  });

  final int intervalSeconds;
  final int maxFailures;
  final OnProxyDead onProxyDead;

  Timer? _timer;
  int _failureCount = 0;
  bool _isRunning = false;

  bool get isRunning => _isRunning;

  void start(ProxyModel proxy) {
    stop();
    _failureCount = 0;
    _isRunning = true;
    _timer = Timer.periodic(
      Duration(seconds: intervalSeconds),
      (_) => _check(proxy),
    );
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
    _failureCount = 0;
  }

  Future<void> _check(ProxyModel proxy) async {
    final alive = await _ping(proxy);
    if (alive) {
      _failureCount = 0;
    } else {
      _failureCount++;
      _log('Health check failed for ${proxy.address}. '
          'Failures: $_failureCount/$maxFailures');
      if (_failureCount >= maxFailures) {
        stop();
        await onProxyDead();
      }
    }
  }

  /// Attempts a TCP connection through the given proxy to the health-check
  /// target. Returns true if successful within the timeout.
  Future<bool> _ping(ProxyModel proxy) async {
    try {
      final socket = await Socket.connect(
        proxy.ip,
        proxy.port,
        timeout:
            const Duration(seconds: AppConstants.healthCheckTimeoutSeconds),
      );
      await socket.close();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Quick latency measurement for a proxy (TCP connect time in ms).
  static Future<int?> measureLatency(ProxyModel proxy) async {
    final stopwatch = Stopwatch()..start();
    try {
      final socket = await Socket.connect(
        proxy.ip,
        proxy.port,
        timeout: const Duration(seconds: AppConstants.healthCheckTimeoutSeconds),
      );
      stopwatch.stop();
      await socket.close();
      return stopwatch.elapsedMilliseconds;
    } catch (_) {
      stopwatch.stop();
      return null;
    }
  }

  void _log(String msg) {
    // ignore: avoid_print
    print('[HealthCheckService] $msg');
  }
}
