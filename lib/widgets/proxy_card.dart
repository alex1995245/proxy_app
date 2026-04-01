import 'package:flutter/material.dart';

import '../core/utils/proxy_utils.dart';
import '../models/proxy_model.dart';

class ProxyCard extends StatelessWidget {
  const ProxyCard({
    super.key,
    required this.proxy,
    this.isActive = false,
    this.onTap,
    this.onFavorite,
    this.onTest,
  });

  final ProxyModel proxy;
  final bool isActive;
  final VoidCallback? onTap;
  final VoidCallback? onFavorite;
  final VoidCallback? onTest;

  Color _statusColor() {
    switch (proxy.status) {
      case ProxyStatus.alive:
        return const Color(0xFF00E676);
      case ProxyStatus.dead:
        return const Color(0xFFFF1744);
      case ProxyStatus.checking:
        return Colors.orange;
      case ProxyStatus.unknown:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _statusColor();
    final flag = ProxyUtils.countryFlag(proxy.countryCode);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: isActive
            ? const BorderSide(color: Color(0xFF00E5FF), width: 1.5)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // Status dot
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: statusColor.withAlpha(128), blurRadius: 6),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Flag
              Text(flag, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          proxy.address,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        if (isActive) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00E5FF).withAlpha(51),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'ACTIVE',
                              style: TextStyle(
                                color: Color(0xFF00E5FF),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      children: [
                        _Chip(
                          label: proxy.anonymity.name,
                          color: proxy.anonymity == ProxyAnonymity.elite
                              ? const Color(0xFF7C4DFF)
                              : Colors.blueGrey,
                        ),
                        if (proxy.latencyMs != null)
                          _Chip(
                            label: '${proxy.latencyMs}ms',
                            color: _latencyColor(proxy.latencyMs!),
                          ),
                        if (proxy.supportsHttps)
                          const _Chip(
                            label: 'HTTPS',
                            color: Color(0xFF00E676),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              // Actions
              Column(
                children: [
                  if (onFavorite != null)
                    IconButton(
                      icon: Icon(
                        proxy.isFavorite ? Icons.star : Icons.star_border,
                        size: 18,
                        color: proxy.isFavorite ? Colors.amber : Colors.grey,
                      ),
                      onPressed: onFavorite,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  if (onTest != null)
                    IconButton(
                      icon: proxy.status == ProxyStatus.checking
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.speed, size: 18, color: Colors.grey),
                      onPressed: onTest,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _latencyColor(int ms) {
    if (ms < 200) return const Color(0xFF00E676);
    if (ms < 600) return Colors.orange;
    return const Color(0xFFFF1744);
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(51),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(128), width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
