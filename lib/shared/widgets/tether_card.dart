import 'package:flutter/material.dart';
import 'package:tether/shared/theme.dart';

/// Elevated card with the Tether design language.
class TetherCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;
  final bool isSelected;

  const TetherCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.borderColor,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final border = isSelected

}}
