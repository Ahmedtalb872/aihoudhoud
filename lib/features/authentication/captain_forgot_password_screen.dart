import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../../core/supabase/auth_exception.dart';
import '../../core/supabase/auth_repository.dart';
import '../../core/widgets/neumorphic_button.dart';
import '../../core/widgets/neumorphic_icon_badge.dart';
import '../../core/widgets/neumorphic_text_field.dart';
import '../../core/widgets/otp_code_input.dart';

/// Lets a captain who forgot their password prove ownership of their phone
/// via a one-time SMS code, then set a new password. Three steps: enter
/// phone -> enter code + new password -> confirmation.
///
/// Styled as a soft-UI / neumorphic card (light surface, inset fields,
/// raised icon badge and button) to match the rest of the authentication
/// flow's updated look.
class CaptainForgotPasswordScreen extends StatefulWidget {
  const CaptainForgotPasswordScreen({super.key});

  @override
  State<CaptainForgotPasswordScreen> createState() =>
      _CaptainForgotPasswordScreenState();
}

class _CaptainForgotPasswordScreenState
    extends State<CaptainForgotPasswordScreen> {
  final _authRepository = AuthRepository();
  final _phoneController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _otpKey = GlobalKey<OtpCodeInputState>();

  int _step = 1; // 1: phone, 2: code + new password, 3: done
  bool _isLoading = false;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorText;
  String _otpCode = '';

  String get _fullPhone => '+222${_phoneController.text.trim()}';

  @override
  void dispose() {
    _phoneController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (_phoneController.text.trim().length < 8) {
      setState(() => _errorText = 'الرجاء إدخال رقم هاتف صحيح');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorText = null;
    });
    try {
      await _authRepository.sendPasswordResetOtp(_fullPhone);
      if (!mounted) return;
      setState(() => _step = 2);
    } on AppAuthException catch (e) {
      setState(() => _errorText = e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    if (_otpCode.trim().length < 4) {
      setState(() => _errorText = 'أدخل رمز التحقق كاملاً');
      return;
    }
    if (_newPasswordController.text.length < 6) {
      setState(() => _errorText = 'كلمة المرور يجب أن تكون 6 أحرف على الأقل');
      return;
    }
    if (_newPasswordController.text != _confirmPasswordController.text) {
      setState(() => _errorText = 'كلمتا المرور غير متطابقتين');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorText = null;
    });
    try {
      await _authRepository.resetPasswordWithOtp(
        phone: _fullPhone,
        code: _otpCode.trim(),
        newPassword: _newPasswordController.text,
      );
      if (!mounted) return;
      setState(() => _step = 3);
    } on AppAuthException catch (e) {
      setState(() => _errorText = e.message);
      _otpKey.currentState?.clear();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.darkText,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 8.0),
          // Each step (phone -> code+password -> success) fades and slides
          // in as its own entrance, instead of the whole form just
          // appearing - the same "things actually move" feel as the
          // reference animation, applied to step transitions since this
          // screen (unlike the splash) has no single fixed sequence to
          // animate once.
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 450),
            transitionBuilder: (child, animation) {
              final slide = Tween<Offset>(
                begin: const Offset(0, 0.08),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(position: slide, child: child),
              );
            },
            child: Column(
              key: ValueKey(_step),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_step == 1) ..._buildStep1(),
                if (_step == 2) ..._buildStep2(),
                if (_step == 3) ..._buildStep3(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildHeader({
    required IconData icon,
    required Color iconColor,
    required String eyebrow,
    required String title,
    required String subtitle,
  }) {
    return [
      const SizedBox(height: 8),
      Center(
        child: TweenAnimationBuilder<double>(
          key: ValueKey(icon),
          tween: Tween(begin: 0.3, end: 1.0),
          duration: const Duration(milliseconds: 650),
          curve: Curves.elasticOut,
          builder: (context, scale, child) =>
              Transform.scale(scale: scale, child: child),
          child: NeumorphicIconBadge(icon: icon, color: iconColor),
        ),
      ),
      const SizedBox(height: 24),
      Text(
        eyebrow,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: AppColors.primaryDark,
          fontFamily: 'Cairo',
        ),
      ),
      const SizedBox(height: 6),
      Text(
        title,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.bold,
          color: AppColors.darkText,
          fontFamily: 'Cairo',
        ),
      ),
      const SizedBox(height: 8),
      Text(
        subtitle,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 13,
          color: AppColors.secondaryText,
          fontFamily: 'Cairo',
          height: 1.5,
        ),
      ),
      const SizedBox(height: 28),
    ];
  }

  List<Widget> _buildStep1() {
    return [
      ..._buildHeader(
        icon: Icons.lock_reset_rounded,
        iconColor: AppColors.primary,
        eyebrow: 'استعادة الحساب',
        title: 'نسيت كلمة المرور؟',
        subtitle: 'أدخل رقم هاتفك المسجّل ككابتن، سنرسل لك رمز تحقق عبر رسالة نصية.',
      ),
      NeumorphicTextField(
        controller: _phoneController,
        keyboardType: TextInputType.phone,
        textAlign: TextAlign.left,
        hintText: '2XXXXXXXX',
        onSubmitted: (_) => _sendCode(),
        prefixIcon: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            '+222',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.bold,
              color: AppColors.darkText,
            ),
          ),
        ),
      ),
      if (_errorText != null) ..._buildError(),
      const SizedBox(height: 24),
      NeumorphicButton(
        label: 'إرسال رمز التحقق',
        isLoading: _isLoading,
        onPressed: _isLoading ? null : _sendCode,
      ),
      const SizedBox(height: 16),
    ];
  }

  List<Widget> _buildStep2() {
    return [
      ..._buildHeader(
        icon: Icons.verified_user_rounded,
        iconColor: AppColors.primary,
        eyebrow: 'التحقق من الهوية',
        title: 'تحقق من هاتفك',
        subtitle: 'أدخل الرمز المرسل إلى $_fullPhone، ثم عيّن كلمة مرور جديدة.',
      ),
      OtpCodeInput(
        key: _otpKey,
        onChanged: (code) => _otpCode = code,
      ),
      const SizedBox(height: 10),
      Center(
        child: TextButton(
          onPressed: _isLoading
              ? null
              : () => setState(() {
                  _step = 1;
                  _errorText = null;
                }),
          child: const Text(
            'لم يصلني الرمز، تغيير الرقم',
            style: TextStyle(fontFamily: 'Cairo', fontSize: 12),
          ),
        ),
      ),
      const SizedBox(height: 12),
      const Align(
        alignment: Alignment.centerRight,
        child: Text(
          'كلمة المرور الجديدة',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppColors.darkText,
            fontFamily: 'Cairo',
          ),
        ),
      ),
      const SizedBox(height: 8),
      NeumorphicTextField(
        controller: _newPasswordController,
        obscureText: _obscureNewPassword,
        hintText: '6 أحرف على الأقل',
        suffixIcon: IconButton(
          icon: Icon(
            _obscureNewPassword
                ? Icons.visibility_off_rounded
                : Icons.visibility_rounded,
            color: AppColors.secondaryText,
          ),
          onPressed: () =>
              setState(() => _obscureNewPassword = !_obscureNewPassword),
        ),
      ),
      const SizedBox(height: 14),
      const Align(
        alignment: Alignment.centerRight,
        child: Text(
          'تأكيد كلمة المرور',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppColors.darkText,
            fontFamily: 'Cairo',
          ),
        ),
      ),
      const SizedBox(height: 8),
      NeumorphicTextField(
        controller: _confirmPasswordController,
        obscureText: _obscureConfirmPassword,
        suffixIcon: IconButton(
          icon: Icon(
            _obscureConfirmPassword
                ? Icons.visibility_off_rounded
                : Icons.visibility_rounded,
            color: AppColors.secondaryText,
          ),
          onPressed: () => setState(
            () => _obscureConfirmPassword = !_obscureConfirmPassword,
          ),
        ),
      ),
      if (_errorText != null) ..._buildError(),
      const SizedBox(height: 24),
      NeumorphicButton(
        label: 'تحقق وتعيين كلمة المرور',
        isLoading: _isLoading,
        onPressed: _isLoading ? null : _resetPassword,
      ),
      const SizedBox(height: 16),
    ];
  }

  List<Widget> _buildStep3() {
    return [
      ..._buildHeader(
        icon: Icons.check_rounded,
        iconColor: AppColors.success,
        eyebrow: 'تم بنجاح',
        title: 'تم تغيير كلمة المرور',
        subtitle: 'يمكنك الآن تسجيل الدخول برقم هاتفك وكلمة المرور الجديدة.',
      ),
      NeumorphicButton(
        label: 'العودة لتسجيل الدخول',
        onPressed: () => Navigator.of(context).pop(),
      ),
      const SizedBox(height: 16),
    ];
  }

  List<Widget> _buildError() {
    return [
      const SizedBox(height: 10),
      Text(
        _errorText!,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppColors.error,
          fontSize: 12,
          fontFamily: 'Cairo',
        ),
      ),
    ];
  }
}
