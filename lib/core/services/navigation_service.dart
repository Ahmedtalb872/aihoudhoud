import 'package:flutter/material.dart';

/// Lets code with no [BuildContext] of its own - like a notification-tap
/// callback, which fires from the plugin, not from a widget - navigate the
/// app. Attached to [MaterialApp.navigatorKey] in main.dart.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
