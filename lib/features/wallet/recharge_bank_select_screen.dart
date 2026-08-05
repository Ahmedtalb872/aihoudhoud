import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/recharge_banks.dart';
import 'recharge_form_screen.dart';

/// First step of wallet recharge: pick which payment provider the captain
/// already sent (or will send) money through.
class RechargeBankSelectScreen extends StatelessWidget {
  const RechargeBankSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('شحن الرصيد')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'اختر وسيلة الدفع الإلكتروني التي حوّلت (أو ستحوّل) منها المبلغ',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.secondaryText,
                fontFamily: 'Cairo',
              ),
            ),
            const SizedBox(height: 16),
            ...kRechargeBanks.map(
              (bank) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _BankCard(bank: bank),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BankCard extends StatelessWidget {
  final RechargeBank bank;
  const _BankCard({required this.bank});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => RechargeFormScreen(bank: bank),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bank.color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(bank.icon, color: bank.color, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                bank.name,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkText,
                  fontFamily: 'Cairo',
                ),
              ),
            ),
            const Icon(
              Icons.chevron_left_rounded,
              color: AppColors.secondaryText,
            ),
          ],
        ),
      ),
    );
  }
}
