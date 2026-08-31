import Flutter
import GoogleMaps
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // iOS-restricted key (by bundle ID), separate from the Android key in
    // AndroidManifest.xml - an "Android apps" restricted key can't be used
    // from iOS at all, which is why this is its own key.
    GMSServices.provideAPIKey("AIzaSyCdN--P9n6AHU3J1Lf7PDYSiceRDL2Q-Bo")
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
