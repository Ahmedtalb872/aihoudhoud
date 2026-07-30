import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Plays a chime, vibrates the phone, and posts a system notification when a
/// new trip request appears for the captain — mirrors the "new ride" alert
/// in real ride-hailing driver apps, and is visible even if the captain has
/// switched to another app.
class NewTripAlert {
  static final AudioPlayer _player = AudioPlayer();
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static const _channel = AndroidNotificationDetails(
    'new_trip_requests',
    'طلبات المشاوير الجديدة',
    channelDescription: 'إشعار عند وصول طلب مشوار جديد',
    importance: Importance.max,
    priority: Priority.high,
  );

  static Future<void> initialize() async {
    if (_initialized) return;
    try {
      await _notifications.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
      );
      _initialized = true;
    } catch (_) {
      // Not supported on this platform (e.g. web); notifications stay off.
    }
  }

  static Future<void> play({String? customerName, String? pickup}) async {
    unawaited(_vibrate());
    unawaited(_playChime());
    unawaited(_notify(customerName: customerName, pickup: pickup));
  }

  static Future<void> _vibrate() async {
    try {
      if (await Vibration.hasVibrator()) {
        Vibration.vibrate(pattern: [0, 350, 150, 350]);
      }
    } catch (_) {
      // No vibration hardware/permission on this platform; ignore.
    }
  }

  static Future<void> _playChime() async {
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/new_trip_chime.wav'));
    } catch (_) {
      // No audio output available in this environment; ignore.
    }
  }

  static Future<void> _notify({String? customerName, String? pickup}) async {
    if (!_initialized) return;
    try {
      await _notifications.show(
        0,
        'مشوار ركاب جديد!',
        customerName != null && pickup != null
            ? '$customerName - $pickup'
            : 'اضغط لعرض تفاصيل الطلب قبل انتهاء الوقت.',
        const NotificationDetails(android: _channel),
      );
    } catch (_) {
      // Notifications not permitted/available; the in-app alert still shows.
    }
  }
}
