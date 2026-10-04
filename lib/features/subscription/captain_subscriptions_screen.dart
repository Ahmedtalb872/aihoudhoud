import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';
import '../../core/supabase/auth_exception.dart';
import '../../core/supabase/subscription_repository.dart';
import '../../models/models.dart';
import 'subscription_chat_screen.dart';

/// Lists every "اشتراك شهري" thread this captain is party to - previously
/// missing entirely: a customer could start negotiating a monthly
/// subscription with a captain (see app-driver-customer's
/// CaptainsBrowseScreen/SubscriptionChatScreen), but nothing in this app
/// ever showed the captain that offer existed at all. Negotiating threads
/// (especially ones awaiting this captain's response) surface above
/// already-settled ones.
class CaptainSubscriptionsScreen extends StatefulWidget {
  const CaptainSubscriptionsScreen({super.key});

  @override
  State<CaptainSubscriptionsScreen> createState() =>
      _CaptainSubscriptionsScreenState();
}

class _CaptainSubscriptionsScreenState
    extends State<CaptainSubscriptionsScreen> {
  final _repository = SubscriptionRepository();
  late Future<List<CaptainSubscription>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repository.fetchMySubscriptions();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _repository.fetchMySubscriptions();
    });
    await _future;
  }

  void _openChat(CaptainSubscription subscription) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) =>
                SubscriptionChatScreen(subscriptionId: subscription.id),
          ),
        )
        .then((_) => _refresh());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('عروض الاشتراك الشهري')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<CaptainSubscription>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              final message = snapshot.error is AppAuthException
                  ? (snapshot.error as AppAuthException).message
                  : 'تعذر تحميل عروض الاشتراك.';
              return ListView(
                children: [
                  const SizedBox(height: 80),
                  Icon(
                    Icons.error_outline_rounded,
                    size: 48,
                    color: AppColors.error.withOpacity(0.6),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              );
            }
            final subscriptions = snapshot.data ?? [];
            if (subscriptions.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 80),
                  const Icon(
                    Icons.handshake_outlined,
                    size: 48,
                    color: AppColors.secondaryText,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'لا توجد عروض اشتراك حالياً',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'عندما يبدأ زبون تفاوضاً معك على اشتراك شهري، سيظهر هنا.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: subscriptions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) =>
                  _SubscriptionTile(
                    subscription: subscriptions[index],
                    onTap: () => _openChat(subscriptions[index]),
                  ),
            );
          },
        ),
      ),
    );
  }
}

class _SubscriptionTile extends StatelessWidget {
  final CaptainSubscription subscription;
  final VoidCallback onTap;

  const _SubscriptionTile({required this.subscription, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final (Color color, String statusText) = switch (subscription.status) {
      SubscriptionStatus.active => (AppColors.success, 'نشط'),
      SubscriptionStatus.rejected => (AppColors.error, 'مرفوض'),
      SubscriptionStatus.cancelled => (AppColors.secondaryText, 'ملغى'),
      SubscriptionStatus.negotiating => subscription.hasPendingCustomerOffer
          ? (AppColors.accent, 'عرض جديد - بانتظار ردك')
          : (AppColors.primary, 'قيد التفاوض'),
    };

    String subtitle;
    if (subscription.status == SubscriptionStatus.active &&
        subscription.agreedPrice != null) {
      subtitle = '${subscription.agreedPrice!.toStringAsFixed(0)} أوقية شهرياً';
    } else if (subscription.proposedPrice != null) {
      subtitle = 'آخر عرض: ${subscription.proposedPrice!.toStringAsFixed(0)} أوقية';
    } else {
      subtitle = 'لا يوجد عرض سعر بعد';
    }

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: subscription.hasPendingCustomerOffer ? 3 : 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: color.withOpacity(0.12),
                child: Icon(Icons.person_rounded, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subscription.customerName,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.darkText,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
