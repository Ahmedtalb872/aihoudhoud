import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/constants/colors.dart';
import '../../core/services/new_trip_alert.dart';
import '../../core/services/oem_background_permission.dart';
import '../../core/services/trip_overlay.dart';
import '../../core/widgets/app_logo.dart';

/// Arabic label shown for a known aggressive-OEM manufacturer string (see
/// kAggressiveOemManufacturers) - null for anything else, in which case the
/// extra guidance card isn't shown at all.
String? _oemDisplayName(String manufacturer) {
  switch (manufacturer) {
    case 'xiaomi':
      return 'شاومي (Xiaomi/Redmi/Poco)';
    case 'oppo':
    case 'realme':
      return 'أوبو (Oppo/Realme)';
    case 'vivo':
      return 'فيفو (Vivo/iQOO)';
    case 'huawei':
    case 'honor':
      return 'هواوي/هونر (Huawei/Honor)';
    case 'infinix':
    case 'tecno':
    case 'itel':
      return 'إنفينكس/تكنو (Infinix/Tecno/itel)';
    default:
      return null;
  }
}

/// Shown once right after login/registration: asks the captain to enable
/// location (needed to show/track trips) and notifications (needed to be
/// alerted about new ride requests). Not a hard gate — "متابعة" always
/// continues to [destination], granted or not.
class PermissionsScreen extends StatefulWidget {
  final Widget destination;
  const PermissionsScreen({super.key, required this.destination});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen>
    with WidgetsBindingObserver {
  PermissionStatus _locationStatus = PermissionStatus.denied;
  PermissionStatus _notificationStatus = PermissionStatus.denied;
  String? _oemLabel;
  // null until checked (or on a platform without this permission, e.g.
  // iOS) - the card only ever shows once this is a real true/false.
  bool? _overlayGranted;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshStatuses();
    // Unconditional, not just on the notification button press below: this
    // screen shows on every login (not only first-time onboarding), and a
    // captain who granted the ordinary notification permission on an older
    // app version - before this Android 14+ full-screen-intent permission
    // existed - would otherwise never be asked for it, since the
    // notification card already shows granted and its button never
    // appears. The native call is a no-op if already granted, so this
    // never interrupts a captain who's already set up.
    NewTripAlert.requestFullScreenIntentPermission();
    _detectOem();
  }

  // Stock Android's notification/full-screen-intent permissions above
  // aren't enough on these ROMs to reliably wake the app while it's
  // backgrounded on a screen that's on and unlocked - see
  // OemBackgroundPermission's header comment. Shown only for manufacturers
  // actually known to need it; everyone else never sees this card.
  Future<void> _detectOem() async {
    final manufacturer = await OemBackgroundPermission.getManufacturer();
    if (!mounted || manufacturer == null) return;
    setState(() => _oemLabel = _oemDisplayName(manufacturer));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Catches the case where the captain granted the permission from the
    // system Settings screen and came back to the app.
    if (state == AppLifecycleState.resumed) {
      _refreshStatuses();
    }
  }

  Future<void> _refreshStatuses() async {
    final location = await _safeStatus(Permission.locationWhenInUse);
    final notification = await _safeStatus(Permission.notification);
    final overlayGranted = await TripOverlay.hasPermission();
    if (!mounted) return;
    setState(() {
      _locationStatus = location;
      _notificationStatus = notification;
      _overlayGranted = overlayGranted;
    });
  }

  Future<void> _requestLocation() async {
    final status = await _safeRequest(Permission.locationWhenInUse);
    if (!mounted) return;
    setState(() => _locationStatus = status);
    if (status.isPermanentlyDenied) _showOpenSettingsSnack();
  }

  Future<void> _requestNotification() async {
    final status = await _safeRequest(Permission.notification);
    if (!mounted) return;
    setState(() => _notificationStatus = status);
    if (status.isPermanentlyDenied) _showOpenSettingsSnack();
    // Separate from the notification permission above on Android 14+ -
    // without it, the new-trip alert rings but never actually opens the
    // app on top of the lock screen the way it's supposed to.
    await NewTripAlert.requestFullScreenIntentPermission();
  }

  // Some platforms (e.g. web) don't implement every Permission; fall back to
  // "denied" instead of crashing the screen.
  Future<PermissionStatus> _safeStatus(Permission permission) async {
    try {
      return await permission.status;
    } catch (_) {
      return PermissionStatus.denied;
    }
  }

  Future<PermissionStatus> _safeRequest(Permission permission) async {
    try {
      return await permission.request();
    } catch (_) {
      return PermissionStatus.denied;
    }
  }

  void _showOpenSettingsSnack() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'تم رفض الصلاحية سابقًا، فعّلها يدويًا من إعدادات الهاتف.',
          style: TextStyle(fontFamily: 'Cairo'),
        ),
        action: SnackBarAction(label: 'الإعدادات', onPressed: openAppSettings),
      ),
    );
  }

  void _continue() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => widget.destination),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locationGranted = _locationStatus.isGranted;
    final notificationGranted = _notificationStatus.isGranted;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              const Center(child: AppLogo(width: 88)),
              const SizedBox(height: 24),
              const Text(
                'قبل ما نبدأ...',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkText,
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'فعّل هاتين الصلاحيتين لتحصل على أفضل تجربة ككابتن.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.secondaryText,
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 28),
              _buildPermissionCard(
                icon: Icons.location_on_rounded,
                title: 'تفعيل الموقع',
                description:
                    'لعرض المشاوير القريبة منك وتتبع مسار الرحلة على الخريطة.',
                granted: locationGranted,
                onPressed: _requestLocation,
              ),
              const SizedBox(height: 16),
              _buildPermissionCard(
                icon: Icons.notifications_active_rounded,
                title: 'تفعيل الإشعارات',
                description: 'لتنبيهك فورًا عند وصول طلب مشوار جديد.',
                granted: notificationGranted,
                onPressed: _requestNotification,
              ),
              if (_overlayGranted != null) ...[
                const SizedBox(height: 16),
                _buildPermissionCard(
                  icon: Icons.picture_in_picture_alt_rounded,
                  title: 'الظهور فوق التطبيقات الأخرى',
                  description:
                      'ليصلك تنبيه المشوار حتى لو كان هاتفك مفتوحًا على تطبيق آخر.',
                  granted: _overlayGranted!,
                  onPressed: TripOverlay.requestPermission,
                ),
              ],
              if (_oemLabel != null) ...[
                const SizedBox(height: 16),
                _buildOemCard(_oemLabel!),
              ],
              const Spacer(),
              ElevatedButton(onPressed: _continue, child: const Text('متابعة')),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // Extra card, only for phones from a manufacturer known to suppress
  // background alerts unless its own autostart/pop-up toggle is on. Not a
  // permission with a granted/denied state to track - just a one-time
  // best-effort jump to that settings screen (see MainActivity.kt).
  Widget _buildOemCard(String oemLabel) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.warning.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.phonelink_lock_rounded,
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'هاتفك من نوع $oemLabel',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.darkText,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'هذا النوع من الهواتف يوقف تنبيه الطلبات الجديدة إن لم تُفعّل خيار "التشغيل التلقائي" أو "الظهور في الخلفية" للتطبيق. فعّله الآن حتى لا تفوّتك الطلبات.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.secondaryText,
              fontFamily: 'Cairo',
              height: 1.6,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: OemBackgroundPermission.openBackgroundSettings,
              child: const Text('فتح إعدادات الهاتف'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionCard({
    required IconData icon,
    required String title,
    required String description,
    required bool granted,
    required VoidCallback onPressed,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (granted ? AppColors.success : AppColors.primary)
                  .withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: granted ? AppColors.success : AppColors.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.darkText,
                    fontFamily: 'Cairo',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.secondaryText,
                    fontFamily: 'Cairo',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          granted
              ? const Icon(Icons.check_circle_rounded, color: AppColors.success)
              : SizedBox(
                  width: 76,
                  height: 34,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                    onPressed: onPressed,
                    child: const Text('تفعيل'),
                  ),
                ),
        ],
      ),
    );
  }
}
