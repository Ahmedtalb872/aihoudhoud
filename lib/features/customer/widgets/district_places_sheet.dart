import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/district_colors.dart';
import '../../../models/district_models.dart';
import '../../../data/nouakchott_districts_data.dart';

class DistrictSheetResult {
  final PlaceItem? place;
  final bool manualFallback;

  const DistrictSheetResult.place(PlaceItem item)
      : place = item,
        manualFallback = false;

  const DistrictSheetResult.manual()
      : place = null,
        manualFallback = true;
}

/// Bottom sheet shown after a district is selected on the map: lets the
/// customer search within the district and pick a neighborhood/POI as their
/// pickup or destination point.
class DistrictPlacesSheet extends StatefulWidget {
  final District district;
  final bool selectingPickup;

  const DistrictPlacesSheet({
    super.key,
    required this.district,
    required this.selectingPickup,
  });

  @override
  State<DistrictPlacesSheet> createState() => _DistrictPlacesSheetState();
}

class _DistrictPlacesSheetState extends State<DistrictPlacesSheet> {
  final _searchController = TextEditingController();
  String _query = '';
  PlaceCategory? _activeCategory;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<PlaceItem> get _allPlaces => NouakchottDistrictsData.placesForDistrict(widget.district.id);

  List<PlaceItem> get _filteredPlaces {
    return _allPlaces.where((p) {
      final matchesQuery = _query.isEmpty || p.name.contains(_query);
      final matchesCategory = _activeCategory == null || p.category == _activeCategory;
      return matchesQuery && matchesCategory;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final color = DistrictColors.fillFor(widget.district.id);
    final categories = _allPlaces.map((p) => p.category).toSet().toList();
    final grouped = <PlaceCategory, List<PlaceItem>>{};
    for (final p in _filteredPlaces) {
      grouped.putIfAbsent(p.category, () => []).add(p);
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.62,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Material(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.district.nameAr,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: AppColors.darkText),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    widget.selectingPickup ? 'اختر نقطة الانطلاق من هذه المقاطعة' : 'اختر الوجهة من هذه المقاطعة',
                    style: const TextStyle(fontSize: 11, color: AppColors.secondaryText, fontFamily: 'Cairo'),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextFormField(
                  controller: _searchController,
                  style: const TextStyle(fontSize: 13, fontFamily: 'Cairo'),
                  decoration: InputDecoration(
                    hintText: 'ابحث داخل ${widget.district.nameAr}...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  ),
                  onChanged: (val) => setState(() => _query = val),
                ),
              ),
              const SizedBox(height: 12),

              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _buildCategoryChip(null, 'الكل'),
                    const SizedBox(width: 8),
                    ...categories.map((c) => Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: _buildCategoryChip(c, c.labelAr),
                        )),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),

              Expanded(
                child: _filteredPlaces.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Text(
                            'لا توجد نتائج مطابقة داخل ${widget.district.nameAr}',
                            style: const TextStyle(fontFamily: 'Cairo', color: AppColors.secondaryText, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        children: grouped.entries.map((entry) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
                                child: Text(
                                  entry.key.labelAr,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: AppColors.secondaryText),
                                ),
                              ),
                              ...entry.value.map((place) => ListTile(
                                    leading: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(color: color.withValues(alpha: 0.25), shape: BoxShape.circle),
                                      child: Icon(place.category.icon, color: AppColors.darkText, size: 18),
                                    ),
                                    title: Text(place.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Cairo')),
                                    trailing: const Icon(Icons.arrow_back_rounded, size: 16),
                                    onTap: () => Navigator.of(context).pop(DistrictSheetResult.place(place)),
                                  )),
                            ],
                          );
                        }).toList(),
                      ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(const DistrictSheetResult.manual()),
                  icon: const Icon(Icons.edit_location_alt_rounded, size: 18),
                  label: const Text('لا أجد المكان، سأحدده يدوياً'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoryChip(PlaceCategory? category, String label) {
    final isSelected = _activeCategory == category;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12, fontFamily: 'Cairo')),
      selected: isSelected,
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(color: isSelected ? Colors.white : AppColors.darkText, fontWeight: FontWeight.bold),
      backgroundColor: AppColors.background,
      onSelected: (_) => setState(() => _activeCategory = category),
    );
  }
}
