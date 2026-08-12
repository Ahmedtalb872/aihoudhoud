import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/constants/colors.dart';
import '../../providers/app_state_provider.dart';
import '../../core/supabase/auth_repository.dart';
import '../../models/models.dart';
import '../../core/widgets/real_map_widget.dart';
import '../../core/widgets/app_logo.dart';
import '../../core/widgets/trip_progress_rail.dart';
import '../../core/widgets/route_row.dart';
import '../trips/my_trips_screen.dart';
import '../wallet/wallet_screen.dart';
import '../profile/profile_screen.dart';
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
        // High fidelity map viewport
        Positioned.fill(
          child: RealMapWidget(
            showRoute: false,
            // Dim map if captain is offline
            interactive: provider.isCaptainOnline,
          ),
        ),

        // Darkened overlay for offline state
        if (!provider.isCaptainOnline)
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.35)),
          ),

        // Custom Header Bar
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
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

                // Online/Offline status switch badge
                GestureDetector(
                  onTap: () => provider.toggleCaptainOnline(),
                  child: AnimatedContainer(
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
        ),

        // Status indicator banner
        Positioned(
          top: 110,
          left: 20,
          right: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 6),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(
                      provider.isCaptainOnline
                          ? Icons.check_circle_rounded
                          : Icons.info_outline_rounded,
                      color: provider.isCaptainOnline
                          ? AppColors.success
                          : AppColors.error,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        provider.isCaptainOnline
                            ? 'أنت متاح لاستقبال المشاوير وبث الطلبات القريبة.'
                            : 'قم بتفعيل زر الاتصال بالأعلى لبدء استقبال المشاوير.',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkText,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ),
                  ],
                ),
                // Delivery-mode toggle - only for motorcycle captains, car
                // captains never see this and never receive delivery
                // requests. Kept in the same flowing container as the
                // status row above it so it can never overlap other
                // absolutely-positioned elements.
                if (provider.isMotorcycleCaptain) ...[
                  const Divider(height: 20),
                  Row(
                    children: [
                      Icon(
                        Icons.inventory_2_rounded,
                        color: provider.deliveryModeEnabled
                            ? AppColors.primaryDark
                            : AppColors.secondaryText,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'قبول طلبات توصيل',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.darkText,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ),
                      Switch(
                        value: provider.deliveryModeEnabled,
                        activeColor: AppColors.primaryDark,
                        onChanged: (_) => provider.toggleDeliveryMode(),
                      ),
                    ],
                  ),
                ],
              ],
            ),
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

    return Positioned.fill(
      child: Container(
        color: Colors.black54, // Translucent dark backdrop
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 20),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const TripProgressRail(step: 1),
                  const SizedBox(height: 14),
                  Row(
                    children: [
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
                  const SizedBox(height: 16),

                  // Pickup & Destination (delivery: pickup/drop-off points)
                  RouteRow(
                    dotColor: AppColors.success,
                    label: 'من',
                    text: trip.pickupLocation,
                    trailing: _distanceFromCaptainKm == null
                        ? null
                        : 'يبعد عنك ${_distanceFromCaptainKm!.toStringAsFixed(1)} كم',
                  ),
                  const SizedBox(height: 6),
                  RouteRow(
                    dotColor: AppColors.error,
                    label: 'إلى',
                    text: trip.destinationLocation ??
                        'مشوار مفتوح (بدون وجهة محددة)',
                  ),
                  const SizedBox(height: 14),

                  // Map preview of pickup & destination points
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      height: 130,
                      child: RealMapWidget(
                        showRoute: true,
                        pickupLat: trip.pickupLat,
                        pickupLng: trip.pickupLng,
                        destLat: trip.destLat,
                        destLng: trip.destLng,
                        interactive: false,
                        showControls: false,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(height: 1, color: AppColors.border),
                  const SizedBox(height: 12),

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
                          'يبدأ من ${AppStateProvider.openRideBaseFare.toStringAsFixed(0)} أوقية',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.darkText,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildQuietStat('المسافة ${trip.distance} كم'),
                        _buildQuietStat('المدة ${trip.duration} د'),
                        _buildQuietStat(
                          'الأجرة ${trip.price} أوقية',
                          emphasize: true,
                        ),
                      ],
                    ),
                  const SizedBox(height: 20),

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
                          onPressed: () {
                            provider.acceptIncomingRequest();
                            // Navigation to Active Trip screen occurs automatically via state listener
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
          ],
        ),
      ),
    );
  }

  Widget _buildQuietStat(String text, {bool emphasize = false}) {
    return Text(
      text,
      style: TextStyle(
        fontSize: emphasize ? 13 : 12,
        fontWeight: emphasize ? FontWeight.bold : FontWeight.normal,
        color: emphasize ? AppColors.darkText : AppColors.secondaryText,
        fontFamily: 'Cairo',
      ),
    );
  }

  Widget _buildDrawer(AppStateProvider provider) {
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: AppColors.primary),
            currentAccountPicture: FutureBuilder<String?>(
              future: provider.userId == null
                  ? null
                  : AuthRepository().getProfilePhotoUrl(provider.userId!),
              builder: (context, snapshot) {
                final url = snapshot.data;
                if (url == null) {
                  return const CircleAvatar(
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.person_rounded,
                      color: AppColors.primary,
                      size: 32,
                    ),
                  );
                }
                return CircleAvatar(
                  backgroundImage: NetworkImage(url),
                  backgroundColor: Colors.white,
                );
              },
            ),
            otherAccountsPictures: const [
              Padding(padding: EdgeInsets.all(6.0), child: AppLogo(width: 40)),
            ],
            accountName: Text(
              provider.captainName,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppColors.darkText,
              ),
            ),
            accountEmail: Text(
              provider.captainPhone,
              style: const TextStyle(fontSize: 13, color: AppColors.darkText),
            ),
          ),

          ListTile(
            leading: const Icon(Icons.wallet_rounded, color: AppColors.primary),
            title: const Text(
              'الأرباح والمحفظة',
              style: TextStyle(fontFamily: 'Cairo'),
            ),
            onTap: () {
              Navigator.of(context).pop();
              setState(() {
                _currentIndex = 2; // Wallet tab
              });
            },
          ),
          ListTile(
            leading: const Icon(
              Icons.emoji_events_rounded,
              color: AppColors.primary,
            ),
            title: const Text(
              'المسابقات وترتيب الكباتنة',
              style: TextStyle(fontFamily: 'Cairo'),
            ),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const LeaderboardScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(
              Icons.history_rounded,
              color: AppColors.primary,
            ),
            title: const Text(
              'سجل رحلات كابتن',
              style: TextStyle(fontFamily: 'Cairo'),
            ),
            onTap: () {
              Navigator.of(context).pop();
              setState(() {
                _currentIndex = 1; // Trips tab
              });
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: AppColors.error),
            title: const Text(
              'تسجيل الخروج',
              style: TextStyle(fontFamily: 'Cairo', color: AppColors.error),
            ),
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
