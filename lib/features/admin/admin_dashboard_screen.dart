import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../../core/supabase/auth_exception.dart';
import '../../core/supabase/auth_repository.dart';

/// Every captain in one list, for an admin account (profiles.is_admin) to
/// look up who to pay and how - name, phone, vehicle, and the payout
/// method/number they entered at registration or from their profile.
/// Read-only: there's no in-app payout action, this just replaces having
/// to run a SQL query per captain from the Supabase dashboard.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _authRepository = AuthRepository();
  bool _isLoading = true;
  String? _errorText;
  List<Map<String, dynamic>> _captains = [];
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorText = null;
    });
    try {
      final captains = await _authRepository.getAllCaptainsForAdmin();
      if (!mounted) return;
      setState(() => _captains = captains);
    } on AppAuthException catch (e) {
      if (mounted) setState(() => _errorText = e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_query.isEmpty) return _captains;
    final q = _query.toLowerCase();
    return _captains.where((c) {
      final name = (c['full_name'] as String? ?? '').toLowerCase();
      final phone = (c['phone'] as String? ?? '').toLowerCase();
      return name.contains(q) || phone.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('لوحة التحكم - الكباتن'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _isLoading ? null : _load,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'ابحث بالاسم أو رقم الهاتف',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorText != null) {
      return Center(
        child: Text(
          _errorText!,
          style: const TextStyle(color: AppColors.error, fontFamily: 'Cairo'),
        ),
      );
    }
    final list = _filtered;
    if (list.isEmpty) {
      return const Center(
        child: Text(
          'لا يوجد كباتن مطابقون',
          style: TextStyle(color: AppColors.secondaryText, fontFamily: 'Cairo'),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) => _buildCaptainCard(list[index]),
      ),
    );
  }

  Widget _buildCaptainCard(Map<String, dynamic> c) {
    final name = c['full_name'] as String? ?? 'بدون اسم';
    final phone = c['phone'] as String? ?? '';
    final status = c['status'] as String? ?? 'pending';
    final vehicleType = c['vehicle_type'] as String?;
    final payoutMethod = c['payout_method'] as String?;
    final payoutPhone = c['payout_phone'] as String?;

    final statusInfo = _statusInfo(status);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.darkText,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusInfo.$2.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    statusInfo.$1,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: statusInfo.$2,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              phone,
              style: const TextStyle(fontSize: 12, color: AppColors.secondaryText),
            ),
            if (vehicleType != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    vehicleType == 'motorcycle'
                        ? Icons.two_wheeler_rounded
                        : Icons.directions_car_filled_rounded,
                    size: 15,
                    color: AppColors.secondaryText,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _vehicleLabel(vehicleType),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.secondaryText,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ],
              ),
            ],
            const Divider(height: 20),
            Row(
              children: [
                const Icon(
                  Icons.payments_outlined,
                  size: 15,
                  color: AppColors.primaryDark,
                ),
                const SizedBox(width: 6),
                Text(
                  payoutMethod == null || payoutPhone == null || payoutPhone.isEmpty
                      ? 'لم يُدخل معلومات دفع بعد'
                      : '${_payoutMethodLabel(payoutMethod)} - $payoutPhone',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: payoutMethod == null
                        ? AppColors.secondaryText
                        : AppColors.darkText,
                    fontFamily: 'Cairo',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  (String, Color) _statusInfo(String status) {
    switch (status) {
      case 'approved':
        return ('مقبول', AppColors.success);
      case 'rejected':
        return ('مرفوض', AppColors.error);
      case 'suspended':
        return ('موقوف', AppColors.error);
      default:
        return ('قيد المراجعة', AppColors.warning);
    }
  }

  String _vehicleLabel(String vehicleType) {
    switch (vehicleType) {
      case 'motorcycle':
        return 'دراجة نارية';
      case 'comfort':
        return 'سيارة مريحة';
      case 'family':
        return 'سيارة عائلية';
      default:
        return 'سيارة اقتصادية';
    }
  }

  String _payoutMethodLabel(String method) {
    switch (method) {
      case 'bankily':
        return 'Bankily';
      case 'masrvi':
        return 'Masrvi';
      case 'sedad':
        return 'Sedad';
      default:
        return 'أخرى';
    }
  }
}
