import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';

/// Plays a short chime and vibrates the phone when a new trip request
/// appears for the captain — mirrors the "new ride" alert in real
/// ride-hailing driver apps.
class NewTripAlert {
  static final AudioPlayer _player = AudioPlayer();

  static Future<void> play() async {
    unawaited(_vibrate());
    unawaited(_playChime());
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
}
