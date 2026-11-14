import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/models.dart';
import '../constants/colors.dart';
import '../services/directions_service.dart';

class RealMapWidget extends StatefulWidget {
  final TripStatus? status;
  final bool showRoute;
  final double? pickupLat;
  final double? pickupLng;
  final double? destLat;
  final double? destLng;
  // The captain's real live GPS fix (see AppStateProvider.myLat/myLng, or an
  // open ride's own position stream) - shown as the car marker and, once a
  // trip is under way, used as the route's starting point instead of the
  // pickup point, so both match where the captain actually is.
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

class _RealMapWidgetState extends State<RealMapWidget> {
  GoogleMapController? _mapController;
  LatLng _currentCenter = const LatLng(18.0858, -15.9785); // Nouakchott center
  bool _isLoadingLocation = false;
  bool _myLocationEnabled = false;

  // Real road-following route fetched from Directions API, replacing the
  // straight-line fallback once it loads. Null while loading or if no
  // widget.routePolyline was supplied and there's nothing to fetch yet.
  List<LatLng>? _fetchedRoute;
  // Only true once a fetch has actually come back empty/failed - the
  // straight-line fallback is reserved for that, not for the ordinary
  // couple of seconds it takes the real route to arrive.
  bool _routeFetchFailed = false;

  // What the last (successful or in-flight) fetch was for - re-fetching on
  // every single GPS update while driving would hammer the Directions API
  // for a route that's barely changed; only the endpoints' reference
  // (destination swap) or a real amount of movement should trigger another
  // call. See _fetchRouteIfNeeded.
  LatLng? _lastFetchOrigin;
  LatLng? _lastFetchDestination;
  static const double _minMetersBeforeRefetch = 120;

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

    _fetchRouteIfNeeded();
  }

  // The route's real origin/destination for the trip's current phase -
  // heading to the passenger routes from the captain's live position to
  // the pickup point; once the trip is under way it routes from the
  // captain's live position to the actual destination. Falls back to the
  // plain pickup->destination overview (no live fix yet, or this is just
  // an incoming-request preview with no status/car at all).
  ({LatLng origin, LatLng destination})? _routeEndpoints() {
    if (!widget.showRoute) return null;
    final hasCar = widget.carLat != null && widget.carLng != null;
    final hasPickup = widget.pickupLat != null && widget.pickupLng != null;
    final hasDest = widget.destLat != null && widget.destLng != null;
    final headingToPickup =
        widget.status == TripStatus.accepted ||
        widget.status == TripStatus.enRoute;
    final tripUnderWay =
        widget.status == TripStatus.arrived ||
        widget.status == TripStatus.started;

    if (hasCar && headingToPickup && hasPickup) {
      return (
        origin: LatLng(widget.carLat!, widget.carLng!),
        destination: LatLng(widget.pickupLat!, widget.pickupLng!),
      );
    }
    if (hasCar && tripUnderWay && hasDest) {
      return (
        origin: LatLng(widget.carLat!, widget.carLng!),
        destination: LatLng(widget.destLat!, widget.destLng!),
      );
    }
    if (hasPickup && hasDest) {
      return (
        origin: LatLng(widget.pickupLat!, widget.pickupLng!),
        destination: LatLng(widget.destLat!, widget.destLng!),
      );
    }
    return null;
  }

  void _fetchRouteIfNeeded() {
    if (widget.routePolyline != null) return; // caller already supplied one
    final endpoints = _routeEndpoints();
    if (endpoints == null) return;

    final lastOrigin = _lastFetchOrigin;
    final lastDest = _lastFetchDestination;
    if (lastOrigin != null && lastDest != null) {
      final sameDestination =
          lastDest.latitude == endpoints.destination.latitude &&
          lastDest.longitude == endpoints.destination.longitude;
      final movedMeters = Geolocator.distanceBetween(
        lastOrigin.latitude,
        lastOrigin.longitude,
        endpoints.origin.latitude,
        endpoints.origin.longitude,
      );
      if (sameDestination && movedMeters < _minMetersBeforeRefetch) {
        return; // Barely moved since the last fetch - not worth another call.
      }
    }

    _lastFetchOrigin = endpoints.origin;
    _lastFetchDestination = endpoints.destination;
    DirectionsService.fetchRoute(
      originLat: endpoints.origin.latitude,
      originLng: endpoints.origin.longitude,
      destLat: endpoints.destination.latitude,
      destLng: endpoints.destination.longitude,
    ).then((route) {
      if (!mounted) return;
      if (route == null || route.isEmpty) {
        setState(() => _routeFetchFailed = true);
      } else {
        setState(() {
          _fetchedRoute = route;
          _routeFetchFailed = false;
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant RealMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Auto-center map when the pickup/destination pair itself changes (a
    // different request/trip) - fit both when there's a route to show,
    // otherwise just zoom to the pickup point on its own. Not triggered by
    // every carLat/carLng tick - panning the camera out from under a
    // captain who's mid-pinch-zoom on their own position would be worse
    // than leaving it where they left it.
    final locationsChanged =
        oldWidget.pickupLat != widget.pickupLat ||
        oldWidget.pickupLng != widget.pickupLng ||
        oldWidget.destLat != widget.destLat ||
        oldWidget.destLng != widget.destLng;
    // The route's effective endpoints also change when the trip moves
    // between phases (heading to pickup -> under way) even though
    // pickup/dest themselves didn't - that's worth both a re-fit and
    // discarding the stale route immediately (not just waiting for the
    // movement-based refetch, since the destination itself just swapped).
    final phaseChanged = oldWidget.status != widget.status;

    if (locationsChanged) {
      final bounds = _boundsForRoute();
      if (bounds != null) {
        _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60));
      } else if (widget.pickupLat != null && widget.pickupLng != null) {
        final newLoc = LatLng(widget.pickupLat!, widget.pickupLng!);
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(newLoc, 14.0));
      }
    }
    if (locationsChanged || phaseChanged) {
      // Stale route from the old endpoints - clear it and fetch again.
      // No fallback line while this is in flight; _routeFetchFailed only
      // flips back on if this fetch fails.
      _fetchedRoute = null;
      _routeFetchFailed = false;
      _lastFetchOrigin = null;
      _lastFetchDestination = null;
    }
    _fetchRouteIfNeeded();
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
                  fontFamily: 'El Messiri',
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
                style: TextStyle(fontFamily: 'El Messiri', fontWeight: FontWeight.bold),
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
                style: TextStyle(fontFamily: 'El Messiri', fontWeight: FontWeight.bold),
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

  // Bounds covering the route's actual current endpoints (see
  // _routeEndpoints) - the captain's live position and wherever they're
  // headed right now - so the camera fits what's actually being
  // navigated, not always the pickup/destination pair regardless of trip
  // phase.
  LatLngBounds? _boundsForRoute() {
    final endpoints = _routeEndpoints();
    if (endpoints == null) return null;
    final lats = [endpoints.origin.latitude, endpoints.destination.latitude]
      ..sort();
    final lngs = [endpoints.origin.longitude, endpoints.destination.longitude]
      ..sort();
    return LatLngBounds(
      southwest: LatLng(lats.first, lngs.first),
      northeast: LatLng(lats.last, lngs.last),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Prefer a caller-supplied route, then the real road-following route
    // fetched from Directions API. No line shows while that fetch is still
    // in flight - the straight-line fallback is reserved for when it
    // actually fails, not for the couple of seconds it normally takes.
    List<LatLng> polylinePoints = widget.routePolyline ?? _fetchedRoute ?? [];
    if (polylinePoints.isEmpty && _routeFetchFailed) {
      final endpoints = _routeEndpoints();
      if (endpoints != null) {
        polylinePoints = [endpoints.origin, endpoints.destination];
      }
    }

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: _currentCenter,
            zoom: 13.0,
          ),
          onMapCreated: (controller) {
            _mapController = controller;
            final bounds = _boundsForRoute();
            if (bounds != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                try {
                  await controller.animateCamera(
                    CameraUpdate.newLatLngBounds(bounds, 60),
                  );
                } catch (_) {
                  // Map view may not have finished laying out yet on the
                  // very first frame; it's already centered on the pickup
                  // point as a reasonable fallback.
                }
              });
            }
          },
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

    // The captain's real live position - absent entirely (no fallback
    // simulation) until an actual GPS fix comes in from the caller, so this
    // never shows a car somewhere the captain isn't really at.
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
    }

    return markers;
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
