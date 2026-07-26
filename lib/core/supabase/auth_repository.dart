import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_exception.dart';
import 'supabase_config.dart';

/// One captain verification document picked on-device, ready to upload.
class CaptainDocumentFile {
  final String docKey;
  final String docName;
  final Uint8List bytes;
  const CaptainDocumentFile({
    required this.docKey,
    required this.docName,
    required this.bytes,
  });
}

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
    required String role, // 'customer' or 'captain'
  }) async {
    _requireConfigured();
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName, 'phone': phone, 'role': role},
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

  /// Uploads each picked document to the private `captain-documents` bucket
  /// (under a path prefixed with [captainId], matching its storage RLS
  /// policy) and records it in `captain_documents` for admin review.
  Future<void> uploadCaptainDocuments(
    String captainId,
    List<CaptainDocumentFile> documents,
  ) async {
    _requireConfigured();
    try {
      for (final doc in documents) {
        final path = '$captainId/${doc.docKey}.jpg';
        await _client.storage
            .from('captain-documents')
            .uploadBinary(
              path,
              doc.bytes,
              fileOptions: const FileOptions(
                upsert: true,
                contentType: 'image/jpeg',
              ),
            );

        await _client.from('captain_documents').upsert(
          {
            'captain_id': captainId,
            'doc_key': doc.docKey,
            'doc_name': doc.docName,
            'file_path': path,
            'status': 'under_review',
          },
          onConflict: 'captain_id,doc_key',
        );
      }
    } catch (_) {
      throw AppAuthException(
        'تم إنشاء حسابك، لكن تعذر رفع بعض المستندات. يمكنك رفعها لاحقًا من صفحة حسابك.',
      );
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
