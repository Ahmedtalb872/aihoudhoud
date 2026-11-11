import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';

/// Shows a bottom sheet confirming the trip's agreed-upon price before it's
/// marked complete - fixed to [suggestedAmount] (the quoted fare the
/// customer booked at, or the live metered fare for an open ride) rather
/// than a free-entry amount, so a captain can't report collecting more or
/// less than what was actually agreed. Calls [onConfirm] with that amount.
void showCollectPaymentDialog(
  BuildContext context, {
  required double suggestedAmount,
  required void Function(double amountPaid) onConfirm,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => _CollectPaymentSheet(
      suggestedAmount: suggestedAmount,
      onConfirm: onConfirm,
    ),
  );
}

class _CollectPaymentSheet extends StatelessWidget {
  final double suggestedAmount;
  final void Function(double amountPaid) onConfirm;

  const _CollectPaymentSheet({
    required this.suggestedAmount,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final validAmount = suggestedAmount > 0;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'إنهاء المشوار',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.darkText,
                fontFamily: 'El Messiri',
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'السعر المتفق عليه لهذا المشوار',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.secondaryText,
                fontFamily: 'El Messiri',
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              alignment: Alignment.center,
              child: Text(
                validAmount
                    ? '${suggestedAmount.toStringAsFixed(0)} أوقية'
                    : 'تعذر تحديد السعر',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkText,
                  fontFamily: 'El Messiri',
                ),
              ),
            ),
            if (!validAmount) ...[
              const SizedBox(height: 10),
              const Text(
                'لا يمكن إنهاء المشوار بسعر غير صحيح، تواصل مع الدعم.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.error,
                  fontFamily: 'El Messiri',
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('تراجع'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: validAmount
                        ? () {
                            Navigator.of(context).pop();
                            onConfirm(suggestedAmount);
                          }
                        : null,
                    child: const Text('تأكيد وإنهاء الرحلة'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
