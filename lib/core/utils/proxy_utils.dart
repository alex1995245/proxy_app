import '../../models/proxy_model.dart';

class ProxyUtils {
  ProxyUtils._();

  /// Parses a proxy string in format "ip:port" or "ip:port:user:pass"
  static ProxyModel? parseProxyString(String raw) {
    try {
      final parts = raw.trim().split(':');
      if (parts.length < 2) return null;
      final ip = parts[0];
      final port = int.tryParse(parts[1]);
      if (port == null) return null;
      final username = parts.length > 2 ? parts[2] : null;
      final password = parts.length > 3 ? parts[3] : null;
      return ProxyModel(
        ip: ip,
        port: port,
        username: username,
        password: password,
      );
    } catch (_) {
      return null;
    }
  }

  /// Returns a country flag emoji for a given ISO country code
  static String countryFlag(String? countryCode) {
    if (countryCode == null || countryCode.isEmpty) return '🌐';
    final code = countryCode.toUpperCase();
    if (code.length != 2) return '🌐';
    final firstLetter = code.codeUnitAt(0) - 0x41 + 0x1F1E6;
    final secondLetter = code.codeUnitAt(1) - 0x41 + 0x1F1E6;
    return String.fromCharCode(firstLetter) + String.fromCharCode(secondLetter);
  }

  /// Returns a color label for latency
  static String latencyLabel(int? latencyMs) {
    if (latencyMs == null) return 'Unknown';
    if (latencyMs < 200) return 'Fast';
    if (latencyMs < 600) return 'Medium';
    return 'Slow';
  }

  /// Formats uptime in human readable string
  static String formatUptime(Duration uptime) {
    final hours = uptime.inHours;
    final minutes = uptime.inMinutes.remainder(60);
    final seconds = uptime.inSeconds.remainder(60);
    if (hours > 0) return '${hours}h ${minutes}m ${seconds}s';
    if (minutes > 0) return '${minutes}m ${seconds}s';
    return '${seconds}s';
  }

  /// Formats bytes to human-readable size
  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Parse JSON proxy list from Proxifly API or CDN
  static List<ProxyModel> parseProxyListJson(List<dynamic> json) {
    final proxies = <ProxyModel>[];
    for (final item in json) {
      try {
        if (item is Map<String, dynamic>) {
          final proxy = ProxyModel.fromJson(item);
          proxies.add(proxy);
        }
      } catch (_) {
        // skip malformed entries
      }
    }
    return proxies;
  }
}
