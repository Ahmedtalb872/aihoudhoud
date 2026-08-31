import 'package:flutter/material.dart';

/// Deep teal pulled from the الهدهد logo's own car/feather shade - matches
/// splash_hero.png's own footer band color exactly, so this live wave reads
/// as a continuation of that artwork rather than a visibly different color.
const Color _kDeepTeal = Color(0xFF0B3D3A);

/// Decorative dark-teal wave pinned to the very bottom of the splash
/// screen, behind the real (animated) loading indicator - splash_hero.png
/// is cropped to exclude its own baked-in version of this band so the two
/// don't overlap or mismatch.
class SplashBottomWave extends StatelessWidget {
  final double height;
  const SplashBottomWave({super.key, this.height = 56});

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _WaveClipper(),
      child: Container(height: height, color: _kDeepTeal),
    );
  }
}

class _WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..lineTo(0, size.height * 0.45)
      ..quadraticBezierTo(
        size.width * 0.25,
        0,
        size.width * 0.5,
        size.height * 0.28,
      )
      ..quadraticBezierTo(
        size.width * 0.75,
        size.height * 0.55,
        size.width,
        size.height * 0.12,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldDelegate) => false;
}
