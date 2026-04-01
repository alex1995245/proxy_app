import 'package:flutter/foundation.dart';

enum ProxyStatus { unknown, alive, dead, checking }
enum ProxyAnonymity { transparent, anonymous, elite }

@immutable
class ProxyModel {
  const ProxyModel({
    required this.ip,
    required this.port,
    this.username,
    this.password,
    this.country,
    this.countryCode,
    this.anonymity = ProxyAnonymity.elite,
    this.supportsHttps = false,
    this.latencyMs,
    this.status = ProxyStatus.unknown,
    this.isFavorite = false,
    this.isManual = false,
    this.protocol = 'socks5',
  });

  final String ip;
  final int port;
  final String? username;
  final String? password;
  final String? country;
  final String? countryCode;
  final ProxyAnonymity anonymity;
  final bool supportsHttps;
  final int? latencyMs;
  final ProxyStatus status;
  final bool isFavorite;
  final bool isManual;
  final String protocol;

  String get address => '$ip:$port';

  bool get requiresAuth => username != null && username!.isNotEmpty;

  ProxyModel copyWith({
    String? ip,
    int? port,
    String? username,
    String? password,
    String? country,
    String? countryCode,
    ProxyAnonymity? anonymity,
    bool? supportsHttps,
    int? latencyMs,
    ProxyStatus? status,
    bool? isFavorite,
    bool? isManual,
    String? protocol,
  }) {
    return ProxyModel(
      ip: ip ?? this.ip,
      port: port ?? this.port,
      username: username ?? this.username,
      password: password ?? this.password,
      country: country ?? this.country,
      countryCode: countryCode ?? this.countryCode,
      anonymity: anonymity ?? this.anonymity,
      supportsHttps: supportsHttps ?? this.supportsHttps,
      latencyMs: latencyMs ?? this.latencyMs,
      status: status ?? this.status,
      isFavorite: isFavorite ?? this.isFavorite,
      isManual: isManual ?? this.isManual,
      protocol: protocol ?? this.protocol,
    );
  }

  factory ProxyModel.fromJson(Map<String, dynamic> json) {
    ProxyAnonymity anonymity = ProxyAnonymity.elite;
    final rawAnon = (json['anonymity'] as String? ?? '').toLowerCase();
    if (rawAnon == 'transparent') {
      anonymity = ProxyAnonymity.transparent;
    } else if (rawAnon == 'anonymous') {
      anonymity = ProxyAnonymity.anonymous;
    }

    String ip = '';
    int port = 0;

    // 1) Try "proxy" field: may be "socks5://1.2.3.4:1080" or "1.2.3.4:1080"
    if (json.containsKey('proxy') && json['proxy'] is String) {
      String proxyStr = json['proxy'] as String;
      // Remove protocol prefix (socks4, socks5, http, https, etc.)
      proxyStr =
          proxyStr.replaceFirst(RegExp(r'^(socks[45]|https?):\/\/'), '');
      final parts = proxyStr.split(':');
      if (parts.length >= 2) {
        ip = parts[0];
        port = int.tryParse(parts[1]) ?? 0;
      }
    }

    // 2) Fallback: separate "ip" and "port" fields
    if (ip.isEmpty && json.containsKey('ip')) {
      ip = json['ip'] as String? ?? '';
    }
    if (port == 0 && json.containsKey('port')) {
      port = json['port'] is int
          ? json['port'] as int
          : int.tryParse(json['port']?.toString() ?? '') ?? 0;
    }

    // 3) Handle "host" field as alternative to "ip"
    if (ip.isEmpty && json.containsKey('host')) {
      ip = json['host'] as String? ?? '';
    }

    // 4) Geolocation from Proxifly API
    String? countryCode =
        json['countryCode'] as String? ?? json['cc'] as String?;
    String? country = json['country'] as String?;
    if (countryCode == null &&
        json.containsKey('geolocation') &&
        json['geolocation'] is Map) {
      final geo = json['geolocation'] as Map;
      countryCode = geo['country'] as String?;
      country = geo['city'] as String?;
    }

    return ProxyModel(
      ip: ip,
      port: port,
      country: country,
      countryCode: countryCode,
      anonymity: anonymity,
      supportsHttps: json['https'] as bool? ?? false,
      protocol: json['protocol'] as String? ?? 'socks5',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ip': ip,
      'port': port,
      if (username != null) 'username': username,
      if (password != null) 'password': password,
      'country': country,
      'countryCode': countryCode,
      'anonymity': anonymity.name,
      'supportsHttps': supportsHttps,
      'latencyMs': latencyMs,
      'status': status.name,
      'isFavorite': isFavorite,
      'isManual': isManual,
      'protocol': protocol,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProxyModel && ip == other.ip && port == other.port;

  @override
  int get hashCode => Object.hash(ip, port);

  @override
  String toString() => 'ProxyModel($ip:$port)';
}
