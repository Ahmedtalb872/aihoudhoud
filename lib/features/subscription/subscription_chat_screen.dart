import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';
import '../../core/supabase/auth_exception.dart';
import '../../core/supabase/subscription_repository.dart';
import '../../models/models.dart';

/// Captain's side of a single "اشتراك شهري" negotiation thread - mirrors
/// the customer app's own SubscriptionChatScreen, but with accept/reject
/// where the customer's screen only ever has "cancel the chat", since only
/// a captain can accept/reject an offer (see captain_accept_subscription/
/// captain_reject_subscription).
class SubscriptionChatScreen extends StatefulWidget {
  final String subscriptionId;
  const SubscriptionChatScreen({super.key, required this.subscriptionId});

  @override
  State<SubscriptionChatScreen> createState() =>
      _SubscriptionChatScreenState();
}

class _SubscriptionChatScreenState extends State<SubscriptionChatScreen> {
  final _repository = SubscriptionRepository();
  final _messageController = TextEditingController();
  final _offerController = TextEditingController();
  final _scrollController = ScrollController();

  StreamSubscription<CaptainSubscription?>? _statusSub;
  StreamSubscription<List<SubscriptionMessage>>? _messagesSub;

  CaptainSubscription? _status;
  List<SubscriptionMessage> _messages = [];
  bool _isSending = false;
  bool _isActing = false;

  @override
  void initState() {
    super.initState();
    _statusSub = _repository
        .watchSubscription(widget.subscriptionId)
        .listen((status) {
          if (mounted) setState(() => _status = status);
        });
    _messagesSub = _repository
        .watchMessages(widget.subscriptionId)
        .listen((messages) {
          if (!mounted) return;
          setState(() => _messages = messages);
          _scrollToBottom();
        });
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    _messagesSub?.cancel();
    _messageController.dispose();
    _offerController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSend() async {
    final body = _messageController.text.trim();
    if (body.isEmpty || _isSending) return;
    setState(() => _isSending = true);
    try {
      await _repository.sendMessage(widget.subscriptionId, body);
      _messageController.clear();
    } on AppAuthException catch (e) {
      _showError(e.message);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _handleSendOffer() async {
    final amount = double.tryParse(_offerController.text.trim());
    if (amount == null || amount <= 0) {
      _showError('أدخل مبلغاً صحيحاً للعرض أولاً.');
      return;
    }
    if (_isSending) return;
    setState(() => _isSending = true);
    try {
      await _repository.sendMessage(
        widget.subscriptionId,
        'أقترح اشتراكاً شهرياً بمبلغ ${amount.toStringAsFixed(0)} أوقية.',
        offerAmount: amount,
      );
      _offerController.clear();
    } on AppAuthException catch (e) {
      _showError(e.message);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _handleAccept() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('قبول العرض', style: TextStyle(fontFamily: 'Cairo')),
        content: Text(
          'سيُخصم المبلغ المتفق عليه (${_status?.proposedPrice?.toStringAsFixed(0) ?? '-'} أوقية) '
          'من محفظة الزبون فوراً، ويصبح الاشتراك نشطاً لمدة 30 يوماً. هل تريد المتابعة؟',
          style: const TextStyle(fontFamily: 'Cairo'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('تراجع'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('قبول العرض'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _isActing = true);
    try {
      await _repository.acceptSubscription(widget.subscriptionId);
    } on AppAuthException catch (e) {
      _showError(e.message);
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  Future<void> _handleReject() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('رفض العرض', style: TextStyle(fontFamily: 'Cairo')),
        content: const Text(
          'هل تريد إنهاء هذه المحادثة دون الاتفاق على اشتراك؟',
          style: TextStyle(fontFamily: 'Cairo'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('تراجع'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('رفض العرض', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _isActing = true);
    try {
      await _repository.rejectSubscription(widget.subscriptionId);
      if (mounted) Navigator.of(context).pop();
    } on AppAuthException catch (e) {
      _showError(e.message);
      if (mounted) setState(() => _isActing = false);
    }
  }

  Future<void> _handleCancelActive() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إلغاء الاشتراك', style: TextStyle(fontFamily: 'Cairo')),
        content: const Text(
          'هل تريد إنهاء هذا الاشتراك النشط؟ إذا لم تُصرف كامل مستحقاتك بعد، سيراجع فريقنا المبلغ المتبقي.',
          style: TextStyle(fontFamily: 'Cairo'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('تراجع'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('إلغاء الاشتراك', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _isActing = true);
    try {
      await _repository.cancelActiveSubscription(widget.subscriptionId);
    } on AppAuthException catch (e) {
      _showError(e.message);
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  Future<void> _handleConfirmPayment() async {
    setState(() => _isActing = true);
    try {
      await _repository.confirmRenewalPayment(widget.subscriptionId);
    } on AppAuthException catch (e) {
      _showError(e.message);
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'Cairo')),
        backgroundColor: AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    final canRespond = status?.hasPendingCustomerOffer == true;
    final canChat = status == null || status.isNegotiating;
    final isActive = status?.status == SubscriptionStatus.active;
    final disputed = status?.paymentDispute == true;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          status?.customerName ?? 'اشتراك شهري',
          style: const TextStyle(fontFamily: 'Cairo'),
        ),
      ),
      body: Column(
        children: [
          if (status != null) _buildStatusBanner(status),
          Expanded(
            child: _messages.isEmpty
                ? const Center(
                    child: Text(
                      'لا رسائل بعد في هذه المحادثة',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        color: AppColors.secondaryText,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) =>
                        _buildBubble(_messages[index]),
                  ),
          ),
          if (canRespond) _buildAcceptRejectBar(),
          if (canChat)
            _buildComposer()
          else if (isActive && !disputed)
            _buildActiveControls(status!),
        ],
      ),
    );
  }

  Widget _buildStatusBanner(CaptainSubscription status) {
    if (status.paymentDispute) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: AppColors.warning.withOpacity(0.12),
        child: const Text(
          'هذا الاشتراك قيد المراجعة من فريقنا - سنتواصل معك قريباً بخصوص المبلغ المحجوز.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColors.warning,
          ),
        ),
      );
    }

    late final Color color;
    late final String text;
    switch (status.status) {
      case SubscriptionStatus.active:
        color = AppColors.success;
        final days = status.daysRemaining;
        final modeText = status.renewalMode == SubscriptionRenewalMode.trusted
            ? 'دفع مباشر (موثوق)'
            : 'دفع عبر التطبيق';
        text = status.agreedPrice != null
            ? 'الاشتراك نشط (الدورة ${status.cycleCount}) بمبلغ '
                  '${status.agreedPrice!.toStringAsFixed(0)} أوقية شهرياً - $modeText'
                  '${days != null ? ' - باقي $days يوماً' : ''}'
            : 'الاشتراك نشط';
        break;
      case SubscriptionStatus.rejected:
        color = AppColors.error;
        text = 'تم رفض هذا العرض';
        break;
      case SubscriptionStatus.cancelled:
        color = AppColors.secondaryText;
        text = 'تم إلغاء هذه المحادثة';
        break;
      case SubscriptionStatus.negotiating:
        color = AppColors.accent;
        text = status.proposedPrice != null
            ? 'آخر عرض: ${status.proposedPrice!.toStringAsFixed(0)} أوقية شهرياً'
                '${status.proposedBy == 'captain' ? ' (منك)' : ' (من الزبون)'}'
            : 'لم يُقترح سعر بعد';
        break;
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: color.withOpacity(0.1),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  /// Shown whenever the customer's current offer is still awaiting this
  /// captain's response - a quick accept/reject without needing to send a
  /// counter-offer through the composer below.
  Widget _buildAcceptRejectBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      color: AppColors.accent.withOpacity(0.08),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _isActing ? null : _handleReject,
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text('رفض'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton(
              onPressed: _isActing ? null : _handleAccept,
              child: Text(_isActing ? 'جارٍ القبول...' : 'قبول العرض'),
            ),
          ),
        ],
      ),
    );
  }

  /// Shown instead of the chat composer once a subscription is active (no
  /// more negotiating to do): the trusted-mode payment-confirmation prompt
  /// when one is pending, and the option to end the subscription early.
  Widget _buildActiveControls(CaptainSubscription status) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, -2)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (status.awaitingCaptainConfirmation) ...[
              Text(
                'هل استلمت مباشرة اشتراك هذا الشهر من ${status.customerName}؟',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppColors.darkText,
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _isActing ? null : _handleConfirmPayment,
                child: Text(_isActing ? 'جارٍ التأكيد...' : 'نعم، استلمت الدفعة'),
              ),
              const SizedBox(height: 8),
            ],
            TextButton(
              onPressed: _isActing ? null : _handleCancelActive,
              child: const Text(
                'إلغاء الاشتراك',
                style: TextStyle(color: AppColors.error),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBubble(SubscriptionMessage message) {
    final isMine = message.senderRole == 'captain';
    return Align(
      alignment: isMine
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        decoration: BoxDecoration(
          color: message.isOffer
              ? AppColors.accent.withOpacity(0.15)
              : (isMine ? AppColors.primary : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: message.isOffer
              ? Border.all(color: AppColors.accent.withOpacity(0.4))
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.isOffer)
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text(
                  'عرض سعر',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.secondary,
                  ),
                ),
              ),
            Text(
              message.body,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                color: message.isOffer
                    ? AppColors.darkText
                    : (isMine ? Colors.white : AppColors.darkText),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComposer() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, -2)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _offerController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: 'اقترح سعراً شهرياً (أوقية)',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _isSending ? null : _handleSendOffer,
                  child: const Text('إرسال عرض'),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'اكتب رسالة...',
                      isDense: true,
                    ),
                    onSubmitted: (_) => _handleSend(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _isSending ? null : _handleSend,
                  icon: const Icon(Icons.send_rounded, color: AppColors.primary),
                ),
              ],
            ),
            // Only shown here when there's no pending customer offer to
            // accept/reject already (that case gets its own dedicated bar,
            // _buildAcceptRejectBar, right above this composer) - avoids
            // showing two different ways to reject at once.
            if (_status?.isNegotiating == true &&
                _status?.hasPendingCustomerOffer != true)
              TextButton(
                onPressed: _isActing ? null : _handleReject,
                child: const Text(
                  'رفض العرض وإنهاء المحادثة',
                  style: TextStyle(color: AppColors.error),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
