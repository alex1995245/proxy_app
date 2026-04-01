import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/proxy_model.dart';
import '../providers/connection_provider.dart';
import '../providers/proxy_list_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/proxy_card.dart';
import 'add_proxy_screen.dart';

class ProxyListScreen extends StatelessWidget {
  const ProxyListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final proxyList = context.watch<ProxyListProvider>();
    final conn = context.watch<ConnectionProvider>();
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Proxy List'),
        actions: [
          IconButton(
            icon: const Icon(Icons.speed),
            tooltip: 'Test All',
            onPressed: proxyList.isLoading
                ? null
                : () => proxyList.testAllProxies(),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Proxy',
            onPressed: () => _openAddProxy(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => proxyList.loadProxies(
          country: settings.preferredCountry.isEmpty
              ? null
              : settings.preferredCountry,
        ),
        child: _buildBody(context, proxyList, conn),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    ProxyListProvider proxyList,
    ConnectionProvider conn,
  ) {
    if (proxyList.isLoading && proxyList.proxies.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading proxies…', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    if (proxyList.loadingState == LoadingState.error &&
        proxyList.proxies.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(
              proxyList.errorMessage ?? 'Failed to load proxies',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => proxyList.loadProxies(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (proxyList.proxies.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.list_alt, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('No proxies loaded',
                style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => proxyList.loadProxies(),
              child: const Text('Load Proxies'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: proxyList.proxies.length,
      itemBuilder: (context, i) {
        final proxy = proxyList.proxies[i];
        return ProxyCard(
          proxy: proxy,
          isActive: conn.activeProxy?.address == proxy.address,
          onTap: () => _connectToProxy(context, conn, proxy),
          onFavorite: () => proxyList.toggleFavorite(proxy),
          onTest: proxy.status == ProxyStatus.checking
              ? null
              : () => proxyList.testProxy(proxy),
        );
      },
    );
  }

  Future<void> _connectToProxy(
    BuildContext context,
    ConnectionProvider conn,
    ProxyModel proxy,
  ) async {
    if (conn.activeProxy?.address == proxy.address) {
      conn.disconnect();
      return;
    }
    await conn.connect(proxy);
  }

  void _openAddProxy(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AddProxyScreen()),
    );
  }
}
