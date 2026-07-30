import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/supabase/auth_exception.dart';
import '../../core/supabase/auth_repository.dart';
import '../../core/widgets/app_logo.dart';
import '../../providers/app_state_provider.dart';
import 'captain_register_stepper_screen.dart';
import '../captain/captain_home_screen.dart';
import '../onboarding/pending_review_screen.dart';
import '../onboarding/permissions_screen.dart';

/// Captain login by phone number + SMS one-time code (no email/password).
class CaptainLoginScreen extends StatefulWidget {
  const CaptainLoginScreen({super.key});

  @override
  State<CaptainLoginScreen> createState() => _CaptainLoginScreenState();
}

class _CaptainLoginScreenState extends State<CaptainLoginScreen> {
  final _authRepository = AuthRepository();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();

  // 1 = enter phone, 2 = enter the SMS code sent to it.
  int _step = 1;
  bool _isLoading = false;
  String? _errorText;

  String get _fullPhone => '+222${_phoneController.text.trim()}';

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final phone = _phoneController.text.trim();
    if (phone.length < 8) {
      setState(() => _errorText = 'الرجاء إدخال رقم هاتف صحيح');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });
    try {
      await _authRepository.sendPhoneOtp(phone: _fullPhone);
      if (!mounted) return;
      setState(() => _step = 2);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم إرسال رمز التحقق عبر رسالة نصية.',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } on AppAuthException catch (e) {
      setState(() => _errorText = e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyCode() async {
    if (_codeController.text.trim().length < 4) {
      setState(() => _errorText = 'الرجاء إدخال رمز التحقق كاملاً');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });
    try {
      final profile = await _authRepository.verifyPhoneOtp(
        phone: _fullPhone,
        code: _codeController.text.trim(),
      );

      if (profile['role'] != 'captain') {
        await _authRepository.signOut();
        throw AppAuthException(
          'هذا الحساب غير مسجل ككابتن. الرجاء استخدام تطبيق الزبائن لتسجيل الدخول.',
        );
      }

      if (!mounted) return;
      final provider = Provider.of<AppStateProvider>(context, listen: false);
      provider.loginFromProfile(profile, _fullPhone);

      final approved = profile['is_approved'] as bool? ?? false;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => approved
              ? const PermissionsScreen(destination: CaptainHomeScreen())
              : const PendingReviewScreen(),
        ),
        (route) => false,
      );
    } on AppAuthException catch (e) {
      setState(() => _errorText = e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (_step == 2) {
              setState(() {
                _step = 1;
                _errorText = null;
              });
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
        title: const Text('تسجيل دخول الكابتن'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              const Center(child: AppLogo(width: 96)),
              const SizedBox(height: 20),
              Text(
                _step == 1 ? 'أهلاً بك يا كابتن!' : 'أدخل رمز التحقق',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkText,
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _step == 1
                    ? 'سجل دخولك برقم هاتفك لبدء استقبال طلبات الركاب وتحقيق أرباح يومية.'
                    : 'أرسلنا رمزًا مكوّنًا من عدة أرقام برسالة نصية إلى $_fullPhone',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.secondaryText,
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 32),

              if (_step == 1) ...[
                const Text(
                  'رقم الهاتف',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkText,
                    fontFamily: 'Cairo',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  textAlign: TextAlign.left,
                  decoration: const InputDecoration(
                    hintText: '2XXXXXXXX',
                    prefixIcon: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        '+222',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkText,
                        ),
                      ),
                    ),
                    prefixIconConstraints: BoxConstraints(minWidth: 0),
                  ),
                ),
              ] else ...[
                const Text(
                  'رمز التحقق',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkText,
                    fontFamily: 'Cairo',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    letterSpacing: 8,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: const InputDecoration(hintText: '- - - - - -'),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: _isLoading ? null : _sendCode,
                    child: const Text('إعادة إرسال الرمز'),
                  ),
                ),
              ],

              if (_errorText != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorText!,
                  style: const TextStyle(
                    color: AppColors.error,
                    fontSize: 13,
                    fontFamily: 'Cairo',
                  ),
                ),
              ],
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : (_step == 1 ? _sendCode : _verifyCode),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: AppColors.darkText,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Text(_step == 1 ? 'إرسال رمز التحقق' : 'تسجيل الدخول ككابتن'),
              ),
              const SizedBox(height: 24),

              if (_step == 1)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'تريد الانضمام ككابتن؟',
                      style: TextStyle(
                        color: AppColors.secondaryText,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) =>
                                const CaptainRegisterStepperScreen(),
                          ),
                        );
                      },
                      child: const Text('سجل الآن ككابتن جديد'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
