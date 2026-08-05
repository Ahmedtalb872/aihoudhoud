import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_exception.dart';
import 'supabase_config.dart';

/// Recharging the wallet is currently a manual-review flow: the captain
/// transfers money to our own account with the chosen provider outside the
/// app, then submits the amount + the transaction reference here for an
/// admin to verify and credit manually - because we don't yet have merchant
/// API access with any of Bankily/Sedad/Click.
///
/// Once we do, only [submitRechargeRequest] needs to change: call the
/// provider's verification API instead of just inserting a pending row, and
/// credit the wallet immediately on a successful response instead of
/// waiting on admin review.
class WalletRepository {
  SupabaseClient get _client => SupabaseConfig.client;

  Future<void> submitRechargeRequest({
    required String bankId,
    required double amount,
    required String transactionReference,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw AppAuthException('يجب تسجيل الدخول أولاً.');
    }
    try {
      await _client.from('wallet_recharge_requests').insert({
        'captain_id': userId,
        'bank': bankId,
        'amount': amount,
        'transaction_reference': transactionReference,
      });
    } on PostgrestException {
      throw AppAuthException('تعذر إرسال طلب الشحن، حاول مرة أخرى.');
    }
  }

  Future<List<Map<String, dynamic>>> getMyRechargeRequests() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];
    try {
      return await _client
          .from('wallet_recharge_requests')
          .select()
          .eq('captain_id', userId)
          .order('created_at', ascending: false);
    } on PostgrestException {
      throw AppAuthException('تعذر تحميل طلبات الشحن.');
    }
  }
}
