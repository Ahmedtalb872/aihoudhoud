import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_exception.dart';
import 'supabase_config.dart';

/// Wraps Supabase Auth (email + password) and the matching `profiles` row
/// created automatically by the `handle_new_user` DB trigger.
class AuthRepository {
  SupabaseClient get _client => SupabaseConfig.client;

  User? get currentUser =>
      SupabaseConfig.isReady ? _client.auth.currentUser : null;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  void _requireConfigured() {
    if (!SupabaseConfig.isReady) {
      throw AppAuthException(
        'لم يتم إعداد الاتصال بالخادم بعد. راجع ملف env.json.example.',
      );
    }
  }

  Future<Map<String, dynamic>> signUp({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required String userType, // 'customer' or 'captain'
  }) async {
    _requireConfigured();
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName, 'phone': phone, 'user_type': userType},
      );

      final user = response.user;
      if (user == null) {
        throw AppAuthException('تعذر إنشاء الحساب، حاول مرة أخرى.');
      }

      return await getProfile(user.id);
    } on AuthException catch (e) {
      throw AppAuthException(_translateAuthError(e));
    }
  }

  Future<Map<String, dynamic>> signIn({
    required String email,
    required String password,
  }) async {
    _requireConfigured();
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = response.user;
      if (user == null) {
        throw AppAuthException('بيانات الدخول غير صحيحة.');
      }

      return await getProfile(user.id);
    } on AuthException catch (e) {
      throw AppAuthException(_translateAuthError(e));
    }
  }

  Future<Map<String, dynamic>> getProfile(String userId) async {
    try {
      return await _client.from('profiles').select().eq('id', userId).single();
    } on PostgrestException {
      throw AppAuthException('تعذر تحميل بيانات الحساب.');
    }
  }

  Future<void> signOut() async {
    if (!SupabaseConfig.isReady) return;
    await _client.auth.signOut();
  }

  Future<void> resetPasswordForEmail(String email) async {
    _requireConfigured();
    try {
      await _client.auth.resetPasswordForEmail(email);
    } on AuthException catch (e) {
      throw AppAuthException(_translateAuthError(e));
    }
  }

  String _translateAuthError(AuthException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('invalid login credentials')) {
      return 'البريد الإلكتروني أو كلمة المرور غير صحيحة.';
    }
    if (msg.contains('already registered') ||
        msg.contains('user already exists')) {
      return 'هذا البريد الإلكتروني مسجل بالفعل، جرّب تسجيل الدخول.';
    }
    if (msg.contains('email not confirmed')) {
      return 'يرجى تأكيد بريدك الإلكتروني أولاً قبل تسجيل الدخول.';
    }
    return e.message;
  }
}
