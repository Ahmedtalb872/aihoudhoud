import 'dart:convert';
import 'package:http/http.dart' as http;

/// Turns a raw lat/lng into a short, human-readable "نقطة معروفة قريبة"
/// description, for trips whose destination was dropped as a map pin
/// instead of picked from an address search - those arrive with an address
/// string that just says it was picked from the map, which tells a captain
/// nothing useful about where to actually go.
///
/// Uses the same Google Maps key already shipped for the map itself
/// (see android/app/src/main/AndroidManifest.xml) - it must have both
/// "Places API" and "Geocoding API" enabled in Google Cloud Console
/// alongside the Maps SDK, or every lookup below fails closed to the
/// coordinates-only fallback.
class GeocodingService {
  GeocodingService._();

  static const String _apiKey = 'AIzaSyCCk_PuvRgaxz41DC94-UOu4zoppb13PZk';

  // Keyed by "lat,lng" rounded to ~11m precision - trip pins repeat around
  // the same handful of neighborhoods, so this avoids re-billing the same
  // lookup every time a captain reopens a request card.
  static final Map<String, String?> _cache = {};

  /// Returns something like "بالقرب من صيدلية الأمل" (a real nearby
  /// landmark's name, from Places Nearby Search) or, if nothing named is
  /// close enough, "بالقرب من [شارع]، [حي]" (a shortened reverse-geocoded
  /// address). Returns null if both lookups come up empty - caller should
  /// fall back to showing the raw coordinates in that case.
  static Future<String?> nearbyPlaceLabel(double lat, double lng) async {
    final key = '${lat.toStringAsFixed(4)},${lng.toStringAsFixed(4)}';
    if (_cache.containsKey(key)) return _cache[key];

    final landmark = await _nearestNamedPlace(lat, lng);
    final label = landmark != null
        ? 'بالقرب من $landmark'
        : await _reverseGeocodedLabel(lat, lng);
    _cache[key] = label;
    return label;
  }

  // Places Nearby Search - ranked by distance, so results[0] is the
  // closest actual business/landmark (a grocery store, pharmacy,
  // hospital, mosque, ...) rather than just a street address.
  static Future<String?> _nearestNamedPlace(double lat, double lng) async {
    try {
      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/place/nearbysearch/json',
        {
          'location': '$lat,$lng',
          'rankby': 'distance',
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
      final results = body['results'] as List<dynamic>;
      if (results.isEmpty) return null;
      final nearest = results.first as Map<String, dynamic>;
      final name = nearest['name'] as String?;
      if (name == null || name.trim().isEmpty) return null;
      return name.trim();
    } catch (_) {
      return null;
    }
  }

  // Reverse Geocoding fallback - used only when no named place turned up
  // nearby (open land, a new neighborhood Places hasn't indexed yet).
  static Future<String?> _reverseGeocodedLabel(double lat, double lng) async {
    try {
      final uri = Uri.https('maps.googleapis.com', '/maps/api/geocode/json', {
        'latlng': '$lat,$lng',
        'language': 'ar',
        'key': _apiKey,
      });
      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) return null;
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['status'] != 'OK') return null;
      final results = body['results'] as List<dynamic>;
      if (results.isEmpty) return null;
      final formatted =
          (results.first as Map<String, dynamic>)['formatted_address']
              as String?;
      return formatted == null ? null : 'بالقرب من ${_shorten(formatted)}';
    } catch (_) {
      return null;
    }
  }

  // Same spirit as RouteRow.shortAddress - a full "street, quarter,
  // moughataa, wilaya, Mauritania" string is too long for a trip card.
  static String _shorten(String formatted) {
    final parts = formatted
        .split(',')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.length <= 2) return parts.join('، ');
    return '${parts.first}، ${parts[parts.length - 2]}';
  }

  static String coordinatesLabel(double lat, double lng) =>
      '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
}
