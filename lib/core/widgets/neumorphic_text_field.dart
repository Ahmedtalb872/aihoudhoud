import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/colors.dart';

/// A [TextField] sitting inside a soft "pressed into the surface" container
/// - the same neumorphic treatment as [OtpCodeInput], just full-width for a
/// single field (phone number, password, ...) instead of one box per digit.
class NeumorphicTextField extends StatelessWidget {
  final TextEditingController controller;
  final String? hintText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextAlign textAlign;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final ValueChanged<String>? onSubmitted;
  final TextStyle? style;
  final List<TextInputFormatter>? inputFormatters;

  const NeumorphicTextField({
    super.key,
    required this.controller,
    this.hintText,
    this.obscureText = false,
    this.keyboardType,
    this.textAlign = TextAlign.right,
    this.prefixIcon,
    this.suffixIcon,
    this.onSubmitted,
    this.style,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.white, offset: Offset(-4, -4), blurRadius: 8),
          BoxShadow(
            color: Color(0x2B000000),
            offset: Offset(4, 4),
            blurRadius: 10,
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        textAlign: textAlign,
        onSubmitted: onSubmitted,
        inputFormatters: inputFormatters,
        style:
            style ??
            const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.darkText,
              fontFamily: 'El Messiri',
            ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(
            color: AppColors.secondaryText,
            fontFamily: 'El Messiri',
            fontWeight: FontWeight.normal,
          ),
          // Without this, Flutter reserves its default ~48px-tall box for
          // prefixIcon regardless of how small its actual content is,
          // pinning a short prefix like "+222" to the top of that box
          // instead of centering it next to the input text - visible as
          // the prefix floating noticeably above the typed/hint number.
          prefixIconConstraints: const BoxConstraints(minWidth: 0),
          prefixIcon: prefixIcon,
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 16,
          ),
        ),
      ),
    );
  }
}
