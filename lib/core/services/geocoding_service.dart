import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

/// Turns a raw lat/lng into a short "بالقرب من [اسم معلم حقيقي]" label -
/// for trips whose destination was dropped as a map pin instead of picked
/// from an address search, those arrive with an address string that just
/// says it was picked from the map, which tells a captain nothing useful
/// about where to actually go.
///
/// Only ever returns an actual named place (a shop, pharmacy, mosque,
/// hospital, ...) - never a street address, which the captain asked not to
/// see because it's too long to be useful at a glance. Returns null when no
/// named place is close enough; the caller then falls back to showing the
/// raw coordinates with a "open in maps" link instead.
///
/// Uses the same Google Maps key already shipped for the map itself
/// (see android/app/src/main/AndroidManifest.xml) - it must have "Places
/// API" enabled in Google Cloud Console alongside the Maps SDK, or every
/// lookup below fails closed to the coordinates-only fallback.
class GeocodingService {
  GeocodingService._();

  static const String _apiKey = 'AIzaSyCCk_PuvRgaxz41DC94-UOu4zoppb13PZk';

  // Nearby Search's rankby=distance mode requires a keyword/name/type
  // filter and still only returns one category at a time, which misses a
  // closer place of a different kind. Plain radius search returns every
  // nearby place regardless of kind, and we sort them by real distance
  // ourselves - the radii below are tried in order, widening only if the
  // tighter one comes back empty (open land, a newly built area).
  static const List<int> _searchRadiiMeters = [400, 1200];

  // Keyed by "lat,lng" rounded to ~11m precision - trip pins repeat around
  // the same handful of neighborhoods, so this avoids re-billing the same
  // lookup every time a captain reopens a request card.
  static final Map<String, String?> _cache = {};

  static Future<String?> nearbyPlaceLabel(double lat, double lng) async {
    final key = '${lat.toStringAsFixed(4)},${lng.toStringAsFixed(4)}';
    if (_cache.containsKey(key)) return _cache[key];

    String? label;
    for (final radius in _searchRadiiMeters) {
      final name = await _nearestNamedPlace(lat, lng, radius);
      if (name != null) {
        label = 'بالقرب من $name';
        break;
      }
    }
    _cache[key] = label;
    return label;
  }

  static Future<String?> _nearestNamedPlace(
    double lat,
    double lng,
    int radiusMeters,
  ) async {
    try {
      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/place/nearbysearch/json',
        {
          'location': '$lat,$lng',
          'radius': '$radiusMeters',
          'language': 'ar',
          'key': _apiKey,
        },
      );
      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) return null;
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['status'] != 'OK') return null;
      final results = (body['results'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      if (results.isEmpty) return null;

      Map<String, dynamic>? nearest;
      double nearestDistance = double.infinity;
      for (final place in results) {
        final name = place['name'] as String?;
        if (name == null || name.trim().isEmpty) continue;
        final location =
            (place['geometry'] as Map<String, dynamic>?)?['location']
                as Map<String, dynamic>?;
        final placeLat = (location?['lat'] as num?)?.toDouble();
        final placeLng = (location?['lng'] as num?)?.toDouble();
        if (placeLat == null || placeLng == null) continue;
        final distance = _distanceMeters(lat, lng, placeLat, placeLng);
        if (distance < nearestDistance) {
          nearestDistance = distance;
          nearest = place;
        }
      }
      return (nearest?['name'] as String?)?.trim();
    } catch (_) {
      return null;
    }
  }

  static double _distanceMeters(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const earthRadiusMeters = 6371000.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLng = _degToRad(lng2 - lng1);
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_degToRad(lat1)) *
            cos(_degToRad(lat2)) *
            sin(dLng / 2) *
            sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  static double _degToRad(double deg) => deg * pi / 180;

  static String coordinatesLabel(double lat, double lng) =>
      '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
}
