import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/supabase/auth_repository.dart';
import '../../providers/app_state_provider.dart';
import '../captain/captain_home_screen.dart';
import 'auth_choice_screen.dart';
import 'pending_review_screen.dart';

/// Opening sequence: the TRENDE logo (icon + wordmark already combined in
/// one mark, unlike the previous brand's separate "H" badge + typed-out
/// name) bounces in, holds for a beat, then the app resumes the captain's
/// session (or sends them to the login/sign-up choice if there isn't one).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;

  @override
  void initState() {
    super.initState();
    //   0 - 650ms    logo bounces in
    //   650ms - end  holds, fully visible, so it's actually readable
    //                rather than the screen moving on the instant the
    //                entrance animation finishes
    const totalMs = 1600;
    const logoBounceMs = 650;

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: totalMs),
    )..forward();

    _logoScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.4,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.elasticOut)),
        weight: logoBounceMs.toDouble(),
      ),
      TweenSequenceItem(
        tween: ConstantTween(1.0),
        weight: (totalMs - logoBounceMs).toDouble(),
      ),
    ]).animate(_controller);

    _logoOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.25, curve: Curves.easeOut),
    );

    Timer(const Duration(milliseconds: totalMs + 500), _resumeSessionOrLogin);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Retries a flaky startup network call instead of treating the very first
  // failure as final - a captain who launches the app during a brief
  // connectivity gap (switching towers, wifi handoff, a few seconds of no
  // signal) used to be bounced straight to the login screen or the
  // "جاري تأكد من حسابك" pending-review screen on the first timeout, even
  // though they're actually a logged-in, approved captain and the network
  // recovers a moment later. 4 attempts with a growing delay comfortably
  // rides out a short gap without making an already-slow cold start feel
  // endless if the network is genuinely down.
  Future<T?> _withRetries<T>(Future<T> Function() call) async {
    for (var attempt = 0; attempt < 4; attempt++) {
      try {
        return await call();
      } catch (_) {
        if (attempt == 3) return null;
        await Future.delayed(Duration(milliseconds: 800 * (attempt + 1)));
      }
    }
    return null;
  }

  Future<void> _resumeSessionOrLogin() async {
    Widget destination = const AuthChoiceScreen();

    final currentUser = AuthRepository().currentUser;
    if (currentUser != null) {
      final profile = await _withRetries(
        () => AuthRepository().getProfile(currentUser.id),
      );
      if (profile != null && profile['role'] == 'captain' && mounted) {
        final captain = await _withRetries(
          () => AuthRepository().getCaptain(currentUser.id),
        );
        // A captain row that couldn't be fetched even after retries (still
        // offline, or a genuine server hiccup) is treated as "unknown", not
        // "not approved" - keeps them on the dashboard they were already
        // approved for rather than wrongly demoting them to pending-review.
        final approved = captain == null || captain['status'] == 'approved';
        if (mounted) {
          final appState = Provider.of<AppStateProvider>(
            context,
            listen: false,
          );
          appState.loginFromProfile(
            profile,
            currentUser.phone ?? '',
            captain: captain,
          );
          // Restores an in-progress trip if the app process was killed
          // mid-trip (e.g. the phone locked/closed) - otherwise the
          // captain would land on the dashboard with no sign it still
          // exists, even though nothing changed on the server.
          if (approved) {
            await appState.restoreActiveTripIfAny();
          }
        }
        destination = approved
            ? const CaptainHomeScreen()
            : const PendingReviewScreen();
      }
      // profile == null after all retries means the network never
      // recovered in time - falls through to the login screen below, the
      // same safe default as before for a genuinely expired/invalid session.
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => destination,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          body: Center(
            child: Opacity(
              opacity: _logoOpacity.value,
              child: Transform.scale(
                scale: _logoScale.value,
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 220,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
