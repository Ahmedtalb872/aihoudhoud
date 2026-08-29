import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';

/// Deep teal pulled from the الهدهد logo's own car/feather shade - used only
/// for this illustration's road, car, and footer band. Not added to the
/// shared AppColors palette since nothing else in the app uses this exact
/// tone; keeping it scoped here avoids widening the app's design system for
/// a single decorative screen.
const Color _kDeepTeal = Color(0xFF0B3D3A);

/// Soft full-screen backdrop for the splash screen: a warm gold-to-cream
/// gradient with a faint street-grid texture, calm enough to sit behind the
/// logo without competing with it. Replaces the previous live Google Map
/// background - a splash screen shouldn't depend on a network-fetched map
/// SDK just to render a decorative backdrop.
class SplashBackdrop extends StatelessWidget {
  const SplashBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFCE8C8), Color(0xFFF5CE85)],
        ),
      ),
      child: CustomPaint(painter: _GridPainter(), size: Size.infinite),
    );
  }
}

/// A faint diamond street-grid - two families of parallel lines crossing at
/// an angle, well below full opacity so it reads as texture, not content.
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.22)
      ..strokeWidth = 1.2;
    const step = 42.0;
    final diagonal = size.width + size.height;

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(math.pi / 7);
    for (double x = -diagonal; x < diagonal; x += step) {
      canvas.drawLine(
        Offset(x, -diagonal),
        Offset(x, diagonal),
        paint,
      );
    }
    canvas.restore();

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(-math.pi / 9);
    for (double y = -diagonal; y < diagonal; y += step) {
      canvas.drawLine(
        Offset(-diagonal, y),
        Offset(diagonal, y),
        paint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) => false;
}

/// Small ornamental divider - a short line, a diamond, a short line - placed
/// between the app name and the tagline.
class SplashDivider extends StatelessWidget {
  const SplashDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 28, height: 1.2, color: _kDeepTeal.withOpacity(0.35)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Transform.rotate(
            angle: math.pi / 4,
            child: Container(
              width: 6,
              height: 6,
              color: AppColors.primaryDark,
            ),
          ),
        ),
        Container(width: 28, height: 1.2, color: _kDeepTeal.withOpacity(0.35)),
      ],
    );
  }
}

/// A gentle winding road with a small car fixed on it - the "نقل" (transit)
/// motif from the reference design, drawn rather than a live map so it
/// renders instantly with no network/SDK dependency. Intentionally static
/// (no animation controller): the splash screen should have nothing moving
/// on it besides the loading spinner.
class SplashRoadCar extends StatelessWidget {
  const SplashRoadCar({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: double.infinity,
      height: 96,
      child: CustomPaint(
        size: Size.infinite,
        painter: _RoadPainter(progress: 0.55),
      ),
    );
  }
}

class _RoadPainter extends CustomPainter {
  final double progress;
  const _RoadPainter({required this.progress});

  Path _roadPath(Size size) {
    final path = Path()..moveTo(size.width * 0.04, size.height * 0.30);
    path.cubicTo(
      size.width * 0.28,
      size.height * 0.02,
      size.width * 0.40,
      size.height * 0.85,
      size.width * 0.66,
      size.height * 0.50,
    );
    path.cubicTo(
      size.width * 0.80,
      size.height * 0.28,
      size.width * 0.88,
      size.height * 0.62,
      size.width * 0.97,
      size.height * 0.42,
    );
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = _roadPath(size);
    final metric = path.computeMetrics().first;

    // Soft shadow, then the road surface itself.
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black.withOpacity(0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 18
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withOpacity(0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round,
    );

    // Dashed center line.
    double distance = 0;
    const dash = 9.0, gap = 7.0;
    final dashPaint = Paint()
      ..color = _kDeepTeal.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    while (distance < metric.length) {
      final next = math.min(distance + dash, metric.length);
      canvas.drawPath(metric.extractPath(distance, next), dashPaint);
      distance += dash + gap;
    }

    // Car following the curve, rotated to match its heading there.
    final tangent = metric.getTangentForOffset(metric.length * progress);
    if (tangent != null) {
      canvas.save();
      canvas.translate(tangent.position.dx, tangent.position.dy);
      canvas.rotate(tangent.angle);
      _drawCar(canvas);
      canvas.restore();
    }
  }

  void _drawCar(Canvas canvas) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-17, -7, 34, 14),
        const Radius.circular(6),
      ),
      Paint()..color = _kDeepTeal,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-7, -13, 17, 9),
        const Radius.circular(4),
      ),
      Paint()..color = _kDeepTeal.withOpacity(0.92),
    );
    canvas.drawCircle(
      const Offset(15, 0),
      2.6,
      Paint()..color = AppColors.primary,
    );
  }

  @override
  bool shouldRepaint(covariant _RoadPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Decorative dark-teal wave pinned to the very bottom of the screen -
/// purely a footer accent, sits behind the loading indicator/text above it.
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
