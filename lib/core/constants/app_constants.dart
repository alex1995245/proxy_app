class AppConstants {
  AppConstants._();

  // Proxifly API
  static const String proxiflyApiKey = '5KrgZUHY9UykVgwd8Yt7GUaGSp6fDh8wzFZfYYa7bvcu';
  static const String proxiflyApiUrl = 'https://api.proxifly.dev/proxy';
  static const String proxiflyIpUrl = 'https://api.proxifly.dev/ip';
  static const String proxiflyCdnUrl =
      'https://cdn.jsdelivr.net/gh/proxifly/free-proxy-list@main/proxies/protocols/socks5/data.json';

  // Health check
  static const int defaultHealthCheckInterval = 15; // seconds
  static const int defaultMaxFailures = 3;
  static const String healthCheckTarget = 'https://api.proxifly.dev/ip';
  static const int healthCheckTimeoutSeconds = 10;

  // Proxy defaults
  static const String defaultProtocol = 'socks5';
  static const String defaultAnonymity = 'elite';
  static const int defaultQuantity = 20;

  // SharedPreferences keys
  static const String keyApiKey = 'api_key';
  static const String keyHealthCheckInterval = 'health_check_interval';
  static const String keyMaxFailures = 'max_failures';
  static const String keyPreferredCountry = 'preferred_country';
  static const String keyAutoConnect = 'auto_connect';
  static const String keyDarkTheme = 'dark_theme';
  static const String keyFavoriteProxies = 'favorite_proxies';
  static const String keySwitchLog = 'switch_log';
  static const String keyEnableSystemProxy = 'enable_system_proxy';
}
