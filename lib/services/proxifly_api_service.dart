import 'dart:convert';

import 'package:dio/dio.dart';

import '../core/constants/app_constants.dart';
import '../core/utils/proxy_utils.dart';
import '../models/proxy_model.dart';

class ProxiflyApiService {
  ProxiflyApiService({String? apiKey}) : _apiKey = apiKey ?? AppConstants.proxiflyApiKey {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ));
  }

  final String _apiKey;
  late final Dio _dio;

  /// Fetch proxy list from Proxifly REST API
  Future<List<ProxyModel>> fetchProxies({
    String protocol = 'socks5',
    String anonymity = 'elite',
    int quantity = 20,
    String? country,
  }) async {
    try {
      final body = <String, dynamic>{
        'protocol': protocol,
        'anonymity': anonymity,
        'format': 'json',
        'quantity': quantity,
        if (country != null && country.isNotEmpty) 'country': country,
      };

      final response = await _dio.post(
        AppConstants.proxiflyApiUrl,
        data: json.encode(body),
        options: Options(
          headers: {'x-api-key': _apiKey},
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is List) {
          return ProxyUtils.parseProxyListJson(data);
        }
      }
    } on DioException catch (e) {
      // Fall through to CDN backup
      _logError('Proxifly API error: ${e.message}');
    } catch (e) {
      _logError('Unexpected error fetching proxies: $e');
    }

    // Fallback to CDN list
    return _fetchFromCdn();
  }

  /// Fetch proxy list from CDN backup
  Future<List<ProxyModel>> _fetchFromCdn() async {
    try {
      final response = await _dio.get(AppConstants.proxiflyCdnUrl);
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is List) {
          return ProxyUtils.parseProxyListJson(data);
        }
      }
    } on DioException catch (e) {
      _logError('CDN fetch error: ${e.message}');
    } catch (e) {
      _logError('Unexpected CDN error: $e');
    }
    return [];
  }

  /// Get the external IP as seen by the server (optionally through a proxy)
  Future<String?> getExternalIp() async {
    try {
      final response = await _dio.get(AppConstants.proxiflyIpUrl);
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map && data.containsKey('ip')) {
          return data['ip'] as String?;
        }
        if (data is String) return data.trim();
      }
    } catch (e) {
      _logError('IP check error: $e');
    }
    return null;
  }

  void _logError(String message) {
    // ignore: avoid_print
    print('[ProxiflyApiService] $message');
  }

  void dispose() {
    _dio.close();
  }
}
