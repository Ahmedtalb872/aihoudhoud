import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/supabase/auth_repository.dart';
import '../../providers/app_state_provider.dart';
import '../captain/captain_home_screen.dart';
import 'auth_choice_screen.dart';
import 'pending_review_screen.dart';
import 'widgets/splash_illustration.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Long enough to actually read the name/tagline before it moves on -
    // was 2800ms, felt rushed with no entrance animation to fill that time.
    Timer(const Duration(milliseconds: 4500), _resumeSessionOrLogin);
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
    return Scaffold(
      // Matches splash_hero.png's own background tone, so there's no flash
      // of a different color on the first frame before the image decodes.
      backgroundColor: const Color(0xFFFCE8C8),
      body: Stack(
        children: [
          // The reference artwork itself (logo, name, tagline, road+car,
          // map-grid backdrop) cropped to exclude its baked-in status bar
          // and its baked-in loading spinner/caption - those two are
          // replaced below with the real status bar and a genuinely
          // animated indicator instead of a static picture of one.
          //
          // BoxFit.cover here used to zoom the art to fill the full device
          // height - since the crop already removed a chunk of the original
          // canvas (status bar + footer), covering the *same* screen height
          // with that shorter image needs more zoom than the reference
          // photo ever had, making the logo/name look oversized compared to
          // it. fitWidth scales by width only (matching the reference's own
          // proportions) and just leaves the Scaffold's background - the
          // same beige as the art's own background - showing below it,
          // which the bottom wave then covers anyway.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Image.asset(
              'assets/images/splash_hero.png',
              fit: BoxFit.fitWidth,
              alignment: Alignment.topCenter,
            ),
          ),

          // Real dark-teal footer band + live loading indicator, sitting
          // where the artwork's own (now-cropped-out) spinner used to be -
          // the only thing that actually moves on this screen.
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SplashBottomWave(height: 70),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: MediaQuery.paddingOf(context).bottom + 18,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                    strokeWidth: 3,
                    backgroundColor: Color(0x330B3D3A),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'جاري فتح تطبيق',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontFamily: 'Cairo',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
