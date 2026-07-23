import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../providers/app_state_provider.dart';
import '../../models/models.dart';
import '../../core/widgets/real_map_widget.dart';

class OpenTripsScreen extends StatefulWidget {
  final bool showAppBar;
  const OpenTripsScreen({super.key, this.showAppBar = false});

  @override
  State<OpenTripsScreen> createState() => _OpenTripsScreenState();
}

class _OpenTripsScreenState extends State<OpenTripsScreen> {
  // Local list of active open rides
  List<Map<String, dynamic>> _openRides = [];
  Timer? _tickerTimer;

  @override
  void initState() {
    super.initState();
    // Initialize with 2 dummy open rides
    _openRides = [
      {
        'id': 'open_t1',
        'customerName': 'سيدي ولد المختار',
        'customerPhone': '+22246667777',
        'pickup': 'لكصر (كارفور ولد أماه)',
        'pickupLat': 18.0982,
        'pickupLng': -15.9592,
        'payment': 'نقداً',
        'timeLeft': 38,
      },
      {
        'id': 'open_t2',
        'customerName': 'زينب منت اعل',
        'customerPhone': '+22248889999',
        'pickup': 'عرفات (كارفور مدريد)',
        'pickupLat': 18.0435,
        'pickupLng': -15.9521,
        'payment': 'Bankily',
        'timeLeft': 52,
      },
    ];

    // Start local timer to tick down durations
    _tickerTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          for (var ride in _openRides) {
            if (ride['timeLeft'] > 0) {
              ride['timeLeft']--;
            }
          }
          // Remove rides that expired (0 seconds)
          _openRides.removeWhere((r) => r['timeLeft'] <= 0);
        });
      }
    });
  }

  @override
  void dispose() {
    _tickerTimer?.cancel();
    super.dispose();
  }

  void _acceptOpenTrip(Map<String, dynamic> rideData) {
    final provider = Provider.of<AppStateProvider>(context, listen: false);

    // Simulate accepting the open ride. No destination or fixed price: the
    // fare is metered live once the customer boards (see openRideFare).
    provider.requestTrip(
      customerName: rideData['customerName'],
      customerPhone: rideData['customerPhone'],
      pickup: rideData['pickup'],
      pickupLat: rideData['pickupLat'],
      pickupLng: rideData['pickupLng'],
      distance: 0,
      duration: 0,
      price: AppStateProvider.openRideBaseFare,
      carType: VehicleType.economy,
      isOpenRide: true,
      timeoutSeconds: 45,
      paymentMethod: rideData['payment'],
    );

    // Switch state from customer searching to accepted immediately
    provider.acceptIncomingRequest();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'تم قبول المشوار بنجاح! جاري التوجه إلى الزبون: ${rideData['customerName']}',
          style: const TextStyle(fontFamily: 'Cairo'),
        ),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: widget.showAppBar
          ? AppBar(title: const Text('المشاوير المفتوحة للجميع'))
          : AppBar(
              title: const Text('المشاوير المفتوحة'),
              automaticallyImplyLeading: false,
            ),
      body: _openRides.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.hourglass_empty_rounded,
                      color: AppColors.primary,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'لا توجد مشاوير مفتوحة حالياً',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkText,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'انتظر، ستظهر الطلبات الجديدة هنا فوراً.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.secondaryText,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(24.0),
              itemCount: _openRides.length,
              itemBuilder: (context, index) {
                final ride = _openRides[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header metadata (customer name and time left)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'الزبون: ${ride['customerName']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: AppColors.darkText,
                                fontFamily: 'Cairo',
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.error.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.timer_outlined,
                                    color: AppColors.error,
                                    size: 12,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'تبقي ${ride['timeLeft']} ثانية',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.error,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),

                        // Pickup point (no destination: it's an open ride)
                        Row(
                          children: [
                            const Icon(
                              Icons.radio_button_checked_rounded,
                              color: AppColors.success,
                              size: 16,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'من',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: AppColors.secondaryText,
                                      fontFamily: 'Cairo',
                                    ),
                                  ),
                                  Text(
                                    ride['pickup'],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: AppColors.darkText,
                                      fontFamily: 'Cairo',
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Map preview of the pickup point only
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: SizedBox(
                            height: 120,
                            child: RealMapWidget(
                              pickupLat: ride['pickupLat'],
                              pickupLng: ride['pickupLng'],
                              interactive: false,
                              showControls: false,
                            ),
                          ),
                        ),
                        const Divider(height: 24),

                        // Fare & payment info
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'مشوار مفتوح',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.secondaryText,
                                    fontFamily: 'Cairo',
                                  ),
                                ),
                                Text(
                                  'يبدأ من ${AppStateProvider.openRideBaseFare.toStringAsFixed(0)} أوقية',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                    fontFamily: 'Cairo',
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  'الدفع',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.secondaryText,
                                    fontFamily: 'Cairo',
                                  ),
                                ),
                                Text(
                                  ride['payment'],
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.darkText,
                                    fontFamily: 'Cairo',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Divider(height: 24),

                        // Action buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'مشوار مفتوح من ${ride['pickup']} — بدون وجهة محددة، السعر يُحسب حسب الوقت.',
                                        style: const TextStyle(
                                          fontFamily: 'Cairo',
                                        ),
                                      ),
                                      backgroundColor: AppColors.primary,
                                    ),
                                  );
                                },
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(double.infinity, 40),
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  'عرض التفاصيل',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => _acceptOpenTrip(ride),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.success,
                                  minimumSize: const Size(double.infinity, 40),
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  'قبول المشوار',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
