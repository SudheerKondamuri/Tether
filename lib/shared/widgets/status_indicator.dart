import 'package:flutter/material.dart';
import 'package:tether/shared/theme.dart';

enum ConnectionStatus { connected, disconnected, searching }

/// Animated status dot with optional label.
class StatusIndicator extends StatefulWidget {
  final ConnectionStatus status;
  final double size;
  final bool showLabel;

  const StatusIndicator({
    super.key,
    required this.status,
    this.size = 10,
    this.showLabel = false,
  });

  @override
  State<StatusIndicator> createState() => _StatusIndicatorState();
}

class _StatusIndicatorState extends State<StatusIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.4).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _updateAnimation();
  }

  @override
  void didUpdateWidget(StatusIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status) {
      _updateAnimation();
    }
  }

  void _updateAnimation() {
    if (widget.status == ConnectionStatus.connected ||
        widget.status == ConnectionStatus.searching) {
      _controller.repeat(reverse: true);
    } else {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color get _dotColor {
    switch (widget.status) {
      case ConnectionStatus.connected:
        return TetherColors.accentSecondary;

}}}
