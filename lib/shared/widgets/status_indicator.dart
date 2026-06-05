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
      case ConnectionStatus.disconnected:
        return TetherColors.textDisabled;
      case ConnectionStatus.searching:
        return TetherColors.accentPrimary;
    }
  }

  String get _label {
    switch (widget.status) {
      case ConnectionStatus.connected:
        return 'Connected';
      case ConnectionStatus.disconnected:
        return 'Disconnected';
      case ConnectionStatus.searching:
        return 'Searching...';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            final scale = widget.status == ConnectionStatus.disconnected
                ? 1.0
                : _pulseAnimation.value;
            return Container(
              width: widget.size * scale,
              height: widget.size * scale,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _dotColor,
                boxShadow: widget.status == ConnectionStatus.connected
                    ? [
                        BoxShadow(
                          color: _dotColor.withAlpha(80),
                          blurRadius: widget.size * 0.8 * scale,
                          spreadRadius: widget.size * 0.2 * (scale - 1),
                        ),
                      ]
                    : null,
              ),
            );
          },
        ),
        if (widget.showLabel) ...[
          SizedBox(width: TetherSpacing.sm),
          Flexible(
            child: Text(
              _label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: _dotColor,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ],
    );
  }
}
