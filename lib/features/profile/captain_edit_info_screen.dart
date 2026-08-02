import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/supabase/auth_exception.dart';
import '../../core/supabase/auth_repository.dart';
import '../../providers/app_state_provider.dart';

/// Lets a captain fix their personal/vehicle details after registration -
/// most commonly needed right after an admin rejects the application for a
/// mistake (wrong plate number, blurry brand/model, etc.) and the captain
/// needs to correct it and resubmit.
class CaptainEditInfoScreen extends StatefulWidget {
  const CaptainEditInfoScreen({super.key});

  @override
  State<CaptainEditInfoScreen> createState() => _CaptainEditInfoScreenState();
}

class _CaptainEditInfoScreenState extends State<CaptainEditInfoScreen> {
  final _authRepository = AuthRepository();
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorText;

  final _nameController = TextEditingController();
  String _selectedCity = 'نواكشوط';
  final _addressController = TextEditingController();
  final _dobController = TextEditingController();

  String _vehicleCategory = 'car';
  String _carType = 'economy';
  final _carBrandController = TextEditingController();
  final _carModelController = TextEditingController();
  final _carYearController = TextEditingController();
  final _carColorController = TextEditingController();
  final _carPlateController = TextEditingController();
  int _carSeats = 4;

  bool get _isMotorcycle => _vehicleCategory == 'motorcycle';

  @override
  void initState() {
    super.initState();
    _loadCurrentInfo();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _dobController.dispose();
    _carBrandController.dispose();
    _carModelController.dispose();
    _carYearController.dispose();
    _carColorController.dispose();
    _carPlateController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentInfo() async {
    final userId = _authRepository.currentUser?.id;
    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final profile = await _authRepository.getProfile(userId);
      final captain = await _authRepository.getCaptain(userId);
      if (!mounted) return;
      setState(() {
        _nameController.text = profile['full_name'] as String? ?? '';
        _selectedCity = captain['city'] as String? ?? 'نواكشوط';
        _addressController.text = captain['address'] as String? ?? '';
        _dobController.text = captain['date_of_birth'] as String? ?? '';
        final vehicleType = captain['vehicle_type'] as String? ?? 'economy';
        _vehicleCategory = vehicleType == 'motorcycle' ? 'motorcycle' : 'car';
        _carType = _vehicleCategory == 'car' ? vehicleType : 'economy';
        _carBrandController.text = captain['vehicle_brand'] as String? ?? '';
        _carModelController.text = captain['vehicle_model'] as String? ?? '';
        _carYearController.text =
            (captain['vehicle_year'] as num?)?.toString() ?? '2018';
        _carColorController.text = captain['vehicle_color'] as String? ?? '';
        _carPlateController.text = captain['vehicle_plate'] as String? ?? '';
        _carSeats = (captain['vehicle_seats'] as num?)?.toInt() ?? 4;
      });
    } on AppAuthException catch (e) {
      if (mounted) setState(() => _errorText = e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    final userId = _authRepository.currentUser?.id;
    if (userId == null) return;
    if (_nameController.text.trim().isEmpty) {
      setState(() => _errorText = 'الرجاء إدخال الاسم الكامل');
      return;
    }
    setState(() {
      _isSaving = true;
      _errorText = null;
    });
    try {
      await _authRepository.updateProfileName(
        userId,
        _nameController.text.trim(),
      );
      final vehicleType = _isMotorcycle ? 'motorcycle' : _carType;
      await _authRepository.updateCaptainVehicleInfo(
        captainId: userId,
        city: _selectedCity,
        address: _addressController.text.trim(),
        dateOfBirth: _dobController.text.trim(),
        vehicleType: vehicleType,
        vehicleBrand: _carBrandController.text.trim(),
        vehicleModel: _carModelController.text.trim(),
        vehicleYear: int.tryParse(_carYearController.text.trim()) ?? 2018,
        vehicleColor: _carColorController.text.trim(),
        vehiclePlate: _carPlateController.text.trim(),
        vehicleSeats: _carSeats,
      );
      if (!mounted) return;
      final provider = Provider.of<AppStateProvider>(context, listen: false);
      provider.updateCaptainDisplayName(_nameController.text.trim());
      provider.updateVehicleCategoryLocally(vehicleType);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم حفظ التعديلات بنجاح.',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.of(context).pop();
    } on AppAuthException catch (e) {
      setState(() => _errorText = e.message);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('تعديل المعلومات')),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'المعلومات الشخصية',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkText,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildTextField('الاسم الكامل', _nameController),
                    const SizedBox(height: 16),
                    const Text(
                      'المدينة',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkText,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedCity,
                          isExpanded: true,
                          style: const TextStyle(
                            color: AppColors.darkText,
                            fontSize: 16,
                            fontFamily: 'Cairo',
                          ),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _selectedCity = value);
                            }
                          },
                          items:
                              <String>['نواكشوط', 'نواذيبو', 'روصو', 'أطار', 'كيفه']
                                  .map(
                                    (v) => DropdownMenuItem(
                                      value: v,
                                      child: Text(v),
                                    ),
                                  )
                                  .toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildTextField('العنوان بالتفصيل', _addressController),
                    const SizedBox(height: 16),
                    _buildTextField(
                      'تاريخ الميلاد',
                      _dobController,
                      hint: 'YYYY-MM-DD',
                    ),
                    const SizedBox(height: 28),

                    const Text(
                      'المركبة',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkText,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildVehicleCategoryCard(
                          'car',
                          'سيارة',
                          Icons.directions_car_filled_rounded,
                        ),
                        const SizedBox(width: 12),
                        _buildVehicleCategoryCard(
                          'motorcycle',
                          'دراجة نارية',
                          Icons.two_wheeler_rounded,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (!_isMotorcycle) ...[
                      const Text(
                        'فئة السيارة',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkText,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildCarTypeChip('economy', 'إقتصادية'),
                          const SizedBox(width: 8),
                          _buildCarTypeChip('comfort', 'مريحة'),
                          const SizedBox(width: 8),
                          _buildCarTypeChip('family', 'عائلية'),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                    _buildTextField(
                      _isMotorcycle ? 'ماركة الدراجة' : 'ماركة السيارة',
                      _carBrandController,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField('الموديل', _carModelController),
                    const SizedBox(height: 16),
                    _buildTextField('سنة الصنع', _carYearController),
                    const SizedBox(height: 16),
                    _buildTextField(
                      _isMotorcycle ? 'لون الدراجة' : 'لون السيارة',
                      _carColorController,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField('رقم اللوحة', _carPlateController),
                    if (!_isMotorcycle) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'عدد المقاعد المتاحة للركاب',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkText,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _carSeats,
                            isExpanded: true,
                            style: const TextStyle(
                              color: AppColors.darkText,
                              fontSize: 16,
                              fontFamily: 'Cairo',
                            ),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _carSeats = value);
                              }
                            },
                            items: <int>[4, 6, 7]
                                .map(
                                  (v) => DropdownMenuItem(
                                    value: v,
                                    child: Text('$v مقاعد'),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ),
                    ],

                    if (_errorText != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _errorText!,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 13,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      child: _isSaving
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: AppColors.darkText,
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Text('حفظ التعديلات'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildVehicleCategoryCard(String category, String label, IconData icon) {
    bool isSel = _vehicleCategory == category;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _vehicleCategory = category),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSel ? AppColors.primary.withOpacity(0.12) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSel ? AppColors.primary : AppColors.border,
              width: isSel ? 2 : 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSel ? AppColors.primaryDark : AppColors.secondaryText,
                size: 32,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.darkText,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCarTypeChip(String type, String label) {
    bool isSel = _carType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _carType = type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSel ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSel ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSel ? Colors.white : AppColors.darkText,
              fontWeight: FontWeight.bold,
              fontFamily: 'Cairo',
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.darkText,
            fontFamily: 'Cairo',
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }
}
