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

/// Wraps Supabase Auth (phone number + password, with a one-time SMS code to
/// confirm the phone at sign-up) and the matching `profiles` row created
/// automatically by the `handle_new_user` DB trigger.
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

  /// Creates a new captain account with [phone] + [password], and (if phone
  /// confirmations are enabled in Supabase) sends a 6-digit SMS code that
  /// must be confirmed with [verifySignUpOtp] before the account is usable.
  Future<void> signUpWithPassword({
    required String phone,
    required String password,
    required String fullName,
  }) async {
    _requireConfigured();
    try {
      await _client.auth.signUp(
        phone: phone,
        password: password,
        data: {'full_name': fullName, 'phone': phone, 'role': 'captain'},
      );
    } on AuthException catch (e) {
      throw AppAuthException(_translateAuthError(e));
    }
  }

  /// Confirms the phone number for an account created by
  /// [signUpWithPassword], completing the sign-up.
  Future<Map<String, dynamic>> verifySignUpOtp({
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

  /// Logs an existing captain in with their phone + password. No SMS needed.
  Future<Map<String, dynamic>> signInWithPassword({
    required String phone,
    required String password,
  }) async {
    _requireConfigured();
    try {
      final response = await _client.auth.signInWithPassword(
        phone: phone,
        password: password,
      );
      final user = response.user;
      if (user == null) {
        throw AppAuthException('تعذر تسجيل الدخول.');
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

  /// The `captains` row for [captainId] - created automatically (bare) by
  /// the sign-up trigger. `status` ('pending'/'approved'/'rejected'/
  /// 'suspended') is the real approval gate, separate from
  /// `profiles.is_approved`.
  Future<Map<String, dynamic>> getCaptain(String captainId) async {
    try {
      return await _client
          .from('captains')
          .select()
          .eq('id', captainId)
          .single();
    } on PostgrestException {
      throw AppAuthException('تعذر تحميل بيانات حساب الكابتن.');
    }
  }

  /// Fills in the vehicle/city/address/birth-date details collected during
  /// registration on the bare `captains` row the sign-up trigger created.
  Future<void> updateCaptainVehicleInfo({
    required String captainId,
    required String city,
    required String address,
    required String dateOfBirth,
    required String vehicleCategory,
    required String vehicleType,
    required String vehicleBrand,
    required String vehicleModel,
    required int vehicleYear,
    required String vehicleColor,
    required String vehiclePlate,
    required int vehicleSeats,
  }) async {
    try {
      await _client
          .from('captains')
          .update({
            'city': city,
            'address': address,
            'date_of_birth': dateOfBirth,
            'vehicle_category': vehicleCategory,
            'vehicle_type': vehicleType,
            'vehicle_brand': vehicleBrand,
            'vehicle_model': vehicleModel,
            'vehicle_year': vehicleYear,
            'vehicle_color': vehicleColor,
            'vehicle_plate': vehiclePlate,
            'vehicle_seats': vehicleSeats,
          })
          .eq('id', captainId);
    } on PostgrestException {
      throw AppAuthException('تعذر حفظ بيانات السيارة.');
    }
  }

  Future<void> setCaptainOnline(String captainId, bool isOnline) async {
    try {
      await _client
          .from('captains')
          .update({'is_online': isOnline})
          .eq('id', captainId);
    } catch (_) {
      // Best-effort - local online state still works even if this fails.
    }
  }

  /// Motorcycle captains can opt in/out of receiving delivery requests
  /// alongside their normal passenger requests.
  Future<void> setDeliveryModeEnabled(String captainId, bool enabled) async {
    try {
      await _client
          .from('captains')
          .update({'delivery_mode_enabled': enabled})
          .eq('id', captainId);
    } catch (_) {
      // Best-effort - local toggle state still works even if this fails.
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
    if (msg.contains('invalid login credentials')) {
      return 'رقم الهاتف أو كلمة المرور غير صحيحة.';
    }
    if (msg.contains('user already registered') ||
        msg.contains('already been registered')) {
      return 'هذا الرقم مسجل بالفعل. سجل الدخول بدلاً من إنشاء حساب جديد.';
    }
    if (msg.contains('password') && msg.contains('at least')) {
      return 'كلمة المرور قصيرة جدًا، استخدم 6 أحرف على الأقل.';
    }
    return e.message;
  }
}
