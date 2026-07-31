import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../providers/app_state_provider.dart';
import '../../models/models.dart';
import '../../core/widgets/real_map_widget.dart';
import '../../core/widgets/trip_progress_rail.dart';
import '../../core/widgets/route_row.dart';
import '../../core/services/phone_caller.dart';
import '../support/chat_screen.dart';
import 'captain_trip_summary_screen.dart';
import 'open_ride_active_screen.dart';
import 'cancel_trip_dialog.dart';

class CaptainActiveTripScreen extends StatelessWidget {
  const CaptainActiveTripScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppStateProvider>(context);
    final trip = provider.activeTrip;

    if (trip == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.check_circle_rounded,
                size: 48,
                color: AppColors.success,
              ),
              const SizedBox(height: 16),
              const Text(
                'تم إكمال المشوار بنجاح!',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('الرجوع للرئيسية'),
              ),
            ],
          ),
        ),
      );
    }

    // Auto transition to Trip Summary screen once completed
    if (trip.status == TripStatus.completed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const CaptainTripSummaryScreen(),
          ),
        );
      });
    }

    // Open rides have no known destination: once the customer boards, hand
    // off to the live-meter screen instead of "en route to a destination".
    if (trip.status == TripStatus.started && trip.isOpenRide) {
      return const OpenRideActiveScreen();
    }

    // Determine state visual details
    String statusTitle = 'توجه إلى نقطة الانطلاق';
    String actionLabel = 'وصلت للزبون';
    IconData actionIcon = Icons.sports_motorsports_rounded;
    VoidCallback onAction = () => provider.captainArriveAtPickup();
    int progressStep = 2;

    if (trip.status == TripStatus.arrived) {
      statusTitle = 'وصلت لموقع العميل';
      actionLabel = 'بدء الرحلة الجارية';
      actionIcon = Icons.play_arrow_rounded;
      onAction = () => provider.captainStartActiveTrip();
      progressStep = 3;
    } else if (trip.status == TripStatus.started) {
      statusTitle = 'مشوار جاري الآن نحو الوجهة';
      actionLabel = 'إنهاء الرحلة بنجاح';
      actionIcon = Icons.flag_rounded;
      onAction = () => provider.captainCompleteActiveTrip();
      progressStep = 4;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(statusTitle),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: () => showCancelTripDialog(context),
            child: const Text(
              'إلغاء المشوار',
              style: TextStyle(color: AppColors.error, fontFamily: 'Cairo'),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Map viewport
            Expanded(
              child: Stack(
                children: [
                  RealMapWidget(
                    showRoute: true,
                    status: trip.status,
                    pickupLat: trip.pickupLat,
                    pickupLng: trip.pickupLng,
                    destLat: trip.destLat,
                    destLng: trip.destLng,
                    animateCar: true,
                  ),

                  // Float ETA indicator
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 4),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${trip.distance} كم',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppColors.primary,
                            ),
                          ),
                          const Text(
                            'المسافة الكلية',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.secondaryText,
                              fontFamily: 'Cairo',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Sheet control board
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TripProgressRail(step: progressStep),
                  const SizedBox(height: 20),

                  // Pickup & destination, each on its own line.
                  RouteRow(dotColor: AppColors.success, text: trip.pickupLocation),
                  const SizedBox(height: 6),
                  RouteRow(
                    dotColor: AppColors.error,
                    text: trip.destinationLocation ?? 'غير محددة',
                  ),
                  const Divider(height: 24),

                  // Customer details and actions row
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.primary,
                        child: Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              trip.customerName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                fontFamily: 'Cairo',
                              ),
                            ),
                            Text(
                              trip.customerPhone,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.chat_bubble_outline_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) =>
                                  const ChatScreen(showAppBar: true),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.call_outlined,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        onPressed: () => PhoneCaller.call(trip.customerPhone),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Status change confirm action button
                  ElevatedButton(
                    onPressed: onAction,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(actionLabel),
                        const SizedBox(width: 8),
                        Icon(actionIcon),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
