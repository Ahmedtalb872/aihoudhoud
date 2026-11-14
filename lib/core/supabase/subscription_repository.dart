import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/models.dart';
import 'auth_exception.dart';
import 'supabase_config.dart';

/// Captain-side half of the monthly subscription negotiation
/// (captain_subscriptions/captain_subscription_messages - see
/// app-driver-customer's 20260812000056/57 migrations and its own
/// CaptainSubscriptionRepository, which this mirrors). Every write still
/// happens through the same SECURITY DEFINER RPCs the customer app calls -
/// this repository does no pricing/eligibility/payout math client-side
/// either.
class SubscriptionRepository {
  SupabaseClient get _client => SupabaseConfig.client;

  static const String _fullJoin = '*, customers(profiles(full_name, phone))';

  CaptainSubscription _rowToSubscription(Map<String, dynamic> row) {
    final customer = row['customers'] as Map<String, dynamic>?;
    final profile = customer?['profiles'] as Map<String, dynamic>?;
    return CaptainSubscription.fromJson({
      'id': row['id'],
      'customer_id': row['customer_id'],
      'customer_name': profile?['full_name'],
      'customer_phone': profile?['phone'],
      'status': row['status'],
      'proposed_price': row['proposed_price'],
      'proposed_by': row['proposed_by'],
      'agreed_price': row['agreed_price'],
      'started_at': row['started_at'],
      'expires_at': row['expires_at'],
      'payout_status': row['payout_status'],
      'renewal_mode': row['renewal_mode'],
      'cycle_count': row['cycle_count'],
      'renewal_window_opened_at': row['renewal_window_opened_at'],
      'customer_confirmed_renewal_at': row['customer_confirmed_renewal_at'],
      'captain_confirmed_renewal_at': row['captain_confirmed_renewal_at'],
      'payment_dispute': row['payment_dispute'],
      'dispute_reason': row['dispute_reason'],
    });
  }

  /// Every subscription thread this captain is party to - unlike a
  /// customer (capped at one relevant thread), a captain may have several
  /// open negotiations and/or an active subscription at once, so this
  /// returns the full list rather than a single "most relevant" row.
  /// Sorted with a pending customer offer first (needs this captain's
  /// response now), then other negotiating threads, then active ones,
  /// then settled/rejected/cancelled - newest first within each group -
  /// so an offer awaiting a response never gets buried under settled
  /// ones. Postgres' own alphabetical ordering of the status text
  /// ('active' < 'cancelled' < 'negotiating' < 'rejected') wouldn't give
  /// this priority, so the sort happens here instead of via `.order()`.
  Future<List<CaptainSubscription>> fetchMySubscriptions() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw AppAuthException('يجب تسجيل الدخول أولاً.');
    try {
      final rows = await _client
          .from('captain_subscriptions')
          .select(_fullJoin)
          .eq('captain_id', uid)
          .order('created_at', ascending: false);
      final subscriptions = (rows as List)
          .cast<Map<String, dynamic>>()
          .map(_rowToSubscription)
          .toList();
      // Grouped (not `List.sort`, which Dart doesn't guarantee is stable)
      // so the created_at-descending order the query already returned
      // within each group survives.
      final groups = List.generate(4, (_) => <CaptainSubscription>[]);
      for (final s in subscriptions) {
        groups[_sortRank(s)].add(s);
      }
      return groups.expand((g) => g).toList();
    } on PostgrestException {
      throw AppAuthException('تعذر تحميل عروض الاشتراك.');
    }
  }

  int _sortRank(CaptainSubscription s) {
    if (s.hasPendingCustomerOffer) return 0;
    if (s.isNegotiating) return 1;
    if (s.isActive) return 2;
    return 3;
  }

  Future<void> sendMessage(
    String subscriptionId,
    String body, {
    double? offerAmount,
  }) async {
    try {
      await _client.rpc(
        'send_subscription_message',
        params: {
          'p_subscription_id': subscriptionId,
          'p_body': body,
          'p_offer_amount': offerAmount,
        },
      );
    } on PostgrestException {
      throw AppAuthException('تعذر إرسال الرسالة.');
    }
  }

  /// Accepts the thread's current proposed price: this is what actually
  /// charges the customer's wallet and activates the subscription (see
  /// captain_accept_subscription) - not reversible from here.
  Future<void> acceptSubscription(String subscriptionId) async {
    try {
      await _client.rpc(
        'captain_accept_subscription',
        params: {'p_subscription_id': subscriptionId},
      );
    } on PostgrestException catch (e) {
      if (e.message.contains('SUBSCRIPTION_INSUFFICIENT_BALANCE')) {
        throw AppAuthException('رصيد الزبون لا يكفي لتغطية قيمة الاشتراك.');
      }
      throw AppAuthException('تعذر قبول العرض.');
    }
  }

  Future<void> rejectSubscription(String subscriptionId) async {
    try {
      await _client.rpc(
        'captain_reject_subscription',
        params: {'p_subscription_id': subscriptionId},
      );
    } on PostgrestException {
      throw AppAuthException('تعذر رفض العرض.');
    }
  }

  /// Ends an already-active subscription early, from the captain's side.
  Future<void> cancelActiveSubscription(String subscriptionId) async {
    try {
      await _client.rpc(
        'captain_cancel_active_subscription',
        params: {'p_subscription_id': subscriptionId},
      );
    } on PostgrestException {
      throw AppAuthException('تعذر إنهاء الاشتراك.');
    }
  }

  /// Trusted-mode renewal: confirms this captain was paid directly by the
  /// customer this cycle. Applies the renewal immediately once the
  /// customer has confirmed too (see
  /// [CaptainSubscription.awaitingCaptainConfirmation]).
  Future<void> confirmRenewalPayment(String subscriptionId) async {
    try {
      await _client.rpc(
        'captain_confirm_subscription_payment',
        params: {'p_subscription_id': subscriptionId},
      );
    } on PostgrestException {
      throw AppAuthException('تعذر تأكيد استلام الدفعة.');
    }
  }

  /// Live messages for a negotiation thread, oldest first.
  Stream<List<SubscriptionMessage>> watchMessages(String subscriptionId) {
    return _client
        .from('captain_subscription_messages')
        .stream(primaryKey: ['id'])
        .eq('subscription_id', subscriptionId)
        .order('created_at')
        .map(
          (rows) => rows
              .cast<Map<String, dynamic>>()
              .map(SubscriptionMessage.fromJson)
              .toList(),
        );
  }

  Future<CaptainSubscription> _fetchSubscription(String subscriptionId) async {
    final row = await _client
        .from('captain_subscriptions')
        .select(_fullJoin)
        .eq('id', subscriptionId)
        .single();
    return _rowToSubscription(row);
  }

  /// Live status for a single thread - lets the chat screen react the
  /// instant a customer sends a new offer, without the captain having to
  /// leave and reopen it.
  Stream<CaptainSubscription?> watchSubscription(String subscriptionId) {
    final controller = StreamController<CaptainSubscription?>.broadcast();
    CaptainSubscription? lastKnown;

    final sub = _client
        .from('captain_subscriptions')
        .stream(primaryKey: ['id'])
        .eq('id', subscriptionId)
        .listen((rows) async {
          if (rows.isEmpty) {
            controller.add(null);
            return;
          }
          try {
            lastKnown = await _fetchSubscription(subscriptionId);
            controller.add(lastKnown);
          } catch (_) {
            controller.add(lastKnown);
          }
        });

    controller.onCancel = () => sub.cancel();
    return controller.stream;
  }
}
