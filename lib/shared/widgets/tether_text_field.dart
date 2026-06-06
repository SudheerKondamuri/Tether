import 'package:flutter/material.dart';
import 'package:tether/shared/theme.dart';

/// Styled text field with Tether design language.
class TetherTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? hint;
  final String? label;
  final ValueChanged<String>? onSubmitted;
  final bool obscureText;
  final bool isMonospace;
  final int maxLines;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;

  const TetherTextField({
    super.key,
    this.controller,
    this.hint,
    this.label,
    this.onSubmitted,
    this.obscureText = false,
    this.isMonospace = false,
    this.maxLines = 1,
    this.prefixIcon,
    this.suffixIcon,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: maxLines == 1 ? 40 : null,
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        maxLines: maxLines,
        onSubmitted: onSubmitted,
        onChanged: onChanged,
        style: TextStyle(
          fontFamily: isMonospace ? 'JetBrainsMono' : 'Inter',
          fontSize: isMonospace ? 13 : 14,
          color: TetherColors.textPrimary,
        ),
        cursorColor: TetherColors.accentPrimary,
        decoration: InputDecoration(
          hintText: hint,
          labelText: label,
          prefixIcon: prefixIcon != null
              ? Icon(prefixIcon, size: 18, color: TetherColors.textSecondary)
              : null,
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }
}
