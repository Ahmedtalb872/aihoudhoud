import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/supabase/auth_exception.dart';
import '../../core/supabase/auth_repository.dart';
import '../../providers/app_state_provider.dart';

/// Same doc_key list used at registration (captain_register_stepper_screen's
/// _kDocKeys) - kept in sync here since both read/write the same
/// `captain_documents` rows.
const List<Map<String, String>> _kDocs = [
  {'key': 'profile_photo', 'name': 'الصورة الشخصية'},
  {'key': 'national_id', 'name': 'بطاقة الهوية الوطنية'},
  {'key': 'driving_license', 'name': 'رخصة السياقة'},
  {'key': 'gray_card', 'name': 'البطاقة الرمادية'},
  {'key': 'car_photo', 'name': 'صورة السيارة'},
  {'key': 'car_insurance', 'name': 'تأمين السيارة'},
  {'key': 'extra_work_permit', 'name': 'تصريح العمل الإضافي'},
];

// Only the driving-license/registration/vehicle-photo/insurance labels
// change wording for a motorcycle - same doc_key, same everything else.
const Map<String, String> _kMotorcycleDocLabels = {
  'رخصة السياقة': 'رخصة قيادة دراجة نارية',
  'البطاقة الرمادية': 'تسجيل الدراجة',
  'صورة السيارة': 'صورة الدراجة النارية',
  'تأمين السيارة': 'تأمين الدراجة النارية',
};

class CaptainDocumentsStatusScreen extends StatefulWidget {
  const CaptainDocumentsStatusScreen({super.key});

  @override
  State<CaptainDocumentsStatusScreen> createState() =>
      _CaptainDocumentsStatusScreenState();
}

class _CaptainDocumentsStatusScreenState
    extends State<CaptainDocumentsStatusScreen> {
  final _authRepository = AuthRepository();
  bool _isLoading = true;
  String? _uploadingDoc;
  Map<String, String> _statusByKey = {};
  String? _rejectionReason;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final userId = _authRepository.currentUser?.id;
    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final docs = await _authRepository.getCaptainDocuments(userId);
      final captain = await _authRepository.getCaptain(userId);
      if (!mounted) return;
      setState(() {
        _statusByKey = {
          for (final row in docs)
            row['doc_key'] as String: row['status'] as String? ??
                'under_review',
        };
        _rejectionReason = captain['status'] == 'rejected'
            ? captain['rejection_reason'] as String?
            : null;
      });
    } on AppAuthException catch (_) {
      // Leave whatever was already loaded - a failed refresh isn't fatal.
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _displayLabel(String docName, bool isMotorcycle) {
    if (!isMotorcycle) return docName;
    return _kMotorcycleDocLabels[docName] ?? docName;
  }

  Future<void> _reuploadDoc(String docKey, String docName) async {
    final userId = _authRepository.currentUser?.id;
    if (userId == null) return;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.camera_alt_rounded,
                color: AppColors.primary,
              ),
              title: const Text(
                'التقاط صورة',
                style: TextStyle(fontFamily: 'Cairo'),
              ),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library_rounded,
                color: AppColors.primary,
              ),
              title: const Text(
                'اختيار من المعرض',
                style: TextStyle(fontFamily: 'Cairo'),
              ),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    setState(() => _uploadingDoc = docKey);
    try {
      final file = await ImagePicker().pickImage(source: source, imageQuality: 80);
      if (file == null) {
        if (mounted) setState(() => _uploadingDoc = null);
        return;
      }
      final Uint8List bytes = await file.readAsBytes();
      await _authRepository.uploadCaptainDocuments(userId, [
        CaptainDocumentFile(docKey: docKey, docName: docName, bytes: bytes),
      ]);
      if (!mounted) return;
      setState(() {
        _statusByKey[docKey] = 'under_review';
        _uploadingDoc = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم رفع $docName من جديد، وهو الآن قيد المراجعة.',
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _uploadingDoc = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تعذر رفع المستند، حاول مرة أخرى.',
            style: TextStyle(fontFamily: 'Cairo'),
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppStateProvider>(context);
    final isMotorcycle = provider.isMotorcycleCaptain;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('حالة المستندات المرفوعة')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(24.0),
                children: [
                  if (_rejectionReason != null &&
                      _rejectionReason!.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.error.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: AppColors.error,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'ملاحظة من الإدارة',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: AppColors.error,
                                    fontFamily: 'Cairo',
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _rejectionReason!,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.darkText,
                                    fontFamily: 'Cairo',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  ..._kDocs.map((doc) {
                    final docKey = doc['key']!;
                    final docName = _displayLabel(doc['name']!, isMotorcycle);
                    final status = _statusByKey[docKey];
                    final isThisUploading = _uploadingDoc == docKey;

                    Color statusColor = AppColors.secondaryText;
                    String statusText = 'لم يُرفع بعد';
                    IconData statusIcon = Icons.upload_file_rounded;
                    if (status == 'approved') {
                      statusColor = AppColors.success;
                      statusText = 'تم القبول';
                      statusIcon = Icons.check_circle_outline;
                    } else if (status == 'under_review') {
                      statusColor = AppColors.warning;
                      statusText = 'قيد المراجعة';
                      statusIcon = Icons.hourglass_empty_rounded;
                    } else if (status == 'rejected') {
                      statusColor = AppColors.error;
                      statusText = 'مرفوض - يحتاج إعادة رفع';
                      statusIcon = Icons.cancel_outlined;
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      docName,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.darkText,
                                        fontFamily: 'Cairo',
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          statusIcon,
                                          color: statusColor,
                                          size: 14,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          statusText,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: statusColor,
                                            fontFamily: 'Cairo',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (status != 'approved') ...[
                                const Divider(height: 24),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: isThisUploading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: AppColors.primary,
                                          ),
                                        )
                                      : ElevatedButton.icon(
                                          onPressed: () => _reuploadDoc(
                                            docKey,
                                            doc['name']!,
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            minimumSize: const Size(140, 36),
                                            padding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                          ),
                                          icon: const Icon(
                                            Icons.upload_rounded,
                                            size: 16,
                                          ),
                                          label: Text(
                                            status == null
                                                ? 'رفع المستند'
                                                : 'إعادة رفع المستند',
                                            style: const TextStyle(
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }
}
