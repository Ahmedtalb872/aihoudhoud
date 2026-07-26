import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/constants/colors.dart';
import '../../providers/app_state_provider.dart';
import '../../core/widgets/real_map_widget.dart';
import '../support/chat_screen.dart';
import 'cancel_trip_dialog.dart';

/// Shown once a captain is driving an open ride (no known destination): a
/// live map, a running fare meter, and a manual "end trip" action instead of
/// the fixed-destination flow in CaptainActiveTripScreen.
class OpenRideActiveScreen extends StatefulWidget {
  const OpenRideActiveScreen({super.key});

  @override
  State<OpenRideActiveScreen> createState() => _OpenRideActiveScreenState();
}

class _OpenRideActiveScreenState extends State<OpenRideActiveScreen> {
  StreamSubscription<Position>? _positionSub;
  double _distanceKm = 0.0;
  double? _lastLat;
  double? _lastLng;
  double? _carLat;
  double? _carLng;

  @override
  void initState() {
    super.initState();
    _startTrackingDistance();
  }

  Future<void> _startTrackingDistance() async {
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

      _positionSub =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 10,
            ),
          ).listen((position) {
            if (!mounted) return;
            if (_lastLat != null && _lastLng != null) {
              final meters = Geolocator.distanceBetween(
                _lastLat!,
                _lastLng!,
                position.latitude,
                position.longitude,
              );
              _distanceKm += meters / 1000;
            }
            setState(() {
              _lastLat = position.latitude;
              _lastLng = position.longitude;
              _carLat = position.latitude;
              _carLng = position.longitude;
            });
            if (mounted) {
              Provider.of<AppStateProvider>(
                context,
                listen: false,
              ).updateOpenRideDistance(_distanceKm);
            }
          });
    } catch (_) {
      // No GPS available in this environment; distance just stays at 0.
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
  }

  void _simulateCall(String name) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            'اتصال هاتفي',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          content: Text(
            'جاري الاتصال بـ $name...',
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
            textAlign: TextAlign.center,
          ),
          actions: [
            Center(
              child: ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                ),
                icon: const Icon(Icons.call_end_rounded),
                label: const Text('إنهاء المكالمة'),
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatElapsed(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    // Read (not listen): the live fare/time ticker fires every second, and
    // listening here would rebuild the whole screen - including the map -
    // on every tick, which is what made the map look like it was jittering.
    final provider = Provider.of<AppStateProvider>(context, listen: false);
    final trip = provider.activeTrip;
    if (trip == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  RealMapWidget(
                    pickupLat: trip.pickupLat,
                    pickupLng: trip.pickupLng,
                    carLat: _carLat,
                    carLng: _carLng,
                  ),

                  // Live fare badge - the only part that needs to redraw
                  // every second, so it's isolated from the map above.
                  Positioned(
                    top: 16,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Consumer<AppStateProvider>(
                        builder: (context, provider, _) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.darkText,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: const [
                              BoxShadow(color: Colors.black26, blurRadius: 8),
                            ],
                          ),
                          child: Text(
                            '${provider.openRideFare.toStringAsFixed(0)} أوقية',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              fontFamily: 'Cairo',
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Cancel trip button
                  Positioned(
                    right: 16,
                    top: 16,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black26, blurRadius: 6),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: AppColors.error,
                        ),
                        onPressed: () => showCancelTripDialog(context),
                      ),
                    ),
                  ),

                  // Live stats stack - same isolation as the fare badge above.
                  Positioned(
                    left: 16,
                    top: 72,
                    child: Consumer<AppStateProvider>(
                      builder: (context, provider, _) => Column(
                        children: [
                          _buildStatChip(
                            provider.openRideFare.toStringAsFixed(0),
                            'أوقية',
                          ),
                          const SizedBox(height: 8),
                          _buildStatChip(_distanceKm.toStringAsFixed(1), 'كم'),
                          const SizedBox(height: 8),
                          _buildStatChip(
                            _formatElapsed(provider.openRideElapsed),
                            'الوقت',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom control board
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
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: const Text(
                          'مشوار مفتوح',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'كود: ${trip.id.length > 8 ? trip.id.substring(trip.id.length - 8) : trip.id}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  Row(
                    children: [
                      const Icon(
                        Icons.radio_button_checked_rounded,
                        color: AppColors.success,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
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
                              trip.pickupLocation,
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
                  const Divider(height: 24),

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
                        onPressed: () => _simulateCall(trip.customerName),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  ElevatedButton(
                    onPressed: () => provider.captainCompleteOpenRide(
                      distanceKm: _distanceKm,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.darkText,
                    ),
                    child: const Text('إنهاء الرحلة'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(String value, String label) {
    return Container(
      width: 64,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: AppColors.darkText,
              fontFamily: 'Cairo',
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              color: AppColors.secondaryText,
              fontFamily: 'Cairo',
            ),
          ),
        ],
      ),
    );
  }
}
