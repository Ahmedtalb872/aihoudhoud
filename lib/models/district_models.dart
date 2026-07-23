import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

enum PlaceCategory {
  neighborhood,
  hospital,
  restaurant,
  market,
  playground,
  mosque,
  school,
  government,
  gasStation,
  landmark,
}

extension PlaceCategoryX on PlaceCategory {
  String get labelAr {
    switch (this) {
      case PlaceCategory.neighborhood:
        return 'الأحياء';
      case PlaceCategory.hospital:
        return 'المستشفيات';
      case PlaceCategory.restaurant:
        return 'المطاعم';
      case PlaceCategory.market:
        return 'الأسواق';
      case PlaceCategory.playground:
        return 'الملاعب';
      case PlaceCategory.mosque:
        return 'المساجد';
      case PlaceCategory.school:
        return 'المدارس والجامعات';
      case PlaceCategory.government:
        return 'الإدارات الحكومية';
      case PlaceCategory.gasStation:
        return 'محطات الوقود';
      case PlaceCategory.landmark:
        return 'أماكن مشهورة';
    }
  }

  IconData get icon {
    switch (this) {
      case PlaceCategory.neighborhood:
        return Icons.location_city_rounded;
      case PlaceCategory.hospital:
        return Icons.local_hospital_rounded;
      case PlaceCategory.restaurant:
        return Icons.restaurant_rounded;
      case PlaceCategory.market:
        return Icons.storefront_rounded;
      case PlaceCategory.playground:
        return Icons.sports_soccer_rounded;
      case PlaceCategory.mosque:
        return Icons.mosque_rounded;
      case PlaceCategory.school:
        return Icons.school_rounded;
      case PlaceCategory.government:
        return Icons.account_balance_rounded;
      case PlaceCategory.gasStation:
        return Icons.local_gas_station_rounded;
      case PlaceCategory.landmark:
        return Icons.landscape_rounded;
    }
  }
}

class District {
  final String id;
  final String nameAr;
  final List<LatLng> boundary;
  final LatLng center;

  const District({
    required this.id,
    required this.nameAr,
    required this.boundary,
    required this.center,
  });

  /// Ray-casting point-in-polygon test, used to resolve which district
  /// (if any) a raw map tap falls inside.
  bool containsPoint(LatLng point) {
    bool inside = false;
    for (int i = 0, j = boundary.length - 1; i < boundary.length; j = i++) {
      final xi = boundary[i].longitude, yi = boundary[i].latitude;
      final xj = boundary[j].longitude, yj = boundary[j].latitude;
      final intersect = ((yi > point.latitude) != (yj > point.latitude)) &&
          (point.longitude <
              (xj - xi) * (point.latitude - yi) / (yj - yi) + xi);
      if (intersect) inside = !inside;
    }
    return inside;
  }

  LatLngBounds get bounds => LatLngBounds.fromPoints(boundary);
}

class PlaceItem {
  final String id;
  final String name;
  final String districtId;
  final PlaceCategory category;
  final LatLng position;
  final String? note;

  const PlaceItem({
    required this.id,
    required this.name,
    required this.districtId,
    required this.category,
    required this.position,
    this.note,
  });
}
