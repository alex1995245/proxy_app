import 'package:flutter/material.dart';

import '../providers/connection_provider.dart';

class StatusIndicator extends StatelessWidget {
  const StatusIndicator({super.key, required this.status, this.size = 12});

  final ConnectionStatus status;
  final double size;

  Color _color() {
    switch (status) {
      case ConnectionStatus.connected:
        return const Color(0xFF00E676);
      case ConnectionStatus.disconnected:
        return const Color(0xFFFF1744);
      case ConnectionStatus.connecting:
      case ConnectionStatus.switching:
        return Colors.orange;
    }
  }

  String _label() {
    switch (status) {
      case ConnectionStatus.connected:
        return 'Connected';
      case ConnectionStatus.disconnected:
        return 'Disconnected';
      case ConnectionStatus.connecting:
        return 'Connecting';
      case ConnectionStatus.switching:
        return 'Switching';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PulseDot(color: color, size: size),
        const SizedBox(width: 6),
        Text(
          _label(),
          style: TextStyle(
            color: color,
            fontSize: size + 2,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.8, end: 1.2).animate(
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
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: widget.color.withAlpha(128), blurRadius: 6),
          ],
        ),
      ),
    );
  }
}
