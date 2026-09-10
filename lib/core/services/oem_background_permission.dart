import 'package:flutter/services.dart';

/// Manufacturers known for aggressively killing backgrounded apps and/or
/// suppressing full-screen-intent notifications unless their own
/// "autostart"/"background pop-up" toggle is enabled - see MainActivity.kt
/// for the actual per-OEM settings screens this opens. Matches
/// Build.MANUFACTURER (lowercase), not the marketing brand name shown in
/// stores.
const List<String> kAggressiveOemManufacturers = [
  'xiaomi',
  'oppo',
  'realme',
  'vivo',
  'huawei',
  'honor',
  'infinix',
  'tecno',
  'itel',
];

/// Bridges to MainActivity.kt's per-manufacturer "autostart"/background
/// permission screens - stock Android's notification and battery-optimization
/// permissions alone aren't enough on these ROMs for a backgrounded
/// النقل app's full-screen trip alert to actually pop the screen open
/// while it's on and unlocked (see NewTripAlert's header comment).
class OemBackgroundPermission {
  static const _channel = MethodChannel('com.alhudhud.captain/oem_settings');

  /// Build.MANUFACTURER, lowercased (e.g. "xiaomi", "samsung") - null on iOS
  /// or if the platform channel isn't available for any reason. Compare
  /// against [kAggressiveOemManufacturers] to decide whether to show extra
  /// guidance.
  static Future<String?> getManufacturer() async {
    try {
      final result = await _channel.invokeMethod<String>('getManufacturer');
      return result;
    } catch (_) {
      return null;
    }
  }

  /// Best-effort: tries this device's manufacturer-specific "autostart"/
  /// background-activity settings screen first, then the standard Android
  /// battery-optimization exemption prompt, then the app's own details page
  /// as a last resort - see MainActivity.openBackgroundSettings() for the
  /// exact fallback chain. Always returns normally even if every attempt
  /// silently fails (unrecognized ROM), since there's nothing more this app
  /// itself can do beyond pointing the captain at whatever opened.
  static Future<void> openBackgroundSettings() async {
    try {
      await _channel.invokeMethod('openBackgroundSettings');
    } catch (_) {
      // Not Android, or the channel/activity isn't available - nothing else
      // to fall back to from the Dart side.
    }
  }
}
