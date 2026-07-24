import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:latlong2/latlong.dart';
import '../models/district_models.dart';

class NouakchottDistrictsData {
  /// Loads the 9 Nouakchott moughataa (districts) from the bundled GeoJSON asset.
  static Future<List<District>> loadDistricts() async {
    final raw = await rootBundle.loadString('assets/geo/nouakchott_districts.geojson');
    final geo = json.decode(raw) as Map<String, dynamic>;
    final features = geo['features'] as List;

    return features.map((f) {
      final feature = f as Map<String, dynamic>;
      final props = feature['properties'] as Map<String, dynamic>;
      final geometry = feature['geometry'] as Map<String, dynamic>;
      final ring = (geometry['coordinates'] as List)[0] as List;

      final boundary = ring.map((c) {
        final coord = c as List;
        return LatLng((coord[1] as num).toDouble(), (coord[0] as num).toDouble());
      }).toList();

      final centerCoord = props['center'] as List;
      final center = LatLng((centerCoord[1] as num).toDouble(), (centerCoord[0] as num).toDouble());

      return District(
        id: props['id'] as String,
        nameAr: props['name_ar'] as String,
        boundary: boundary,
        center: center,
      );
    }).toList();
  }

  /// Dummy points of interest, grouped by district and category.
  /// Ready to be replaced by a real backend feed later.
  static final List<PlaceItem> places = [
    // تفرغ زينة
    const PlaceItem(id: 'p_tz_1', name: 'حي النخيل', districtId: 'tevragh_zeina', category: PlaceCategory.neighborhood, position: LatLng(18.1085, -15.9700)),
    const PlaceItem(id: 'p_tz_2', name: 'حي السفارات', districtId: 'tevragh_zeina', category: PlaceCategory.neighborhood, position: LatLng(18.1040, -15.9630)),
    const PlaceItem(id: 'p_tz_3', name: 'مجمع البيت', districtId: 'tevragh_zeina', category: PlaceCategory.market, position: LatLng(18.1025, -15.9754)),
    const PlaceItem(id: 'p_tz_4', name: 'سوبرماركت النخيل', districtId: 'tevragh_zeina', category: PlaceCategory.market, position: LatLng(18.1075, -15.9680)),
    const PlaceItem(id: 'p_tz_5', name: 'مطعم الواحة', districtId: 'tevragh_zeina', category: PlaceCategory.restaurant, position: LatLng(18.1055, -15.9715)),
    const PlaceItem(id: 'p_tz_6', name: 'مسجد الرحمة', districtId: 'tevragh_zeina', category: PlaceCategory.mosque, position: LatLng(18.1095, -15.9660)),
    const PlaceItem(id: 'p_tz_7', name: 'المدرسة الفرنسية الدولية', districtId: 'tevragh_zeina', category: PlaceCategory.school, position: LatLng(18.1110, -15.9690)),
    const PlaceItem(id: 'p_tz_8', name: 'محطة توتال تفرغ زينة', districtId: 'tevragh_zeina', category: PlaceCategory.gasStation, position: LatLng(18.1030, -15.9645)),
    const PlaceItem(id: 'p_tz_9', name: 'فندق الوفاء', districtId: 'tevragh_zeina', category: PlaceCategory.landmark, position: LatLng(18.1070, -15.9635)),

    // لكصر
    const PlaceItem(id: 'p_ks_1', name: 'حي لكصر الشرقي', districtId: 'ksar', category: PlaceCategory.neighborhood, position: LatLng(18.1000, -15.9560)),
    const PlaceItem(id: 'p_ks_2', name: 'حي لكصر الغربي', districtId: 'ksar', category: PlaceCategory.neighborhood, position: LatLng(18.0965, -15.9630)),
    const PlaceItem(id: 'p_ks_3', name: 'المستشفى الوطني', districtId: 'ksar', category: PlaceCategory.hospital, position: LatLng(18.0955, -15.9605)),
    const PlaceItem(id: 'p_ks_4', name: 'مستشفى الأمل', districtId: 'ksar', category: PlaceCategory.hospital, position: LatLng(18.0995, -15.9575)),
    const PlaceItem(id: 'p_ks_5', name: 'سوق العاصمة', districtId: 'ksar', category: PlaceCategory.market, position: LatLng(18.0878, -15.9789)),
    const PlaceItem(id: 'p_ks_6', name: 'السوق المركزي', districtId: 'ksar', category: PlaceCategory.market, position: LatLng(18.0975, -15.9560)),
    const PlaceItem(id: 'p_ks_7', name: 'الجامع الكبير', districtId: 'ksar', category: PlaceCategory.mosque, position: LatLng(18.0990, -15.9615)),
    const PlaceItem(id: 'p_ks_8', name: 'مبنى الوزارة الأولى', districtId: 'ksar', category: PlaceCategory.government, position: LatLng(18.0940, -15.9590)),
    const PlaceItem(id: 'p_ks_9', name: 'مبنى البلدية', districtId: 'ksar', category: PlaceCategory.government, position: LatLng(18.1005, -15.9600)),
    const PlaceItem(id: 'p_ks_10', name: 'محطة شنقيط', districtId: 'ksar', category: PlaceCategory.gasStation, position: LatLng(18.0960, -15.9560)),
    const PlaceItem(id: 'p_ks_11', name: 'المتحف الوطني', districtId: 'ksar', category: PlaceCategory.landmark, position: LatLng(18.0985, -15.9640)),

    // تيارت
    const PlaceItem(id: 'p_ty_1', name: 'حي تيارت الشمالي', districtId: 'teyarett', category: PlaceCategory.neighborhood, position: LatLng(18.1290, -15.9260)),
    const PlaceItem(id: 'p_ty_2', name: 'حي تيارت الجنوبي', districtId: 'teyarett', category: PlaceCategory.neighborhood, position: LatLng(18.1210, -15.9320)),
    const PlaceItem(id: 'p_ty_3', name: 'كارفور عين الطلح', districtId: 'teyarett', category: PlaceCategory.market, position: LatLng(18.1255, -15.9288)),
    const PlaceItem(id: 'p_ty_4', name: 'مطعم الفردوس', districtId: 'teyarett', category: PlaceCategory.restaurant, position: LatLng(18.1265, -15.9310)),
    const PlaceItem(id: 'p_ty_5', name: 'ملعب تيارت الرياضي', districtId: 'teyarett', category: PlaceCategory.playground, position: LatLng(18.1230, -15.9270)),
    const PlaceItem(id: 'p_ty_6', name: 'مسجد النور', districtId: 'teyarett', category: PlaceCategory.mosque, position: LatLng(18.1275, -15.9300)),
    const PlaceItem(id: 'p_ty_7', name: 'ثانوية تيارت', districtId: 'teyarett', category: PlaceCategory.school, position: LatLng(18.1245, -15.9330)),
    const PlaceItem(id: 'p_ty_8', name: 'محطة مصطفى', districtId: 'teyarett', category: PlaceCategory.gasStation, position: LatLng(18.1220, -15.9295)),

    // دار النعيم
    const PlaceItem(id: 'p_dn_1', name: 'حي دار النعيم الجديد', districtId: 'dar_naim', category: PlaceCategory.neighborhood, position: LatLng(18.1130, -15.9050)),
    const PlaceItem(id: 'p_dn_2', name: 'حي دار النعيم القديم', districtId: 'dar_naim', category: PlaceCategory.neighborhood, position: LatLng(18.1060, -15.9130)),
    const PlaceItem(id: 'p_dn_3', name: 'سوق دار النعيم الأسبوعي', districtId: 'dar_naim', category: PlaceCategory.market, position: LatLng(18.1098, -15.9087)),
    const PlaceItem(id: 'p_dn_4', name: 'مسجد دار النعيم الكبير', districtId: 'dar_naim', category: PlaceCategory.mosque, position: LatLng(18.1110, -15.9110)),
    const PlaceItem(id: 'p_dn_5', name: 'مدرسة دار النعيم الابتدائية', districtId: 'dar_naim', category: PlaceCategory.school, position: LatLng(18.1080, -15.9070)),
    const PlaceItem(id: 'p_dn_6', name: 'محطة دار النعيم', districtId: 'dar_naim', category: PlaceCategory.gasStation, position: LatLng(18.1150, -15.9100)),

    // توجنين
    const PlaceItem(id: 'p_tj_1', name: 'حي توجنين الصناعي', districtId: 'toujounine', category: PlaceCategory.neighborhood, position: LatLng(18.1450, -15.9420)),
    const PlaceItem(id: 'p_tj_2', name: 'مستشفى الشيخ زايد', districtId: 'toujounine', category: PlaceCategory.hospital, position: LatLng(18.1400, -15.9460)),
    const PlaceItem(id: 'p_tj_3', name: 'سوق توجنين', districtId: 'toujounine', category: PlaceCategory.market, position: LatLng(18.1435, -15.9440)),
    const PlaceItem(id: 'p_tj_4', name: 'مسجد توجنين الكبير', districtId: 'toujounine', category: PlaceCategory.mosque, position: LatLng(18.1410, -15.9400)),
    const PlaceItem(id: 'p_tj_5', name: 'جامعة العلوم الإسلامية', districtId: 'toujounine', category: PlaceCategory.school, position: LatLng(18.1445, -15.9470)),
    const PlaceItem(id: 'p_tj_6', name: 'محطة توجنين', districtId: 'toujounine', category: PlaceCategory.gasStation, position: LatLng(18.1390, -15.9430)),

    // عرفات
    const PlaceItem(id: 'p_af_1', name: 'حي عرفات 1', districtId: 'arafat', category: PlaceCategory.neighborhood, position: LatLng(18.0460, -15.9540)),
    const PlaceItem(id: 'p_af_2', name: 'حي عرفات 2', districtId: 'arafat', category: PlaceCategory.neighborhood, position: LatLng(18.0400, -15.9500)),
    const PlaceItem(id: 'p_af_3', name: 'كارفور الداية', districtId: 'arafat', category: PlaceCategory.market, position: LatLng(18.0435, -15.9521)),
    const PlaceItem(id: 'p_af_4', name: 'سوق عرفات', districtId: 'arafat', category: PlaceCategory.market, position: LatLng(18.0450, -15.9490)),
    const PlaceItem(id: 'p_af_5', name: 'مسجد عرفات الكبير', districtId: 'arafat', category: PlaceCategory.mosque, position: LatLng(18.0420, -15.9530)),
    const PlaceItem(id: 'p_af_6', name: 'ملعب عرفات', districtId: 'arafat', category: PlaceCategory.playground, position: LatLng(18.0470, -15.9510)),
    const PlaceItem(id: 'p_af_7', name: 'محطة عرفات', districtId: 'arafat', category: PlaceCategory.gasStation, position: LatLng(18.0410, -15.9505)),

    // الرياض
    const PlaceItem(id: 'p_ry_1', name: 'حي الرياض 1', districtId: 'riyad', category: PlaceCategory.neighborhood, position: LatLng(18.0155, -15.9670)),
    const PlaceItem(id: 'p_ry_2', name: 'حي الرياض 5', districtId: 'riyad', category: PlaceCategory.neighborhood, position: LatLng(18.0080, -15.9710)),
    const PlaceItem(id: 'p_ry_3', name: 'سوق الرياض الشعبي', districtId: 'riyad', category: PlaceCategory.market, position: LatLng(18.0125, -15.9688)),
    const PlaceItem(id: 'p_ry_4', name: 'مطعم طريق روصو', districtId: 'riyad', category: PlaceCategory.restaurant, position: LatLng(18.0100, -15.9650)),
    const PlaceItem(id: 'p_ry_5', name: 'مسجد الرياض', districtId: 'riyad', category: PlaceCategory.mosque, position: LatLng(18.0140, -15.9700)),
    const PlaceItem(id: 'p_ry_6', name: 'ثانوية الرياض', districtId: 'riyad', category: PlaceCategory.school, position: LatLng(18.0090, -15.9660)),
    const PlaceItem(id: 'p_ry_7', name: 'محطة روصو', districtId: 'riyad', category: PlaceCategory.gasStation, position: LatLng(18.0165, -15.9695)),

    // الميناء
    const PlaceItem(id: 'p_em_1', name: 'حي الميناء', districtId: 'el_mina', category: PlaceCategory.neighborhood, position: LatLng(18.0700, -15.9930)),
    const PlaceItem(id: 'p_em_2', name: 'سوق السمك', districtId: 'el_mina', category: PlaceCategory.market, position: LatLng(18.0650, -15.9980)),
    const PlaceItem(id: 'p_em_3', name: 'ميناء الصداقة', districtId: 'el_mina', category: PlaceCategory.landmark, position: LatLng(18.0630, -16.0000)),
    const PlaceItem(id: 'p_em_4', name: 'مطعم المأكولات البحرية', districtId: 'el_mina', category: PlaceCategory.restaurant, position: LatLng(18.0670, -15.9950)),
    const PlaceItem(id: 'p_em_5', name: 'مسجد الميناء', districtId: 'el_mina', category: PlaceCategory.mosque, position: LatLng(18.0715, -15.9910)),

    // السبخة
    const PlaceItem(id: 'p_sb_1', name: 'حي السبخة الشعبي', districtId: 'sebkha', category: PlaceCategory.neighborhood, position: LatLng(18.0865, -15.9900)),
    const PlaceItem(id: 'p_sb_2', name: 'سوق السبخة', districtId: 'sebkha', category: PlaceCategory.market, position: LatLng(18.0840, -15.9865)),
    const PlaceItem(id: 'p_sb_3', name: 'مسجد السبخة الكبير', districtId: 'sebkha', category: PlaceCategory.mosque, position: LatLng(18.0855, -15.9835)),
    const PlaceItem(id: 'p_sb_4', name: 'مدرسة السبخة الأساسية', districtId: 'sebkha', category: PlaceCategory.school, position: LatLng(18.0870, -15.9860)),
    const PlaceItem(id: 'p_sb_5', name: 'محطة السبخة', districtId: 'sebkha', category: PlaceCategory.gasStation, position: LatLng(18.0830, -15.9895)),
  ];

  static List<PlaceItem> placesForDistrict(String districtId) =>
      places.where((p) => p.districtId == districtId).toList();
}
