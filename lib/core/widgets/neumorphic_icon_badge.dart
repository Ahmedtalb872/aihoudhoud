import 'package:flutter/material.dart';
import '../constants/colors.dart';

/// A large circular "soft UI" icon badge - raised off the background with a
/// light highlight and a soft shadow, the way the lock/checkmark icon sits
/// on the authentication screens. [color] tints the icon itself; the badge
/// surface always matches the page background so it reads as sculpted from
/// the same surface rather than a flat colored chip.
class NeumorphicIconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const NeumorphicIconBadge({
    super.key,
    required this.icon,
    this.color = AppColors.primary,
    this.size = 96,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppColors.background,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.white,
            offset: Offset(-8, -8),
            blurRadius: 16,
          ),
          BoxShadow(
            color: Color(0x33000000),
            offset: Offset(8, 8),
            blurRadius: 20,
          ),
        ],
      ),
      child: Center(
        child: Icon(icon, size: size * 0.42, color: color),
      ),
    );
  }
}
