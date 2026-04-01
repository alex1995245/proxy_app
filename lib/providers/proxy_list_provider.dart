import 'package:flutter/foundation.dart';

import '../models/proxy_model.dart';
import '../services/health_check_service.dart';
import '../services/proxifly_api_service.dart';
import '../services/storage_service.dart';

enum LoadingState { idle, loading, error }

class ProxyListProvider extends ChangeNotifier {
  ProxyListProvider({
    required ProxiflyApiService apiService,
    required StorageService storage,
  })  : _apiService = apiService,
        _storage = storage;

  final ProxiflyApiService _apiService;
  final StorageService _storage;

  List<ProxyModel> _proxies = [];
  List<ProxyModel> _favorites = [];
  LoadingState _loadingState = LoadingState.idle;
  String? _errorMessage;

  List<ProxyModel> get proxies => _proxies;
  List<ProxyModel> get favorites => _favorites;
  LoadingState get loadingState => _loadingState;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _loadingState == LoadingState.loading;

  void init() {
    _favorites = _storage.favoriteProxies;
  }

  Future<void> loadProxies({String? country}) async {
    _loadingState = LoadingState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final fetched = await _apiService.fetchProxies(country: country);
      // Merge with favorites (avoid duplicates)
      final allProxies = [..._favorites, ...fetched]
          .fold<Map<String, ProxyModel>>({}, (map, p) {
        map[p.address] = p;
        return map;
      }).values.toList();

      _proxies = allProxies;
      _loadingState = LoadingState.idle;
    } catch (e) {
      _errorMessage = 'Failed to load proxies: $e';
      _loadingState = LoadingState.error;
    }

    notifyListeners();
  }

  Future<void> testAllProxies() async {
    final snapshot = List<ProxyModel>.from(_proxies);
    for (var i = 0; i < snapshot.length; i++) {
      final updatedProxy = await _testProxy(snapshot[i]);
      if (i < _proxies.length) {
        _proxies[i] = updatedProxy;
      }
      notifyListeners();
    }
    _sortByLatency();
    notifyListeners();
  }

  Future<ProxyModel> testProxy(ProxyModel proxy) async {
    final idx = _proxies.indexOf(proxy);
    final updated = await _testProxy(proxy);
    if (idx >= 0) {
      _proxies[idx] = updated;
      notifyListeners();
    }
    return updated;
  }

  Future<ProxyModel> _testProxy(ProxyModel proxy) async {
    final latency = await HealthCheckService.measureLatency(proxy);
    return proxy.copyWith(
      latencyMs: latency,
      status: latency != null ? ProxyStatus.alive : ProxyStatus.dead,
    );
  }

  void _sortByLatency() {
    _proxies.sort((a, b) {
      if (a.latencyMs == null && b.latencyMs == null) return 0;
      if (a.latencyMs == null) return 1;
      if (b.latencyMs == null) return -1;
      return a.latencyMs!.compareTo(b.latencyMs!);
    });
  }

  void addManualProxy(ProxyModel proxy) {
    final updated = proxy.copyWith(isManual: true, isFavorite: true);
    _proxies.removeWhere((p) => p.address == updated.address);
    _proxies.insert(0, updated);
    _favorites.removeWhere((p) => p.address == updated.address);
    _favorites.add(updated);
    _storage.saveFavoriteProxies(_favorites);
    notifyListeners();
  }

  void toggleFavorite(ProxyModel proxy) {
    final idx = _proxies.indexOf(proxy);
    if (idx < 0) return;
    final updated = proxy.copyWith(isFavorite: !proxy.isFavorite);
    _proxies[idx] = updated;

    if (updated.isFavorite) {
      _favorites.add(updated);
    } else {
      _favorites.removeWhere((p) => p.address == updated.address);
    }
    _storage.saveFavoriteProxies(_favorites);
    notifyListeners();
  }

  /// Returns the first alive proxy that is not [excludeProxy].
  ProxyModel? nextAliveProxy({ProxyModel? excludeProxy}) {
    return _proxies.firstWhere(
      (p) =>
          p != excludeProxy &&
          p.status != ProxyStatus.dead,
      orElse: () => _proxies.firstWhere(
        (p) => p != excludeProxy,
        orElse: () => throw StateError('No proxies available'),
      ),
    );
  }
}
