import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/supabase/auth_repository.dart';
import '../../providers/app_state_provider.dart';
import '../captain/captain_home_screen.dart';
import 'auth_choice_screen.dart';
import 'pending_review_screen.dart';

/// Opening sequence: a small "H" badge (for "Al Hudhud") scales in, then
/// morphs into the full wordmark as the background shifts to the brand
/// gold, then the app resumes the captain's session (or sends them to the
/// login/sign-up choice if there isn't one).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // Badge: scales/fades in immediately, then scales back down as the
  // wordmark takes over.
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
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..forward();

    _badgeScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.4,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 55,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.7,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 45,
      ),
    ]).animate(_controller);

    _badgeOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 65),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 35,
      ),
    ]).animate(_controller);

    // Fast fade-in for the wordmark's container (so it doesn't just pop in
    // before the first letter is typed), independent of _wordmarkCharCount
    // below, which handles the actual letter-by-letter reveal.
    _wordmarkOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.45, 0.6, curve: Curves.easeOut),
    );
    _wordmarkSlide =
        Tween<Offset>(
          begin: const Offset(0, 0.15),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.45, 0.65, curve: Curves.easeOutCubic),
          ),
        );
    // Linear so each letter of the name takes roughly the same amount of
    // time to appear, like it's being typed rather than wiped on unevenly.
    _wordmarkCharProgress = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.45, 1.0, curve: Curves.linear),
    );

    // Holds on the fully-revealed wordmark for a beat before moving on, so
    // the name is actually readable rather than vanishing the instant the
    // entrance animation ends.
    Timer(const Duration(milliseconds: 3500), _resumeSessionOrLogin);
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
                // Stage 1: the "H" badge - scales in with a little bounce,
                // then shrinks away as the wordmark takes over.
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
                        'H',
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ),
                  ),
                ),

                // Stage 2: the full wordmark, revealed once the background
                // has settled into the brand gold. Spelled out in Latin
                // script for French (and any other non-Arabic) locale,
                // matching the app's own "AL HODHOD" icon branding, instead
                // of a word French readers can't pronounce from Arabic
                // script.
                Opacity(
                  opacity: _wordmarkOpacity.value,
                  child: SlideTransition(
                    position: _wordmarkSlide,
                    child: Builder(
                      builder: (context) {
                        final isArabic =
                            Provider.of<AppStateProvider>(
                              context,
                              listen: false,
                            ).locale.languageCode ==
                            'ar';
                        final fullText = isArabic
                            ? 'الهدهد'
                            : 'Al Hodhoud Captain';
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
                            style: TextStyle(
                              fontSize: isArabic ? 42 : 30,
                              fontWeight: FontWeight.w900,
                              color: AppColors.primary,
                              fontFamily: 'Cairo',
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
