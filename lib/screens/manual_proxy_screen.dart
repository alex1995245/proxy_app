import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/proxy_model.dart';
import '../providers/connection_provider.dart';
import '../providers/proxy_list_provider.dart';

/// A screen that lets the user enter SOCKS5 proxy credentials manually and
/// immediately connect through the local bridge.
class ManualProxyScreen extends StatefulWidget {
  const ManualProxyScreen({super.key});

  @override
  State<ManualProxyScreen> createState() => _ManualProxyScreenState();
}

class _ManualProxyScreenState extends State<ManualProxyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ipCtrl = TextEditingController();
  final _portCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _isConnecting = false;

  @override
  void dispose() {
    _ipCtrl.dispose();
    _portCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveAndConnect() async {
    if (!_formKey.currentState!.validate()) return;

    final proxy = ProxyModel(
      ip: _ipCtrl.text.trim(),
      port: int.parse(_portCtrl.text.trim()),
      username:
          _userCtrl.text.trim().isEmpty ? null : _userCtrl.text.trim(),
      password:
          _passCtrl.text.trim().isEmpty ? null : _passCtrl.text.trim(),
      isManual: true,
      isFavorite: true,
      protocol: 'socks5',
    );

    // Save to favorites list
    context.read<ProxyListProvider>().addManualProxy(proxy);

    setState(() => _isConnecting = true);
    try {
      final connProvider = context.read<ConnectionProvider>();
      await connProvider.connect(proxy);

      if (!mounted) return;

      if (connProvider.isConnected) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connected via ${proxy.address}'),
            backgroundColor: const Color(0xFF00E676),
          ),
        );
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to connect to ${proxy.address}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manual Proxy')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Enter your SOCKS5 proxy credentials',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 20),

              // IP Address
              TextFormField(
                controller: _ipCtrl,
                decoration: const InputDecoration(
                  labelText: 'IP Address *',
                  hintText: '163.198.212.187',
                  prefixIcon: Icon(Icons.dns),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'IP is required' : null,
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 14),

              // Port
              TextFormField(
                controller: _portCtrl,
                decoration: const InputDecoration(
                  labelText: 'Port *',
                  hintText: '1080',
                  prefixIcon: Icon(Icons.outlet),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Port is required';
                  }
                  final port = int.tryParse(v.trim());
                  if (port == null || port < 1 || port > 65535) {
                    return 'Enter a valid port (1–65535)';
                  }
                  return null;
                },
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 14),

              const Divider(),
              const SizedBox(height: 8),
              const Text(
                'Authentication (optional)',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 10),

              // Username
              TextFormField(
                controller: _userCtrl,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 14),

              // Password
              TextFormField(
                controller: _passCtrl,
                obscureText: _obscurePass,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePass
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePass = !_obscurePass),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              ElevatedButton.icon(
                onPressed: _isConnecting ? null : _saveAndConnect,
                icon: _isConnecting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow),
                label: Text(_isConnecting ? 'Connecting…' : 'Save & Connect'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
