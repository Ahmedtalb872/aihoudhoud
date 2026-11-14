import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/supabase/auth_repository.dart';
import '../../providers/app_state_provider.dart';
import '../captain/captain_home_screen.dart';
import 'auth_choice_screen.dart';
import 'pending_review_screen.dart';

/// Opening sequence: a small "T" badge (for "Trend Ride") scales in, holds,
/// then fades out - after a beat of empty screen, the full "Trend Ride
/// Captain" wordmark fades in and types itself out letter by letter. Once
/// that's finished and held for a moment, the app resumes the captain's
/// session (or sends them to the login/sign-up choice if there isn't one).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // Badge: scales/fades in immediately, then fades out as the wordmark
  // takes over.
  late final Animation<double> _badgeScale;
  late final Animation<double> _badgeOpacity;

  // Wordmark: fades/slides in once the badge has had a moment to register,
  // then its letters are revealed one at a time (see _wordmarkCharProgress)
  // for a "being typed" effect instead of the whole name popping in at once.
  late final Animation<double> _wordmarkOpacity;
  late final Animation<Offset> _wordmarkSlide;
  late final Animation<double> _wordmarkCharProgress;

  @override
  void initState() {
    super.initState();
    // Four clearly separated phases instead of a crossfade - the badge
    // fully finishes and disappears, THEN (after a beat of empty screen)
    // the wordmark starts, so the two never visually overlap:
    //   0 - 650ms    badge bounces in
    //   650 - 1050ms badge holds, fully visible
    //   1050 - 1450ms badge fades out
    //   1450 - 1750ms empty gap
    //   1750ms - end  wordmark fades in, typed out letter by letter
    const totalMs = 2800;
    const badgeBounceMs = 650;
    const badgeHoldMs = 400;
    const badgeFadeMs = 400;
    const gapMs = 300;
    const wordmarkStartMs = badgeBounceMs + badgeHoldMs + badgeFadeMs + gapMs;

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: totalMs),
    )..forward();

    _badgeScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.4,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.elasticOut)),
        weight: badgeBounceMs.toDouble(),
      ),
      TweenSequenceItem(
        tween: ConstantTween(1.0),
        weight: badgeHoldMs.toDouble(),
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.7,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: badgeFadeMs.toDouble(),
      ),
      TweenSequenceItem(
        tween: ConstantTween(0.7),
        weight: (totalMs - badgeBounceMs - badgeHoldMs - badgeFadeMs)
            .toDouble(),
      ),
    ]).animate(_controller);

    _badgeOpacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: ConstantTween(1.0),
        weight: (badgeBounceMs + badgeHoldMs).toDouble(),
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: badgeFadeMs.toDouble(),
      ),
      TweenSequenceItem(
        tween: ConstantTween(0.0),
        weight: (totalMs - badgeBounceMs - badgeHoldMs - badgeFadeMs)
            .toDouble(),
      ),
    ]).animate(_controller);

    // Fast fade-in for the wordmark's container (so it doesn't just pop in
    // before the first letter is typed), independent of _wordmarkCharProgress
    // below, which handles the actual letter-by-letter reveal. Starts only
    // once the badge is fully gone and the gap has passed.
    _wordmarkOpacity = CurvedAnimation(
      parent: _controller,
      curve: Interval(
        wordmarkStartMs / totalMs,
        (wordmarkStartMs + 200) / totalMs,
        curve: Curves.easeOut,
      ),
    );
    _wordmarkSlide =
        Tween<Offset>(
          begin: const Offset(0, 0.15),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: _controller,
            curve: Interval(
              wordmarkStartMs / totalMs,
              (wordmarkStartMs + 280) / totalMs,
              curve: Curves.easeOutCubic,
            ),
          ),
        );
    // Linear so each letter of the name takes roughly the same amount of
    // time to appear, like it's being typed rather than wiped on unevenly.
    _wordmarkCharProgress = CurvedAnimation(
      parent: _controller,
      curve: Interval(
        wordmarkStartMs / totalMs,
        1.0,
        curve: Curves.linear,
      ),
    );

    // Holds on the fully-revealed wordmark for a beat before moving on, so
    // the name is actually readable rather than vanishing the instant the
    // entrance animation ends.
    Timer(const Duration(milliseconds: totalMs + 900), _resumeSessionOrLogin);
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
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Stage 1: the "T" badge - scales in with a little bounce,
                // then fades away as the wordmark takes over.
                Opacity(
                  opacity: _badgeOpacity.value,
                  child: Transform.scale(
                    scale: _badgeScale.value,
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'T',
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                          fontFamily: 'El Messiri',
                        ),
                      ),
                    ),
                  ),
                ),

                // Stage 2: the full wordmark, typed out letter by letter.
                Opacity(
                  opacity: _wordmarkOpacity.value,
                  child: SlideTransition(
                    position: _wordmarkSlide,
                    child: Builder(
                      builder: (context) {
                        const fullText = 'Trend Ride Driver';
                        final visibleCount =
                            (_wordmarkCharProgress.value * fullText.length)
                                .ceil()
                                .clamp(0, fullText.length)
                                .toInt();
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            fullText.substring(0, visibleCount),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'El Messiri',
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: AppColors.primary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
