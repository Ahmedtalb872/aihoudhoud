import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/supabase/auth_exception.dart';
import '../../core/supabase/auth_repository.dart';
import '../../core/services/whatsapp_support.dart';
import '../../providers/app_state_provider.dart';
import '../captain/captain_home_screen.dart';
import 'permissions_screen.dart';
import 'splash_screen.dart';

/// Shown after registration (and on every login) while a captain's account
/// is not yet approved by an admin. There is deliberately no way to skip
/// past this screen into the app - only a status refresh, a WhatsApp
/// contact button for delays, and logout. Approval happens by an admin
/// flipping `profiles.is_approved` from the Supabase Table Editor.
class PendingReviewScreen extends StatefulWidget {
  final String? uploadWarning;
  const PendingReviewScreen({super.key, this.uploadWarning});

  @override
  State<PendingReviewScreen> createState() => _PendingReviewScreenState();
}

class _PendingReviewScreenState extends State<PendingReviewScreen> {
  final _authRepository = AuthRepository();
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    if (widget.uploadWarning != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.uploadWarning!,
              style: const TextStyle(fontFamily: 'Cairo'),
            ),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 5),
          ),
        );
      });
    }
  }

  Future<void> _checkStatus() async {
    setState(() => _isChecking = true);
    try {
      final userId = _authRepository.currentUser?.id;
      if (userId == null) return;
      final captain = await _authRepository.getCaptain(userId);
      final approved = captain['status'] == 'approved';

      if (!mounted) return;
      if (approved) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) =>
                const PermissionsScreen(destination: CaptainHomeScreen()),
          ),
          (route) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'لا يزال طلبك قيد المراجعة، حاول مرة أخرى لاحقًا.',
              style: TextStyle(fontFamily: 'Cairo'),
            ),
          ),
        );
      }
    } on AppAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message, style: const TextStyle(fontFamily: 'Cairo')),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  Future<void> _logout() async {
    await _authRepository.signOut();
    if (!mounted) return;
    Provider.of<AppStateProvider>(context, listen: false).logout();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const SplashScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.hourglass_top_rounded,
                  color: AppColors.warning,
                  size: 72,
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'جاري تأكد من حسابك',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkText,
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'فريقنا يراجع بياناتك ومستنداتك الآن. ستتمكن من الدخول للتطبيق فور تفعيل حسابك من الإدارة.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.secondaryText,
                  fontFamily: 'Cairo',
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _isChecking ? null : _checkStatus,
                icon: _isChecking
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.refresh_rounded),
                label: const Text('تحديث الحالة'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => WhatsAppSupport.contactSupport(
                  message: 'السلام عليكم، تأخر تفعيل حساب الكابتن الخاص بي.',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF25D366),
                  side: const BorderSide(color: Color(0xFF25D366)),
                ),
                icon: const Icon(Icons.chat_rounded),
                label: const Text('تأخر التفعيل؟ تواصل معنا على واتساب'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _logout,
                child: const Text('تسجيل الخروج'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
