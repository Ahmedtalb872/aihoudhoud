import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/models.dart';
import '../constants/colors.dart';

class RealMapWidget extends StatefulWidget {
  final TripStatus? status;
  final bool showRoute;
  final bool animateCar;
  final double? pickupLat;
  final double? pickupLng;
  final double? destLat;
  final double? destLng;
  final double? carLat;
  final double? carLng;
  final List<LatLng>? routePolyline;
  final void Function(LatLng)? onMapTap;
  final bool interactive;
  final bool showControls;

  const RealMapWidget({
    super.key,
    this.status,
    this.showRoute = false,
    this.animateCar = false,
    this.pickupLat,
    this.pickupLng,
    this.destLat,
    this.destLng,
    this.carLat,
    this.carLng,
    this.routePolyline,
    this.onMapTap,
    this.interactive = true,
    this.showControls = true,
  });

  @override
  State<RealMapWidget> createState() => _RealMapWidgetState();
}

class _RealMapWidgetState extends State<RealMapWidget>
    with SingleTickerProviderStateMixin {
  GoogleMapController? _mapController;
  LatLng _currentCenter = const LatLng(18.0858, -15.9785); // Nouakchott center
  bool _isLoadingLocation = false;
  bool _myLocationEnabled = false;

  late AnimationController _carController;
  late Animation<double> _carAnimation;

  @override
  void initState() {
    super.initState();
    // If a pickup point was given, center on it directly - don't fetch the
    // device's own GPS position and jump there instead, which pushed the
    // pickup pin off-screen a moment after this first rendered.
    if (widget.pickupLat != null && widget.pickupLng != null) {
      _currentCenter = LatLng(widget.pickupLat!, widget.pickupLng!);
      _enableMyLocationIfPermitted();
    } else {
      _determinePosition();
    }

    _carController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    );

    _carAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _carController, curve: Curves.easeInOut));

    if (widget.animateCar) {
      _carController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant RealMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animateCar != oldWidget.animateCar) {
      if (widget.animateCar) {
        _carController.repeat();
      } else {
        _carController.stop();
      }
    }

    // Auto-center map if new locations are provided
    if (widget.pickupLat != null && widget.pickupLng != null) {
      final newLoc = LatLng(widget.pickupLat!, widget.pickupLng!);
      if (oldWidget.pickupLat != widget.pickupLat ||
          oldWidget.pickupLng != widget.pickupLng) {
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(newLoc, 14.0));
      }
    }
  }

  @override
  void dispose() {
    _carController.dispose();
    super.dispose();
  }

  // Only turns on the blue "my location" dot if permission is already
  // granted - doesn't move the camera, since a pickup point was given.
  Future<void> _enableMyLocationIfPermitted() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (!mounted) return;
      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        setState(() => _myLocationEnabled = true);
      }
    } catch (_) {
      // Leave the "my location" layer off if permissions can't be resolved.
    }
  }

  Future<void> _determinePosition() async {
    if (!mounted) return;
    setState(() => _isLoadingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) setState(() => _isLoadingLocation = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) setState(() => _isLoadingLocation = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _isLoadingLocation = false);
        return;
      }

      Position position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _currentCenter = LatLng(position.latitude, position.longitude);
          _myLocationEnabled = true;
          _isLoadingLocation = false;
        });
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(_currentCenter, 14.0),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  // Opens turn-by-turn navigation in the native Google Maps app (or its web
  // fallback) - our own map only shows the route, it doesn't drive the
  // captain there.
  Future<void> _openExternalNavigation(double lat, double lng) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _showNavigationChoice() {
    final hasPickup = widget.pickupLat != null && widget.pickupLng != null;
    final hasDest = widget.destLat != null && widget.destLng != null;

    if (hasPickup && !hasDest) {
      _openExternalNavigation(widget.pickupLat!, widget.pickupLng!);
      return;
    }
    if (hasDest && !hasPickup) {
      _openExternalNavigation(widget.destLat!, widget.destLng!);
      return;
    }
    if (!hasPickup && !hasDest) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Text(
                'التوجه عبر خرائط غوغل',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkText,
                  fontFamily: 'Cairo',
                ),
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.radio_button_checked_rounded,
                color: AppColors.success,
              ),
              title: const Text(
                'نقطة البداية',
                style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
              ),
              onTap: () {
                Navigator.of(context).pop();
                _openExternalNavigation(widget.pickupLat!, widget.pickupLng!);
              },
            ),
            ListTile(
              leading: const Icon(Icons.flag_rounded, color: AppColors.error),
              title: const Text(
                'نقطة النهاية',
                style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
              ),
              onTap: () {
                Navigator.of(context).pop();
                _openExternalNavigation(widget.destLat!, widget.destLng!);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // If no route provided but we have pickup/destination and want to show route
    List<LatLng> polylinePoints = widget.routePolyline ?? [];
    if (polylinePoints.isEmpty &&
        widget.showRoute &&
        widget.pickupLat != null &&
        widget.destLat != null) {
      polylinePoints = [
        LatLng(widget.pickupLat!, widget.pickupLng!),
        LatLng(widget.destLat!, widget.destLng!),
      ];
    }

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: _currentCenter,
            zoom: 13.0,
          ),
          onMapCreated: (controller) => _mapController = controller,
          markers: _buildMarkers(),
          polylines: polylinePoints.isEmpty
              ? const {}
              : {
                  Polyline(
                    polylineId: const PolylineId('route'),
                    points: polylinePoints,
                    width: 4,
                    color: AppColors.primary,
                  ),
                },
          onTap: widget.interactive ? widget.onMapTap : null,
          myLocationEnabled: _myLocationEnabled,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          zoomGesturesEnabled: widget.interactive,
          scrollGesturesEnabled: widget.interactive,
          rotateGesturesEnabled: widget.interactive,
          tiltGesturesEnabled: widget.interactive,
        ),

        // Map controls (location, navigation) - zooming is still available
        // via the standard pinch gesture on the map itself.
        if (widget.showControls)
          Positioned(
            left: 16,
            bottom: 150, // Keep above bottom sheets
            child: Column(
              children: [
                _buildMapButton(
                  _isLoadingLocation
                      ? Icons.hourglass_empty
                      : Icons.my_location,
                  _determinePosition,
                ),
                if ((widget.pickupLat != null && widget.pickupLng != null) ||
                    (widget.destLat != null && widget.destLng != null)) ...[
                  const SizedBox(height: 8),
                  _buildMapButton(
                    Icons.alt_route_rounded,
                    _showNavigationChoice,
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};

    if (widget.pickupLat != null && widget.pickupLng != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: LatLng(widget.pickupLat!, widget.pickupLng!),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
        ),
      );
    }

    if (widget.destLat != null && widget.destLng != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: LatLng(widget.destLat!, widget.destLng!),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueRed,
          ),
        ),
      );
    }

    if (widget.carLat != null && widget.carLng != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('car'),
          position: LatLng(widget.carLat!, widget.carLng!),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueOrange,
          ),
        ),
      );
    } else if (widget.showRoute &&
        widget.pickupLat != null &&
        widget.destLat != null) {
      // Animate a simulated car between pickup and destination
      markers.add(
        Marker(
          markerId: const MarkerId('car'),
          position: _getSimulatedCarLocation(),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueOrange,
          ),
        ),
      );
    }

    return markers;
  }

  LatLng _getSimulatedCarLocation() {
    if (widget.pickupLat == null || widget.destLat == null) {
      return _currentCenter;
    }

    double t = _carAnimation.value;

    if (widget.status == TripStatus.started) {
      // Move from pickup to destination
      double lat =
          widget.pickupLat! + (widget.destLat! - widget.pickupLat!) * t;
      double lng =
          widget.pickupLng! + (widget.destLng! - widget.pickupLng!) * t;
      return LatLng(lat, lng);
    } else if (widget.status == TripStatus.accepted ||
        widget.status == TripStatus.enRoute) {
      // Simulate coming to pickup
      double fakeStartLat = widget.pickupLat! - 0.01;
      double fakeStartLng = widget.pickupLng! - 0.01;
      double lat = fakeStartLat + (widget.pickupLat! - fakeStartLat) * t;
      double lng = fakeStartLng + (widget.pickupLng! - fakeStartLng) * t;
      return LatLng(lat, lng);
    }

    return LatLng(widget.pickupLat!, widget.pickupLng!);
  }

  Widget _buildMapButton(IconData icon, VoidCallback onTap) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: AppColors.darkText, size: 20),
        onPressed: onTap,
      ),
    );
  }
}
