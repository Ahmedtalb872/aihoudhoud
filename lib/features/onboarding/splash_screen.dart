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

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _scaleAnimation = Tween<double>(
      begin: 0.6,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    _controller.forward();

    Timer(const Duration(milliseconds: 2800), _resumeSessionOrLogin);
  }

  Future<void> _resumeSessionOrLogin() async {
    Widget destination = const AuthChoiceScreen();

    final currentUser = AuthRepository().currentUser;
    if (currentUser != null) {
      try {
        final profile = await AuthRepository().getProfile(currentUser.id);
        if (profile['role'] == 'captain' && mounted) {
          Map<String, dynamic>? captain;
          bool approved = false;
          try {
            captain = await AuthRepository().getCaptain(currentUser.id);
            approved = captain['status'] == 'approved';
          } catch (_) {
            // Fall back to "not approved".
          }
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
      } catch (_) {
        // No usable session/profile; fall back to the login screen.
      }
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
  void dispose() {
    _controller.dispose();
    super.dispose();
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
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const Spacer(flex: 3),

                  // Logo - unchanged design/colors/asset, just re-centered
                  // in the new layout.
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Container(
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
                    ),
                  ),
                  const SizedBox(height: 22),

                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      children: [
                        const Text(
                          'الهدهد',
                          style: TextStyle(
                            fontSize: 38,
                            fontWeight: FontWeight.w900,
                            color: AppColors.darkText,
                            fontFamily: 'Cairo',
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const SplashDivider(),
                        const SizedBox(height: 10),
                        const Text(
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
                  ),

                  const Spacer(flex: 3),

                  // The winding-road-with-a-car motif, sitting just above
                  // the loading indicator.
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: const SplashRoadCar(),
                  ),
                  const SizedBox(height: 18),

                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
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
