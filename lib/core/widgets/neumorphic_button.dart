import 'package:flutter/material.dart';
import '../constants/colors.dart';

/// Full-width pill button with the same soft-UI "raised off the surface"
/// treatment as the rest of the authentication screens, instead of a flat
/// filled [ElevatedButton]. Used for the screens' single primary action
/// (verify code, reset password, resend, ...).
class NeumorphicButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color color;

  const NeumorphicButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null || isLoading;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: disabled ? null : onPressed,
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            color: disabled ? color.withOpacity(0.5) : color,
            borderRadius: BorderRadius.circular(28),
            boxShadow: disabled
                ? const []
                : [
                    BoxShadow(
                      color: color.withOpacity(0.35),
                      offset: const Offset(0, 6),
                      blurRadius: 14,
                    ),
                  ],
          ),
          alignment: Alignment.center,
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: AppColors.darkText,
                    strokeWidth: 2.5,
                  ),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkText,
                    fontFamily: 'El Messiri',
                  ),
                ),
        ),
      ),
    );
  }
}
