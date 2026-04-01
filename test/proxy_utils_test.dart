import 'package:flutter_test/flutter_test.dart';

import 'package:proxy_app/core/utils/proxy_utils.dart';
import 'package:proxy_app/models/proxy_model.dart';

void main() {
  group('ProxyUtils', () {
    test('countryFlag returns flag emoji for valid code', () {
      expect(ProxyUtils.countryFlag('US'), '🇺🇸');
      expect(ProxyUtils.countryFlag('DE'), '🇩🇪');
    });

    test('countryFlag returns globe for null/invalid code', () {
      expect(ProxyUtils.countryFlag(null), '🌐');
      expect(ProxyUtils.countryFlag(''), '🌐');
      expect(ProxyUtils.countryFlag('USA'), '🌐');
    });

    test('parseProxyString parses ip:port', () {
      final proxy = ProxyUtils.parseProxyString('1.2.3.4:1080');
      expect(proxy, isNotNull);
      expect(proxy!.ip, '1.2.3.4');
      expect(proxy.port, 1080);
      expect(proxy.username, isNull);
    });

    test('parseProxyString parses ip:port:user:pass', () {
      final proxy = ProxyUtils.parseProxyString('1.2.3.4:1080:user:pass');
      expect(proxy, isNotNull);
      expect(proxy!.username, 'user');
      expect(proxy.password, 'pass');
    });

    test('parseProxyString returns null for invalid input', () {
      expect(ProxyUtils.parseProxyString(''), isNull);
      expect(ProxyUtils.parseProxyString('noport'), isNull);
    });

    test('formatUptime formats correctly', () {
      expect(ProxyUtils.formatUptime(Duration.zero), '0s');
      expect(ProxyUtils.formatUptime(const Duration(seconds: 90)), '1m 30s');
      expect(
          ProxyUtils.formatUptime(const Duration(hours: 1, minutes: 5)),
          '1h 5m 0s');
    });

    test('latencyLabel returns correct label', () {
      expect(ProxyUtils.latencyLabel(100), 'Fast');
      expect(ProxyUtils.latencyLabel(400), 'Medium');
      expect(ProxyUtils.latencyLabel(1000), 'Slow');
      expect(ProxyUtils.latencyLabel(null), 'Unknown');
    });
  });

  group('ProxyModel', () {
    test('fromJson parses proxy field', () {
      final model = ProxyModel.fromJson({
        'proxy': '10.0.0.1:9050',
        'country': 'United States',
        'countryCode': 'US',
        'anonymity': 'elite',
        'https': true,
        'protocol': 'socks5',
      });
      expect(model.ip, '10.0.0.1');
      expect(model.port, 9050);
      expect(model.anonymity, ProxyAnonymity.elite);
      expect(model.supportsHttps, true);
    });

    test('fromJson strips socks5:// protocol prefix', () {
      final model = ProxyModel.fromJson({
        'proxy': 'socks5://1.2.3.4:1080',
        'countryCode': 'US',
      });
      expect(model.ip, '1.2.3.4');
      expect(model.port, 1080);
    });

    test('fromJson strips socks4:// protocol prefix', () {
      final model = ProxyModel.fromJson({'proxy': 'socks4://5.6.7.8:3128'});
      expect(model.ip, '5.6.7.8');
      expect(model.port, 3128);
    });

    test('fromJson strips http:// protocol prefix', () {
      final model = ProxyModel.fromJson({'proxy': 'http://9.10.11.12:8080'});
      expect(model.ip, '9.10.11.12');
      expect(model.port, 8080);
    });

    test('fromJson falls back to separate ip/port fields', () {
      final model = ProxyModel.fromJson({
        'ip': '1.2.3.4',
        'port': 9050,
        'countryCode': 'DE',
      });
      expect(model.ip, '1.2.3.4');
      expect(model.port, 9050);
    });

    test('fromJson reads host field as fallback', () {
      final model = ProxyModel.fromJson({
        'host': 'myproxy.example.com',
        'port': 1080,
      });
      expect(model.ip, 'myproxy.example.com');
      expect(model.port, 1080);
    });

    test('fromJson reads geolocation nested field', () {
      final model = ProxyModel.fromJson({
        'ip': '1.2.3.4',
        'port': 1080,
        'geolocation': {'country': 'US', 'city': 'New York'},
      });
      expect(model.countryCode, 'US');
      expect(model.country, 'New York');
    });

    test('address getter returns ip:port', () {
      const model = ProxyModel(ip: '1.2.3.4', port: 1080);
      expect(model.address, '1.2.3.4:1080');
    });

    test('equality is based on ip and port', () {
      const a = ProxyModel(ip: '1.2.3.4', port: 1080);
      const b = ProxyModel(ip: '1.2.3.4', port: 1080, country: 'US');
      expect(a, equals(b));
    });

    test('toJson round-trip', () {
      const model = ProxyModel(
        ip: '1.2.3.4',
        port: 1080,
        countryCode: 'US',
        anonymity: ProxyAnonymity.elite,
        supportsHttps: true,
        protocol: 'socks5',
      );
      final json = model.toJson();
      expect(json['ip'], '1.2.3.4');
      expect(json['port'], 1080);
      expect(json['anonymity'], 'elite');
    });
  });
}
