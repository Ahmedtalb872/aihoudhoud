import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/district_colors.dart';
import '../../models/district_models.dart';
import '../../data/nouakchott_districts_data.dart';
import '../../providers/app_state_provider.dart';
import 'widgets/district_places_sheet.dart';
import 'manual_pin_selection_screen.dart';
import 'trip_details_screen.dart';

enum _SelectionTarget { pickup, destination }

class _SelectedPoint {
  final String label;
  final LatLng position;
  const _SelectedPoint({required this.label, required this.position});
}

class RideMapSelectionScreen extends StatefulWidget {
  const RideMapSelectionScreen({super.key});

  @override
  State<RideMapSelectionScreen> createState() => _RideMapSelectionScreenState();
}

class _RideMapSelectionScreenState extends State<RideMapSelectionScreen> {
  static const LatLng _nouakchottCenter = LatLng(18.0858, -15.9785);
  static const _homePoint = _SelectedPoint(label: 'المنزل - تفرغ زينة (مجمع البيت)', position: LatLng(18.1025, -15.9754));
  static const _workPoint = _SelectedPoint(label: 'العمل - لكصر (سوق العاصمة)', position: LatLng(18.0878, -15.9789));

  final MapController _mapController = MapController();
  final _searchController = TextEditingController();
  final Distance _distanceCalc = const Distance();

  List<District> _districts = [];
  bool _loadingDistricts = true;
  District? _highlightedDistrict;

  LatLng _currentPosition = _nouakchottCenter;

  _SelectionTarget _activeTarget = _SelectionTarget.destination;
  _SelectedPoint? _pickup;
  _SelectedPoint? _destination;

  String _query = '';
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _pickup = const _SelectedPoint(label: 'موقعي الحالي', position: _nouakchottCenter);
    _loadDistricts();
    _resolveCurrentLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDistricts() async {
    final districts = await NouakchottDistrictsData.loadDistricts();
    if (!mounted) return;
    setState(() {
      _districts = districts;
      _loadingDistricts = false;
    });
  }

  Future<void> _resolveCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return;

      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        if (_pickup?.label == 'موقعي الحالي') {
          _pickup = _SelectedPoint(label: 'موقعي الحالي', position: _currentPosition);
        }
      });
    } catch (_) {
      // Keep the fallback Nouakchott-center location silently.
    }
  }

  List<District> get _matchingDistricts {
    if (_query.isEmpty) return [];
    return _districts.where((d) => d.nameAr.contains(_query)).toList();
  }

  List<PlaceItem> get _matchingPlaces {
    if (_query.isEmpty) return [];
    return NouakchottDistrictsData.places.where((p) => p.name.contains(_query)).take(10).toList();
  }

  void _assignSelection(_SelectedPoint point) {
    setState(() {
      if (_activeTarget == _SelectionTarget.pickup) {
        _pickup = point;
        _activeTarget = _SelectionTarget.destination;
      } else {
        _destination = point;
      }
      _query = '';
      _searchController.clear();
      _highlightedDistrict = null;
    });
  }

  Future<void> _selectDistrict(District district) async {
    setState(() {
      _highlightedDistrict = district;
      _query = '';
      _searchController.clear();
      FocusScope.of(context).unfocus();
    });

    _mapController.fitCamera(
      CameraFit.bounds(bounds: district.bounds, padding: const EdgeInsets.all(60)),
    );

    final result = await showModalBottomSheet<DistrictSheetResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DistrictPlacesSheet(
        district: district,
        selectingPickup: _activeTarget == _SelectionTarget.pickup,
      ),
    );

    if (result == null || !mounted) return;

    if (result.manualFallback) {
      final manual = await Navigator.of(context).push<ManualPinResult>(
        MaterialPageRoute(builder: (_) => ManualPinSelectionScreen(initialCenter: district.center)),
      );
      if (manual != null) {
        final label = manual.description.isNotEmpty ? manual.description : 'موقع محدد يدوياً - ${district.nameAr}';
        _assignSelection(_SelectedPoint(label: label, position: manual.position));
      }
    } else if (result.place != null) {
      _assignSelection(_SelectedPoint(label: result.place!.name, position: result.place!.position));
    }
  }

  void _onMapTap(LatLng point) {
    for (final district in _districts) {
      if (district.containsPoint(point)) {
        _selectDistrict(district);
        return;
      }
    }
  }

  void _simulateVoiceSearch() {
    setState(() => _isListening = true);
    Timer(const Duration(milliseconds: 1600), () {
      if (!mounted) return;
      setState(() {
        _isListening = false;
        _query = 'تفرغ زينة';
        _searchController.text = _query;
      });
    });
  }

  void _showRecentDestinations() {
    final trips = context.read<AppStateProvider>().customerTripHistory;
    showModalBottomSheet(
      context: context,
      builder: (context) {
        if (trips.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Text('لا توجد وجهات سابقة بعد.', style: TextStyle(fontFamily: 'Cairo')),
          );
        }
        return ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: trips.take(8).map((trip) {
            return ListTile(
              leading: const Icon(Icons.history_rounded, color: AppColors.primary),
              title: Text(trip.destinationLocation, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13)),
              onTap: () {
                Navigator.of(context).pop();
                _assignSelection(_SelectedPoint(label: trip.destinationLocation, position: LatLng(trip.destLat, trip.destLng)));
              },
            );
          }).toList(),
        );
      },
    );
  }

  void _proceedToTripDetails() {
    if (_pickup == null || _destination == null) return;
    final distance = double.parse(
      (_distanceCalc.as(LengthUnit.Kilometer, _pickup!.position, _destination!.position)).toStringAsFixed(1),
    );
    final duration = (distance * 1.5 + 4).round();
    final price = double.parse((distance * 40 + 50).toStringAsFixed(0));

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TripDetailsScreen(
          pickup: _pickup!.label,
          destination: _destination!.label,
          pickupLat: _pickup!.position.latitude,
          pickupLng: _pickup!.position.longitude,
          destLat: _destination!.position.latitude,
          destLng: _destination!.position.longitude,
          distance: distance,
          duration: duration,
          price: price,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canProceed = _pickup != null && _destination != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Positioned.fill(
            child: _loadingDistricts
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _nouakchottCenter,
                      initialZoom: 12.2,
                      onTap: (tapPosition, latLng) => _onMapTap(latLng),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.alhudhud.app',
                      ),
                      PolygonLayer(
                        polygons: _districts.map((d) {
                          final isHighlighted = _highlightedDistrict?.id == d.id;
                          final base = DistrictColors.fillFor(d.id);
                          return Polygon(
                            points: d.boundary,
                            color: base.withValues(alpha: isHighlighted ? 0.55 : 0.32),
                            isFilled: true,
                            borderColor: base.withValues(alpha: 0.95),
                            borderStrokeWidth: isHighlighted ? 3.5 : 1.5,
                          );
                        }).toList(),
                      ),
                      MarkerLayer(
                        markers: _districts.map((d) {
                          return Marker(
                            point: d.center,
                            width: 110,
                            height: 34,
                            child: GestureDetector(
                              onTap: () => _selectDistrict(d),
                              child: Container(
                                alignment: Alignment.center,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: DistrictColors.borderFor(d.id)),
                                ),
                                child: Text(
                                  d.nameAr,
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: AppColors.darkText),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      MarkerLayer(
                        markers: [
                          if (_pickup != null)
                            Marker(
                              point: _pickup!.position,
                              width: 36,
                              height: 36,
                              child: const Icon(Icons.radio_button_checked_rounded, color: AppColors.success, size: 30),
                            ),
                          if (_destination != null)
                            Marker(
                              point: _destination!.position,
                              width: 36,
                              height: 36,
                              child: const Icon(Icons.location_pin, color: AppColors.error, size: 34),
                            ),
                        ],
                      ),
                    ],
                  ),
          ),

          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.arrow_back_rounded, color: AppColors.darkText),
                              onPressed: () => Navigator.of(context).maybePop(),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
                              ),
                              child: TextFormField(
                                controller: _searchController,
                                style: const TextStyle(fontSize: 13, fontFamily: 'Cairo'),
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  hintText: 'ابحث عن مكان أو مقاطعة',
                                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary, size: 20),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      Icons.mic_rounded,
                                      color: _isListening ? AppColors.error : AppColors.secondaryText,
                                    ),
                                    onPressed: _simulateVoiceSearch,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                onChanged: (val) => setState(() => _query = val),
                              ),
                            ),
                          ),
                        ],
                      ),

                      if (_isListening)
                        Container(
                          margin: const EdgeInsets.only(top: 10),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.graphic_eq_rounded, color: AppColors.error, size: 18),
                              SizedBox(width: 8),
                              Text('جاري الاستماع...', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),

                      if (_query.isNotEmpty) _buildSearchSuggestions(),

                      if (_query.isEmpty) ...[
                        const SizedBox(height: 10),
                        _buildSelectionPills(),
                        const SizedBox(height: 10),
                        _buildQuickShortcuts(),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (canProceed)
            Positioned(
              left: 20,
              right: 20,
              bottom: 24,
              child: SafeArea(
                top: false,
                child: ElevatedButton(
                  onPressed: _proceedToTripDetails,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('متابعة'),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, size: 20),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSelectionPills() {
    return Row(
      children: [
        Expanded(child: _buildTargetPill(_SelectionTarget.pickup, 'الانطلاق', _pickup?.label, Icons.radio_button_checked_rounded, AppColors.success)),
        const SizedBox(width: 8),
        Expanded(child: _buildTargetPill(_SelectionTarget.destination, 'الوجهة', _destination?.label, Icons.location_on_rounded, AppColors.error)),
      ],
    );
  }

  Widget _buildTargetPill(_SelectionTarget target, String title, String? value, IconData icon, Color iconColor) {
    final isActive = _activeTarget == target;
    return GestureDetector(
      onTap: () => setState(() => _activeTarget = target),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isActive ? AppColors.primary : Colors.transparent, width: 1.5),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 9, color: AppColors.secondaryText, fontFamily: 'Cairo')),
                  Text(
                    value ?? 'اختر...',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: value == null ? AppColors.secondaryText : AppColors.darkText),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickShortcuts() {
    return SizedBox(
      height: 74,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildShortcutChip('موقعي الحالي', Icons.my_location_rounded, () {
            _assignSelection(_SelectedPoint(label: 'موقعي الحالي', position: _currentPosition));
          }),
          _buildShortcutChip('المنزل', Icons.home_filled, () => _assignSelection(_homePoint)),
          _buildShortcutChip('العمل', Icons.work_rounded, () => _assignSelection(_workPoint)),
          _buildShortcutChip('آخر الوجهات', Icons.history_rounded, _showRecentDestinations),
        ],
      ),
    );
  }

  Widget _buildShortcutChip(String label, IconData icon, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(left: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 72,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: AppColors.primary, size: 18),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: AppColors.darkText),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchSuggestions() {
    final districts = _matchingDistricts;
    final places = _matchingPlaces;

    if (districts.isEmpty && places.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(16),
        width: double.infinity,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: const Text('لا توجد نتائج مطابقة', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.secondaryText)),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 10),
      constraints: const BoxConstraints(maxHeight: 320),
      decoration: const BoxDecoration(
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            ...districts.map((d) => ListTile(
                  leading: Icon(Icons.map_rounded, color: DistrictColors.fillFor(d.id)),
                  title: Text(d.nameAr, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: const Text('مقاطعة', style: TextStyle(fontFamily: 'Cairo', fontSize: 11)),
                  onTap: () => _selectDistrict(d),
                )),
            ...places.map((p) => ListTile(
                  leading: Icon(p.category.icon, color: AppColors.primary, size: 20),
                  title: Text(p.name, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: Text(p.category.labelAr, style: const TextStyle(fontFamily: 'Cairo', fontSize: 11)),
                  onTap: () => _assignSelection(_SelectedPoint(label: p.name, position: p.position)),
                )),
          ],
        ),
      ),
    );
  }
}
