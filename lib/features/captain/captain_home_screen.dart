import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/constants/colors.dart';
import '../../providers/app_state_provider.dart';
import '../../core/supabase/auth_repository.dart';
import '../../models/models.dart';
import '../../core/widgets/real_map_widget.dart';
import '../../core/widgets/app_logo.dart';
import '../../core/widgets/route_row.dart';
import '../trips/my_trips_screen.dart';
import '../wallet/wallet_screen.dart';
import '../profile/profile_screen.dart';
import '../profile/captain_edit_info_screen.dart';
import '../support/support_screen.dart';
import '../support/settings_screen.dart';
import 'captain_active_trip_screen.dart';
import 'leaderboard_screen.dart';
import '../onboarding/auth_choice_screen.dart';

class CaptainHomeScreen extends StatefulWidget {
  const CaptainHomeScreen({super.key});

  @override
  State<CaptainHomeScreen> createState() => _CaptainHomeScreenState();
}

class _CaptainHomeScreenState extends State<CaptainHomeScreen> {
  int _currentIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Captain's live distance to the pickup point of the current incoming
  // request, fetched once per request (not on every rebuild).
  String? _distanceTripId;
  double? _distanceFromCaptainKm;

  // Tracks which active trip we've already pushed CaptainActiveTripScreen
  // for, so a rebuild (e.g. every second from the open-ride fare ticker)
  // doesn't push a new copy of the screen on top of the navigation stack
  // each time.
  String? _pushedActiveTripId;

  @override
  void initState() {
    super.initState();
    // Catches a wallet_balance change that happened server-side while this
    // screen wasn't mounted - a Bpay recharge that was still "pending" the
    // last time the app checked and settled afterward, or an admin
    // correction - instead of only ever refreshing right after a recharge
    // attempt.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<AppStateProvider>(
          context,
          listen: false,
        ).refreshWalletBalance();
      }
    });
  }

  Future<void> _loadDistanceFromCaptain(Trip trip) async {
    _distanceTripId = trip.id;
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      final meters = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        trip.pickupLat,
        trip.pickupLng,
      );
      if (!mounted || _distanceTripId != trip.id) return;
      setState(() => _distanceFromCaptainKm = meters / 1000);
    } catch (_) {
      // No GPS available; the distance line just stays hidden.
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppStateProvider>(context);

    // List of screens for bottom navigation
    final List<Widget> screens = [
      _buildDashboardView(provider),
      const MyTripsScreen(showAppBar: false),
      const WalletScreen(showAppBar: false),
      const ProfileScreen(showAppBar: false),
    ];

    // Auto navigate to active trip screen if captain has accepted a trip -
    // only once per trip, not on every rebuild (the fare ticker alone
    // notifies listeners once a second while an open ride is running).
    if (provider.activeTrip != null &&
        _pushedActiveTripId != provider.activeTrip!.id &&
        (provider.activeTrip!.status == TripStatus.accepted ||
            provider.activeTrip!.status == TripStatus.enRoute ||
            provider.activeTrip!.status == TripStatus.arrived ||
            provider.activeTrip!.status == TripStatus.started)) {
      _pushedActiveTripId = provider.activeTrip!.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const CaptainActiveTripScreen(),
          ),
        );
      });
    } else if (provider.activeTrip == null) {
      _pushedActiveTripId = null;
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      drawer: _buildDrawer(provider),
      bottomNavigationBar: _buildBottomNavigationBar(),
      body: screens[_currentIndex],
    );
  }

  Widget _buildDashboardView(AppStateProvider provider) {
    return Stack(
      children: [
        // High fidelity map viewport - shows the route for an incoming
        // request right on the main map behind it, instead of a cramped
        // preview inside the request card itself.
        Positioned.fill(
          child: RealMapWidget(
            showRoute: provider.incomingRequest != null,
            pickupLat: provider.incomingRequest?.pickupLat,
            pickupLng: provider.incomingRequest?.pickupLng,
            destLat: provider.incomingRequest?.destLat,
            destLng: provider.incomingRequest?.destLng,
            // Dim map if captain is offline
            interactive: provider.isCaptainOnline,
          ),
        ),

        // Darkened overlay for offline state
        if (!provider.isCaptainOnline)
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.35)),
          ),

        // Custom Header Bar (+ the low-balance banner right beneath it, see
        // below - kept in the same Positioned/Column so the banner sits
        // directly under the wallet/online-toggle row instead of needing a
        // hardcoded vertical offset).
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.only(
                  top: 50,
                  left: 16,
                  right: 16,
                  bottom: 16,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(
                        provider.isCaptainOnline ? 0.4 : 0.6,
                      ),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                // Hamburger drawer icon
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.menu_rounded,
                      color: AppColors.darkText,
                    ),
                    onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                  ),
                ),

                // Online/Offline status switch badge. Red/green background
                // is untouched either way; while the wallet is empty a
                // small yellow dot is merged onto the pill's corner (no
                // separate banner, no extra text) and tapping it jumps
                // straight to the wallet tab instead of trying to toggle.
                GestureDetector(
                  onTap: () {
                    if (provider.captainWalletBalance <= 0) {
                      setState(() => _currentIndex = 2); // Wallet tab
                      return;
                    }
                    provider.toggleCaptainOnline();
                  },
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: provider.isCaptainOnline
                              ? AppColors.success
                              : AppColors.error,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              provider.isCaptainOnline
                                  ? 'متصل (متاح)'
                                  : 'غير متصل (مغلق)',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Cairo',
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (provider.captainWalletBalance <= 0)
                        Positioned(
                          top: -4,
                          right: -4,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: AppColors.warning,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Wallet balance badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.all(Radius.circular(30)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.account_balance_wallet_rounded,
                        color: AppColors.primaryDark,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${provider.captainWalletBalance.toStringAsFixed(0)} أوقية',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
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
            ],
          ),
        ),

        // Incoming Trip Request overlay dialog (Full screen popup when new request arrives)
        if (provider.incomingRequest != null)
          _buildIncomingRequestOverlay(provider),
      ],
    );
  }

  Widget _buildIncomingRequestOverlay(AppStateProvider provider) {
    final trip = provider.incomingRequest!;
    if (_distanceTripId != trip.id) {
      _distanceFromCaptainKm = null;
      _loadDistanceFromCaptain(trip);
    }

    // Anchored to the bottom like a bottom sheet, instead of a centered
    // dialog over a dark backdrop, so the live route on the main map above
    // it (see _buildDashboardView) stays visible while a request is up.
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 24,
              offset: Offset(0, -6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag-handle affordance marking this as a sheet over the map.
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
                    children: [
                      const AppLogo(width: 28),
                      const SizedBox(width: 8),
                      if (trip.isDelivery) ...[
                        const Icon(
                          Icons.inventory_2_rounded,
                          color: AppColors.primaryDark,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        trip.isDelivery ? 'طلب توصيل جديد' : 'مشوار ركاب جديد',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkText,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${trip.customerName} · تبقّى 00:${provider.countdownSeconds.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.secondaryText,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  if (trip.isDelivery &&
                      (trip.packageDescription?.isNotEmpty ?? false)) ...[
                    const SizedBox(height: 4),
                    Text(
                      'الطرد: ${trip.packageDescription}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDark,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),

                  // Pickup & Destination (delivery: pickup/drop-off points)
                  RouteRow(
                    dotColor: AppColors.success,
                    label: 'من',
                    text: trip.pickupLocation,
                    trailing: _distanceFromCaptainKm == null
                        ? null
                        : 'يبعد عنك ${_distanceFromCaptainKm!.toStringAsFixed(1)} كم',
                  ),
                  const SizedBox(height: 4),
                  RouteRow(
                    dotColor: AppColors.error,
                    label: 'إلى',
                    text: trip.destinationLocation ??
                        'مشوار مفتوح (بدون وجهة محددة)',
                  ),
                  const SizedBox(height: 10),
                  // The route itself is drawn on the main map behind this
                  // card (see _buildDashboardView), so the card only needs
                  // the rest of the request's details below.
                  Container(height: 1, color: AppColors.border),
                  const SizedBox(height: 8),

                  // Details row - an open ride has no known destination, so
                  // there's no real fare/distance/duration estimate to show
                  // yet (it's metered live once the trip starts); just say
                  // what the meter starts at instead of a fake fixed number.
                  if (trip.isOpenRide)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'مشوار مفتوح',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.secondaryText,
                            fontFamily: 'Cairo',
                          ),
                        ),
                        Text(
                          'يبدأ من ${AppStateProvider.openRideMinimumFare.toStringAsFixed(0)} أوقية',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.darkText,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ],
                    )
                  else ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildQuietStat(
                          'المسافة ${trip.distance.toStringAsFixed(1)} كم',
                        ),
                        _buildQuietStat('المدة ${trip.duration} د'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // The fare is the number a captain scans for first, so
                    // it gets its own prominent banner instead of blending
                    // into the small distance/duration stats row.
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'الأجرة',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.secondaryText,
                              fontFamily: 'Cairo',
                            ),
                          ),
                          Text(
                            '${trip.price.toStringAsFixed(0)} أوقية',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryDark,
                              fontFamily: 'Cairo',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => provider.ignoreIncomingRequest(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.secondaryText,
                            side: const BorderSide(color: AppColors.border),
                          ),
                          child: const Text('تجاهل'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final error = await provider
                                .acceptIncomingRequest();
                            // Navigation to Active Trip screen occurs automatically via state listener
                            if (error != null && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    error,
                                    style: const TextStyle(
                                      fontFamily: 'Cairo',
                                    ),
                                  ),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                            }
                          },
                          child: Text(
                            trip.isDelivery ? 'قبول التوصيل' : 'قبول المشوار',
                          ),
                        ),
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuietStat(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        color: AppColors.secondaryText,
        fontFamily: 'Cairo',
      ),
    );
  }

  Widget _buildDrawer(AppStateProvider provider) {
    return Drawer(
      backgroundColor: AppColors.background,
      child: Column(
        children: [
          // Gradient header: avatar (with an edit badge that opens the same
          // screen used to upload a profile photo), name, online/offline
          // pill, and phone - all centered, matching the reference layout.
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
              20,
              MediaQuery.of(context).padding.top + 24,
              20,
              24,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, AppColors.primaryDark],
              ),
            ),
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 92,
                      height: 92,
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      child: ClipOval(
                        child: FutureBuilder<String?>(
                          future: provider.userId == null
                              ? null
                              : AuthRepository().getProfilePhotoUrl(
                                  provider.userId!,
                                ),
                          builder: (context, snapshot) {
                            final url = snapshot.data;
                            if (url == null) {
                              return const ColoredBox(
                                color: AppColors.background,
                                child: Icon(
                                  Icons.person_rounded,
                                  color: AppColors.primary,
                                  size: 44,
                                ),
                              );
                            }
                            return Image.network(url, fit: BoxFit.cover);
                          },
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -2,
                      left: -2,
                      child: GestureDetector(
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) =>
                                  const CaptainEditInfoScreen(),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.primary,
                              width: 1.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.edit_rounded,
                            size: 14,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  provider.captainName,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: provider.isCaptainOnline
                              ? AppColors.success
                              : AppColors.error,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        provider.isCaptainOnline ? 'متصل' : 'غير متصل',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: provider.isCaptainOnline
                              ? AppColors.success
                              : AppColors.error,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  provider.captainPhone,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildDrawerItem(
                  icon: Icons.person_rounded,
                  title: 'الملف الشخصي',
                  subtitle: 'معلوماتك الشخصية',
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const CaptainEditInfoScreen(),
                      ),
                    );
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.wallet_rounded,
                  title: 'المحفظة',
                  subtitle: 'رصيدك وشحن المحفظة',
                  onTap: () {
                    Navigator.of(context).pop();
                    setState(() => _currentIndex = 2); // Wallet tab
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.bar_chart_rounded,
                  title: 'الأرباح',
                  subtitle: 'تفاصيل أرباحك وإحصائياتك',
                  onTap: () {
                    Navigator.of(context).pop();
                    setState(() => _currentIndex = 2); // Wallet tab
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.history_rounded,
                  title: 'الرحلات السابقة',
                  subtitle: 'سجل رحلاتك السابقة',
                  onTap: () {
                    Navigator.of(context).pop();
                    setState(() => _currentIndex = 1); // Trips tab
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.star_rounded,
                  title: 'التقييمات والترتيب',
                  subtitle: 'تقييماتك وترتيبك',
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const LeaderboardScreen(),
                      ),
                    );
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.settings_rounded,
                  title: 'الإعدادات',
                  subtitle: 'إعدادات التطبيق',
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const SettingsScreen(),
                      ),
                    );
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.headset_mic_rounded,
                  title: 'الدعم والمساعدة',
                  subtitle: 'تواصل معنا',
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            const SupportScreen(showAppBar: true),
                      ),
                    );
                  },
                ),
                const Divider(height: 24, indent: 20, endIndent: 20),
                _buildDrawerItem(
                  icon: Icons.logout_rounded,
                  title: 'تسجيل الخروج',
                  subtitle: 'خروج من حسابك',
                  color: AppColors.error,
                  onTap: () {
                    Navigator.of(context).pop();
                    provider.logout();
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (context) => const AuthChoiceScreen(),
                      ),
                      (route) => false,
                    );
                  },
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              // No package_info_plus dependency wired in yet - keep this in
              // sync with pubspec.yaml's version by hand if that changes.
              'الإصدار 1.0.1',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                color: AppColors.secondaryText.withOpacity(0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color color = AppColors.primary,
  }) {
    return ListTile(
      leading: Icon(icon, color: color, size: 24),
      title: Text(
        title,
        style: TextStyle(
          fontFamily: 'Cairo',
          fontWeight: FontWeight.bold,
          fontSize: 14,
          color: color == AppColors.error ? AppColors.error : AppColors.darkText,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontFamily: 'Cairo',
          fontSize: 12,
          color: AppColors.secondaryText,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_left_rounded,
        color: AppColors.secondaryText,
      ),
      onTap: onTap,
    );
  }

  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.secondaryText,
      selectedLabelStyle: const TextStyle(
        fontWeight: FontWeight.bold,
        fontFamily: 'Cairo',
        fontSize: 11,
      ),
      unselectedLabelStyle: const TextStyle(
        fontWeight: FontWeight.normal,
        fontFamily: 'Cairo',
        fontSize: 11,
      ),
      onTap: (index) {
        setState(() {
          _currentIndex = index;
        });
      },
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard_rounded),
          label: 'الرئيسية',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.history_rounded),
          label: 'الرحلات',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.wallet_rounded),
          label: 'المحفظة',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_rounded),
          label: 'الحساب',
        ),
      ],
    );
  }
}
