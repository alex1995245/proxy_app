import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/utils/proxy_utils.dart';
import '../providers/connection_provider.dart';
import '../providers/proxy_list_provider.dart';
import '../widgets/connection_button.dart';
import '../widgets/stats_card.dart';
import '../widgets/status_indicator.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadIfEmpty();
    });
  }

  void _loadIfEmpty() {
    final proxyList = context.read<ProxyListProvider>();
    if (proxyList.proxies.isEmpty && !proxyList.isLoading) {
      proxyList.loadProxies();
    }
  }

  @override
  Widget build(BuildContext context) {
    final conn = context.watch<ConnectionProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SOCKS5 Proxy Manager'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: StatusIndicator(status: conn.status),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Connection Button
            Center(child: const ConnectionButton()),
            const SizedBox(height: 28),

            // Active proxy info
            if (conn.activeProxy != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Active Proxy',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            conn.activeProxy!.address,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF00E5FF),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            conn.activeProxy!.countryCode != null
                                ? ProxyUtils.countryFlag(
                                    conn.activeProxy!.countryCode)
                                : '🌐',
                            style: const TextStyle(fontSize: 20),
                          ),
                        ],
                      ),
                      if (conn.activeProxy!.latencyMs != null)
                        Text(
                          'Latency: ${conn.activeProxy!.latencyMs}ms',
                          style: const TextStyle(color: Colors.grey),
                        ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 12),

            // Stats grid
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.4,
              children: [
                StatsCard(
                  title: 'EXTERNAL IP',
                  value: conn.externalIp ?? '—',
                  icon: Icons.public,
                  color: const Color(0xFF00E5FF),
                ),
                StatsCard(
                  title: 'UPTIME',
                  value: conn.isConnected ? conn.uptimeFormatted : '—',
                  icon: Icons.timer_outlined,
                  color: const Color(0xFF00E676),
                ),
                StatsCard(
                  title: 'SWITCHES',
                  value: '${conn.switchCount}',
                  subtitle: 'auto-failover count',
                  icon: Icons.swap_horiz,
                  color: const Color(0xFF7C4DFF),
                ),
                StatsCard(
                  title: 'FAILURES',
                  value: '${conn.failCount}',
                  subtitle: 'total proxy failures',
                  icon: Icons.warning_amber_rounded,
                  color: Colors.orange,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Notifications / Switch log
            if (conn.notifications.isNotEmpty) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'RECENT EVENTS',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                    letterSpacing: 1.2,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: conn.notifications.take(10).length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      child: Text(
                        conn.notifications[i],
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: Colors.grey),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
