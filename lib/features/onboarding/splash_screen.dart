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
    final screenSize = MediaQuery.sizeOf(context);
    // Scales the logo puck to the screen instead of a fixed 180px, so it
    // stays proportionate on small phones and large tablets alike.
    final logoSize = (screenSize.shortestSide * 0.40).clamp(120.0, 190.0);

    return Scaffold(
      // Matches the backdrop gradient's top color, so there's no flash of a
      // different color on the very first frame before it paints.
      backgroundColor: const Color(0xFFFCE8C8),
      body: Stack(
        children: [
          // Calm, static gold-gradient backdrop with a faint street-grid
          // texture - see splash_illustration.dart for why this replaced
          // the previous live Google Map background.
          const Positioned.fill(child: SplashBackdrop()),

          // Main content - kept inside SafeArea so nothing sits under a
          // notch/Dynamic Island (iOS) or a status/navigation bar (Android).
          // Everything here renders at full opacity/size from the very
          // first frame - no entrance animation - the loading spinner near
          // the bottom is the only thing that moves on this screen.
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const Spacer(flex: 3),

                  // Logo - unchanged design/colors/asset, just re-centered
                  // in the new layout.
                  Container(
                    width: logoSize,
                    height: logoSize,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 24,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset('assets/images/logo_splash.png'),
                    ),
                  ),
                  const SizedBox(height: 22),

                  const Column(
                    children: [
                      Text(
                        'الهدهد',
                        style: TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.w900,
                          color: AppColors.darkText,
                          fontFamily: 'Cairo',
                          letterSpacing: 1.5,
                        ),
                      ),
                      SizedBox(height: 10),
                      SplashDivider(),
                      SizedBox(height: 10),
                      Text(
                        'نقلك أسهل، أسرع، وأكثر أمانًا',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.darkText,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ],
                  ),

                  const Spacer(flex: 3),

                  // The winding-road-with-a-car motif - a fixed illustration,
                  // sitting just above the loading indicator.
                  const SplashRoadCar(),
                  const SizedBox(height: 18),

                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 30,
                        height: 30,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFF0B3D3A),
                          ),
                          strokeWidth: 3,
                          backgroundColor: Color(0x330B3D3A),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'جاري فتح تطبيق',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.darkText.withOpacity(0.85),
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: MediaQuery.paddingOf(context).bottom + 40),
                ],
              ),
            ),
          ),

          // Purely decorative footer band, drawn last so it sits above the
          // backdrop but behind nothing else - the content column above
          // already reserves enough bottom padding to clear it.
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SplashBottomWave(),
          ),
        ],
      ),
    );
  }
}
