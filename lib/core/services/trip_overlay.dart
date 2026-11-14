import 'package:flutter/services.dart';

/// Bridges to TripOverlayService.kt - a card drawn on top of whatever app
/// the captain is currently using ("Display over other apps" /
/// SYSTEM_ALERT_WINDOW), tappable straight into the app. A plain
/// full-screen-intent notification (see NewTripAlert) only auto-launches
/// its Activity when the screen is locked - Android platform behavior no
/// permission changes - so this is the only way to interrupt an unlocked
/// phone already showing another app, the same way incoming-call-style
/// apps do it.
///
/// Only covers the app-alive-in-background case: MainActivity's channel
/// this calls into belongs to the same running engine the rest of the app
/// uses, which the separate headless engine firebase_messaging spins up
/// for a fully-killed app does not reach - that case still falls back to
/// the ring + regular notification only.
class TripOverlay {
  static const _channel = MethodChannel('com.alhudhud.captain/trip_overlay');

  /// Whether "Display over other apps" is already granted - null on iOS or
  /// if the channel isn't available for any reason.
  static Future<bool?> hasPermission() async {
    try {
      return await _channel.invokeMethod<bool>('hasOverlayPermission');
    } catch (_) {
      return null;
    }
  }

  /// Opens the system settings screen for this permission - it can't be
  /// granted via a normal runtime prompt like other permissions.
  static Future<void> requestPermission() async {
    try {
      await _channel.invokeMethod('requestOverlayPermission');
    } catch (_) {
      // Not Android, or the channel/activity isn't available.
    }
  }

  /// Best-effort: silently no-ops if the permission isn't granted (the
  /// native side checks) or the platform doesn't support it.
  static Future<void> show({String? customerName, String? pickup}) async {
    try {
      await _channel.invokeMethod('showTripOverlay', {
        'customerName': customerName,
        'pickup': pickup,
      });
    } catch (_) {}
  }

  /// Dismisses an already-showing card - call alongside NewTripAlert.stop()
  /// so it doesn't keep floating for a request that's no longer up for
  /// grabs. Harmless no-op if nothing is showing.
  static Future<void> hide() async {
    try {
      await _channel.invokeMethod('hideTripOverlay');
    } catch (_) {}
  }
}
