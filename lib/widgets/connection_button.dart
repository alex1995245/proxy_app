import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/connection_provider.dart';

class ConnectionButton extends StatefulWidget {
  const ConnectionButton({super.key});

  @override
  State<ConnectionButton> createState() => _ConnectionButtonState();
}

class _ConnectionButtonState extends State<ConnectionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _glowAnim = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectionProvider>(
      builder: (context, conn, _) {
        final isConnected = conn.status == ConnectionStatus.connected;
        final isBusy = conn.isConnecting;

        if (isConnected && !_controller.isAnimating) {
          _controller.repeat(reverse: true);
        } else if (!isConnected && !isBusy) {
          _controller.stop();
          _controller.reset();
        }

        return GestureDetector(
          onTap: isBusy
              ? null
              : () {
                  if (isConnected) {
                    conn.disconnect();
                  } else {
                    conn.connect();
                  }
                },
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final color = isConnected
                  ? const Color(0xFF00E676)
                  : isBusy
                      ? Colors.orange
                      : const Color(0xFF00E5FF);
              return Transform.scale(
                scale: isConnected ? _scaleAnim.value : 1.0,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF1A2235),
                    border: Border.all(color: color, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: color.withAlpha(
                          isConnected
                              ? ((_glowAnim.value * 255).round()
                                  .clamp(0, 255))
                              : 102,
                        ),
                        blurRadius: 30,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isBusy)
                        SizedBox(
                          width: 44,
                          height: 44,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: color,
                          ),
                        )
                      else
                        Icon(
                          isConnected
                              ? Icons.power_settings_new
                              : Icons.power_settings_new_outlined,
                          size: 52,
                          color: color,
                        ),
                      const SizedBox(height: 8),
                      Text(
                        isBusy
                            ? (conn.status == ConnectionStatus.switching
                                ? 'Switching'
                                : 'Connecting')
                            : (isConnected ? 'Disconnect' : 'Connect'),
                        style: TextStyle(
                          color: color,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
