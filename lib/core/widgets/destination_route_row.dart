import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/colors.dart';
import '../services/geocoding_service.dart';
import 'route_row.dart';

/// Destination line for a trip request card. When the passenger picked the
/// destination by dropping a pin on the map instead of searching an address,
/// the saved address text is just a generic "selected from the map" label -
/// useless to a captain deciding whether to take the trip. When we have
/// coordinates for that pin, this re-geocodes them into a nearby landmark
/// description and always shows the raw coordinates with a button to open
/// turn-by-turn navigation straight to that point.
class DestinationRouteRow extends StatefulWidget {
  final String? destinationLocation;
  final double? destLat;
  final double? destLng;

  const DestinationRouteRow({
    super.key,
    required this.destinationLocation,
    required this.destLat,
    required this.destLng,
  });

  // A destination address is considered "unhelpful" - and worth replacing
  // with a geocoded nearby-landmark label - when it's missing, or when it's
  // one of the generic placeholders the customer app saves for a raw map
  // pin rather than a searched address.
  static bool _looksGeneric(String? text) {
    if (text == null || text.trim().isEmpty) return true;
    const markers = ['محدد من الخريطة', 'موقع من الخريطة', 'نقطة على الخريطة'];
    return markers.any(text.contains);
  }

  @override
  State<DestinationRouteRow> createState() => _DestinationRouteRowState();
}

class _DestinationRouteRowState extends State<DestinationRouteRow> {
  String? _nearbyLabel;
  bool _loading = false;

  bool get _hasCoordinates => widget.destLat != null && widget.destLng != null;

  @override
  void initState() {
    super.initState();
    _maybeGeocode();
  }

  @override
  void didUpdateWidget(covariant DestinationRouteRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.destLat != widget.destLat ||
        oldWidget.destLng != widget.destLng) {
      _nearbyLabel = null;
      _maybeGeocode();
    }
  }

  void _maybeGeocode() {
    if (!_hasCoordinates) return;
    if (!DestinationRouteRow._looksGeneric(widget.destinationLocation)) return;
    _loading = true;
    GeocodingService.nearbyPlaceLabel(widget.destLat!, widget.destLng!).then((
      label,
    ) {
      if (!mounted) return;
      setState(() {
        _nearbyLabel = label;
        _loading = false;
      });
    });
  }

  Future<void> _openNavigation() async {
    if (!_hasCoordinates) return;
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${widget.destLat},${widget.destLng}&travelmode=driving',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final isGeneric = DestinationRouteRow._looksGeneric(
      widget.destinationLocation,
    );
    final displayText = isGeneric
        ? (_nearbyLabel ??
              (_loading
                  ? 'جاري تحديد أقرب نقطة معروفة...'
                  : (widget.destinationLocation ??
                        'مشوار مفتوح (بدون وجهة محددة)')))
        : widget.destinationLocation!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RouteRow(dotColor: AppColors.error, label: 'إلى', text: displayText),
        if (isGeneric && _hasCoordinates) ...[
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.only(right: 18),
            child: GestureDetector(
              onTap: _openNavigation,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.map_outlined,
                    size: 13,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      '${GeocodingService.coordinatesLabel(widget.destLat!, widget.destLng!)} · فتح في الخريطة',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Cairo',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
