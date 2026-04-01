import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/connection_provider.dart';
import '../providers/proxy_list_provider.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionHeader('API Configuration'),
          _ApiKeyTile(settings: settings),
          const SizedBox(height: 16),

          _SectionHeader('Health Check'),
          _SliderTile(
            title: 'Check Interval',
            subtitle: '${settings.healthCheckInterval} seconds',
            value: settings.healthCheckInterval.toDouble(),
            min: 5,
            max: 60,
            divisions: 11,
            onChanged: (v) => settings.setHealthCheckInterval(v.round()),
          ),
          _SliderTile(
            title: 'Max Failures Before Switch',
            subtitle: '${settings.maxFailures} failures',
            value: settings.maxFailures.toDouble(),
            min: 1,
            max: 10,
            divisions: 9,
            onChanged: (v) => settings.setMaxFailures(v.round()),
          ),
          const SizedBox(height: 16),

          _SectionHeader('Proxy Preferences'),
          _CountryTile(settings: settings),
          const SizedBox(height: 16),

          _SectionHeader('App'),
          SwitchListTile(
            title: const Text('Auto-connect on startup'),
            value: settings.autoConnect,
            onChanged: settings.setAutoConnect,
          ),
          SwitchListTile(
            title: const Text('Dark Theme'),
            value: settings.darkTheme,
            onChanged: settings.setDarkTheme,
          ),
          SwitchListTile(
            title: const Text('Enable System-wide Proxy'),
            subtitle: const Text(
              'When enabled, most programs on your computer '
              '(Chrome, Edge, etc.) will use the SOCKS5 proxy. '
              'Note: Firefox uses its own proxy settings.',
            ),
            value: settings.enableSystemProxy,
            onChanged: settings.setEnableSystemProxy,
          ),
          const SizedBox(height: 16),

          _SectionHeader('Switch Log'),
          if (settings.switchLog.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No switches recorded yet.',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else ...[
            Card(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: settings.switchLog.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  child: Text(
                    settings.switchLog[i],
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: Colors.grey),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () {
                settings.clearSwitchLog();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Switch log cleared')),
                );
              },
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Clear log'),
            ),
          ],
          const SizedBox(height: 32),

          OutlinedButton.icon(
            onPressed: () {
              _reloadProxies(context);
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Reload Proxy List'),
          ),
        ],
      ),
    );
  }

  void _reloadProxies(BuildContext context) {
    final settings = context.read<SettingsProvider>();
    final conn = context.read<ConnectionProvider>();
    if (conn.isConnected) {
      conn.disconnect();
    }
    context.read<ProxyListProvider>().loadProxies(
          country: settings.preferredCountry.isEmpty
              ? null
              : settings.preferredCountry,
        );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reloading proxy list…')),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF00E5FF),
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}

class _ApiKeyTile extends StatefulWidget {
  const _ApiKeyTile({required this.settings});

  final SettingsProvider settings;

  @override
  State<_ApiKeyTile> createState() => _ApiKeyTileState();
}

class _ApiKeyTileState extends State<_ApiKeyTile> {
  late TextEditingController _controller;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.settings.apiKey);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      obscureText: _obscure,
      decoration: InputDecoration(
        labelText: 'Proxifly API Key',
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: () {
                widget.settings.setApiKey(_controller.text.trim());
                FocusScope.of(context).unfocus();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('API key saved')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SliderTile extends StatelessWidget {
  const _SliderTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subtitle, style: const TextStyle(color: Colors.grey)),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _CountryTile extends StatefulWidget {
  const _CountryTile({required this.settings});

  final SettingsProvider settings;

  @override
  State<_CountryTile> createState() => _CountryTileState();
}

class _CountryTileState extends State<_CountryTile> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.settings.preferredCountry);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      decoration: InputDecoration(
        labelText: 'Preferred Country (ISO code, e.g. US)',
        hintText: 'Leave empty for any',
        suffixIcon: IconButton(
          icon: const Icon(Icons.check),
          onPressed: () {
            widget.settings.setPreferredCountry(_ctrl.text.trim().toUpperCase());
            FocusScope.of(context).unfocus();
          },
        ),
      ),
      textCapitalization: TextCapitalization.characters,
      maxLength: 2,
    );
  }
}
