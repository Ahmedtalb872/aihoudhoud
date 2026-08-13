import 'package:flutter/material.dart';

/// A mobile-payment provider captains can recharge their wallet through.
/// [companyAccountNumber] is our own receiving number for that provider,
/// shown to the captain so they transfer to it themselves - there is no
/// live API integration with any of these providers yet, see
/// WalletRepository for where that would plug in once we have one.
class RechargeBank {
  final String id;
  final String name;
  final Color color;
  final IconData icon;
  final String companyAccountLabel;
  final String companyAccountNumber;

  const RechargeBank({
    required this.id,
    required this.name,
    required this.color,
    required this.icon,
    required this.companyAccountLabel,
    required this.companyAccountNumber,
  });
}

// TODO(payment-setup): replace these placeholder numbers with الهدهد's real
// receiving account/merchant code at each provider once available.
const List<RechargeBank> kRechargeBanks = [
  RechargeBank(
    id: 'bankily',
    name: 'Bankily بنكيلي',
    color: Color(0xFF1CADE4),
    icon: Icons.smartphone_rounded,
    companyAccountLabel: 'كود تاجر الهدهد على Bankily (AL HODHOD)',
    companyAccountNumber: '027575',
  ),
  RechargeBank(
    id: 'sedad',
    name: 'السداد Sedad Bank',
    color: Color(0xFF1B7A3D),
    icon: Icons.account_balance_rounded,
    companyAccountLabel: 'رقم السداد الهدهد',
    companyAccountNumber: '00 00 00 00',
  ),
  RechargeBank(
    id: 'click',
    name: 'كليك Click',
    color: Color(0xFF0B6FB0),
    icon: Icons.touch_app_rounded,
    companyAccountLabel: 'رقم Click الهدهد',
    companyAccountNumber: '00 00 00 00',
  ),
];
