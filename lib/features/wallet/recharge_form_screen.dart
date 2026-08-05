import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/recharge_banks.dart';
import '../../core/supabase/auth_exception.dart';
import '../../core/supabase/wallet_repository.dart';

/// Second step of wallet recharge: the captain enters the amount they
/// already transferred to our own account with [bank], plus the transaction
/// reference their banking app gave them, and submits it for admin review.
class RechargeFormScreen extends StatefulWidget {
  final RechargeBank bank;
  const RechargeFormScreen({super.key, required this.bank});

  @override
  State<RechargeFormScreen> createState() => _RechargeFormScreenState();
}

class _RechargeFormScreenState extends State<RechargeFormScreen> {
  final _repository = WalletRepository();
  final _amountController = TextEditingController();
  final _referenceController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  void _copyAccountNumber() {
    Clipboard.setData(ClipboardData(text: widget.bank.companyAccountNumber));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم نسخ الرقم', style: TextStyle(fontFamily: 'Cairo')),
      ),
    );
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountController.text.trim());
    final reference = _referenceController.text.trim();
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'أدخل مبلغًا صحيحًا.',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    if (reference.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'أدخل رقم عملية التحويل.',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await _repository.submitRechargeRequest(
        bankId: widget.bank.id,
        amount: amount,
        transactionReference: reference,
      );
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم إرسال طلب الشحن، سيُضاف المبلغ لرصيدك بعد مراجعته من الإدارة.',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 5),
        ),
      );
    } on AppAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message, style: const TextStyle(fontFamily: 'Cairo')),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bank = widget.bank;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(bank.name)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: bank.color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: bank.color.withOpacity(0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '١) حوّل المبلغ من تطبيق ${bank.name} إلى:',
                      style: const TextStyle(
                        fontSize: 13,
                        fontFamily: 'Cairo',
                        color: AppColors.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          bank.companyAccountNumber,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: bank.color,
                            fontFamily: 'Cairo',
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          onPressed: _copyAccountNumber,
                        ),
                      ],
                    ),
                    Text(
                      bank.companyAccountLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.secondaryText,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '٢) أدخل بيانات التحويل الذي أجريته',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkText,
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'المبلغ الذي حوّلته',
                  suffixText: 'أوقية',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _referenceController,
                decoration: const InputDecoration(
                  labelText: 'رقم عملية التحويل (Transaction ID)',
                  hintText: 'كما يظهر في تطبيق البنك بعد التحويل',
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('إرسال طلب الشحن'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
