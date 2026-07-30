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

/// Wraps Supabase Auth (phone number + SMS OTP) and the matching `profiles`
/// row created automatically by the `handle_new_user` DB trigger.
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

  /// Sends a 6-digit SMS code to [phone] (e.g. "+22234567890"). Works for
  /// both new registrations and existing-account logins - Supabase creates
  /// the auth user on first verification if one doesn't exist yet, using
  /// [fullName]/[role] as its initial profile metadata.
  Future<void> sendPhoneOtp({
    required String phone,
    String? fullName,
    String? role,
  }) async {
    _requireConfigured();
    try {
      await _client.auth.signInWithOtp(
        phone: phone,
        data: fullName == null && role == null
            ? null
            : {
                if (fullName != null) 'full_name': fullName,
                'phone': phone,
                if (role != null) 'role': role,
              },
      );
    } on AuthException catch (e) {
      throw AppAuthException(_translateAuthError(e));
    }
  }

  /// Verifies the code sent by [sendPhoneOtp], completing sign-up/sign-in.
  Future<Map<String, dynamic>> verifyPhoneOtp({
    required String phone,
    required String code,
  }) async {
    _requireConfigured();
    try {
      final response = await _client.auth.verifyOTP(
        phone: phone,
        token: code,
        type: OtpType.sms,
      );

      final user = response.user;
      if (user == null) {
        throw AppAuthException('رمز التحقق غير صحيح.');
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

  String _translateAuthError(AuthException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('invalid otp') || msg.contains('token has expired')) {
      return 'رمز التحقق غير صحيح أو انتهت صلاحيته، اطلب رمزًا جديدًا.';
    }
    if (msg.contains('sms rate limit') || msg.contains('rate limit')) {
      return 'تم إرسال عدة رموز مؤخرًا، انتظر قليلاً قبل طلب رمز جديد.';
    }
    if (msg.contains('invalid phone')) {
      return 'رقم الهاتف غير صحيح.';
    }
    return e.message;
  }
}
