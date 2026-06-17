import 'package:flutter/material.dart';
import 'package:tether/shared/theme.dart';
import 'package:tether/shared/widgets/tether_button.dart';

/// A UI lock placeholder displayed when there is no active peer connection.
class DisconnectedOverlay extends StatefulWidget {
  final String featureName;
  final String actionLabel;
  final VoidCallback? onAction;

  const DisconnectedOverlay({
    super.key,
    required this.featureName,
    required this.actionLabel,
    this.onAction,
  });

  @override
  State<DisconnectedOverlay> createState() => _DisconnectedOverlayState();
}

class _DisconnectedOverlayState extends State<DisconnectedOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Pulsating Lock Icon
            ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: TetherColors.surfaceElevated,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: TetherColors.borderSubtle,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: TetherColors.accentPrimary.withAlpha(20),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.lock_outline_rounded,
                  size: 32,
                  color: TetherColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // "Not Connected" Header
            const Text(
              'Connection Required',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: TetherColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),

            // Feature lock subtext
            Text(
              'Connect a device to access ${widget.featureName}.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: TetherColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),

            // Action Button (e.g. Scan QR, Go to Settings)
            if (widget.onAction != null)
              TetherButton(
                label: widget.actionLabel,
                icon: Icons.link,
                variant: TetherButtonVariant.ghost,
                onPressed: widget.onAction,
              ),
          ],
        ),
      ),
    );
  }
}
