import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/constants/colors.dart';

class ManualPinResult {
  final LatLng position;
  final String description;

  const ManualPinResult({required this.position, required this.description});
}

class ManualPinSelectionScreen extends StatefulWidget {
  final LatLng initialCenter;

  const ManualPinSelectionScreen({super.key, required this.initialCenter});

  @override
  State<ManualPinSelectionScreen> createState() => _ManualPinSelectionScreenState();
}

class _ManualPinSelectionScreenState extends State<ManualPinSelectionScreen> {
  final MapController _mapController = MapController();
  final _descriptionController = TextEditingController();
  late LatLng _selectedCenter = widget.initialCenter;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  void _confirm() {
    Navigator.of(context).pop(
      ManualPinResult(
        position: _selectedCenter,
        description: _descriptionController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('تحديد الموقع يدوياً'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: widget.initialCenter,
                      initialZoom: 15.5,
                      onPositionChanged: (position, hasGesture) {
                        if (position.center != null) {
                          _selectedCenter = position.center!;
                        }
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.alhudhud.app',
                      ),
                    ],
                  ),

                  // Fixed center pin - the map moves underneath it.
                  const Padding(
                    padding: EdgeInsets.only(bottom: 36),
                    child: Icon(Icons.location_pin, color: AppColors.error, size: 44),
                  ),

                  Positioned(
                    top: 16,
                    left: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.pan_tool_alt_rounded, color: AppColors.primary, size: 18),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'حرّك الخريطة لضبط الدبوس على موقعك بدقة',
                              style: TextStyle(fontSize: 12, fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: AppColors.darkText),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 1)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'صف موقعك (اختياري)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Cairo', color: AppColors.darkText),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _descriptionController,
                    style: const TextStyle(fontSize: 13, fontFamily: 'Cairo'),
                    decoration: const InputDecoration(
                      hintText: 'مثال: بجانب مسجد النور، مقابل سوق عرفات...',
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _confirm,
                    child: const Text('تأكيد هذا الموقع'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
