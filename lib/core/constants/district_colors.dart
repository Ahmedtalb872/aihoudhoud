import 'package:flutter/material.dart';

/// A light, distinct fill color for each of Nouakchott's 9 districts,
/// keyed by district id (see assets/geo/nouakchott_districts.geojson).
class DistrictColors {
  static const Map<String, Color> fill = {
    'tevragh_zeina': Color(0xFF5EEAD4), // light teal
    'ksar': Color(0xFFFDE68A), // light gold
    'teyarett': Color(0xFF93C5FD), // light blue
    'dar_naim': Color(0xFFFCA5A5), // light red
    'toujounine': Color(0xFFC4B5FD), // light purple
    'arafat': Color(0xFFBEF264), // light lime
    'riyad': Color(0xFFF9A8D4), // light pink
    'el_mina': Color(0xFF7DD3FC), // light sky
    'sebkha': Color(0xFFFDBA74), // light orange
  };

  static Color fillFor(String districtId) =>
      fill[districtId] ?? const Color(0xFF94A3B8);

  static Color borderFor(String districtId) =>
      fillFor(districtId).withValues(alpha: 0.9);
}
