package com.alhudhud.captain

import android.content.ActivityNotFoundException
import android.content.ComponentName
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// A stock Android full-screen-intent notification (see NewTripAlert) is
// only guaranteed to actually take over the screen when it's off/locked -
// when the phone is on and unlocked with another app in front, most
// aggressive-battery-management OEM skins (MIUI, ColorOS, Funtouch/OriginOS,
// EMUI/MagicUI - all common in this app's market) additionally suppress it
// unless the app has that manufacturer's own "autostart"/"background
// pop-up" toggle enabled, which sits outside anything Android's standard
// notification/battery-optimization permissions cover. There's no single
// cross-OEM API for this - just per-manufacturer settings screens, sourced
// from what these ROMs' own component names have been for years. Every
// attempt is wrapped so an unrecognized ROM version (renamed activity,
// different OEM entirely) falls through to the next option instead of
// crashing.
private const val CHANNEL = "com.alhudhud.captain/oem_settings"

// See TripOverlayService for why this exists: a full-screen-intent
// notification alone can't pop over an unlocked, already-in-use phone, only
// a SYSTEM_ALERT_WINDOW overlay can. This channel only covers the
// app-alive-in-background case, where NewTripAlert.play()/stop() call
// straight into this same running engine - it does NOT reach the separate
// headless engine firebase_messaging spins up to run
// firebaseMessagingBackgroundHandler for a fully-killed app, which still
// only gets the ring + regular notification.
private const val OVERLAY_CHANNEL = "com.alhudhud.captain/trip_overlay"

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getManufacturer" -> result.success(Build.MANUFACTURER.lowercase())
                "openBackgroundSettings" -> {
                    openBackgroundSettings()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, OVERLAY_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasOverlayPermission" -> result.success(Settings.canDrawOverlays(this))
                "requestOverlayPermission" -> {
                    if (!Settings.canDrawOverlays(this)) {
                        val intent = Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:$packageName"),
                        )
                        tryStartActivity(intent)
                    }
                    result.success(null)
                }
                "showTripOverlay" -> {
                    if (Settings.canDrawOverlays(this)) {
                        val serviceIntent = Intent(this, TripOverlayService::class.java).apply {
                            putExtra(
                                TripOverlayService.EXTRA_CUSTOMER_NAME,
                                call.argument<String>("customerName"),
                            )
                            putExtra(TripOverlayService.EXTRA_PICKUP, call.argument<String>("pickup"))
                        }
                        // The Dart call that triggers this very often comes
                        // from a backgrounded app (captain switched away) -
                        // plain startService() is blocked from there on API
                        // 26+, startForegroundService() is the sanctioned
                        // way in (TripOverlayService promotes itself within
                        // the required 5s via startForeground()).
                        ContextCompat.startForegroundService(this, serviceIntent)
                    }
                    result.success(null)
                }
                "hideTripOverlay" -> {
                    val serviceIntent = Intent(this, TripOverlayService::class.java).apply {
                        action = TripOverlayService.ACTION_HIDE
                    }
                    ContextCompat.startForegroundService(this, serviceIntent)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun tryStartActivity(intent: Intent): Boolean {
        return try {
            startActivity(intent)
            true
        } catch (_: ActivityNotFoundException) {
            false
        } catch (_: Exception) {
            false
        }
    }

    private fun openBackgroundSettings() {
        val manufacturer = Build.MANUFACTURER.lowercase()
        val oemIntents = when {
            manufacturer.contains("xiaomi") -> listOf(
                ComponentName(
                    "com.miui.securitycenter",
                    "com.miui.permcenter.autostart.AutoStartManagementActivity",
                ),
            )
            manufacturer.contains("oppo") || manufacturer.contains("realme") -> listOf(
                ComponentName(
                    "com.coloros.safecenter",
                    "com.coloros.safecenter.permission.startup.StartupAppListActivity",
                ),
                ComponentName(
                    "com.oppo.safe",
                    "com.oppo.safe.permission.startup.StartupAppListActivity",
                ),
            )
            manufacturer.contains("vivo") -> listOf(
                ComponentName(
                    "com.vivo.permissionmanager",
                    "com.vivo.permissionmanager.activity.BgStartUpManagerActivity",
                ),
                ComponentName(
                    "com.iqoo.secure",
                    "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity",
                ),
            )
            manufacturer.contains("huawei") || manufacturer.contains("honor") -> listOf(
                ComponentName(
                    "com.huawei.systemmanager",
                    "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity",
                ),
                ComponentName(
                    "com.huawei.systemmanager",
                    "com.huawei.systemmanager.optimize.process.ProtectActivity",
                ),
            )
            manufacturer.contains("infinix") || manufacturer.contains("tecno") ||
                manufacturer.contains("itel") -> listOf(
                // Transsion (Infinix/Tecno/itel) ROMs are all XOS/HiOS-based
                // and typically expose the same phone-manager package name.
                ComponentName(
                    "com.transsion.phonemanager",
                    "com.transsion.phonemanager.MainActivity",
                ),
            )
            else -> emptyList()
        }

        for (component in oemIntents) {
            val intent = Intent().apply {
                setComponent(component)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            if (tryStartActivity(intent)) return
        }

        // Falls back to the standard (non-OEM-specific, always available)
        // battery-optimization exemption prompt - still helps on stock
        // Android/Samsung/Pixel, and as a last resort if the OEM changed
        // their autostart screen's package/class name in a newer ROM update.
        try {
            val powerManager = getSystemService(POWER_SERVICE) as PowerManager
            if (!powerManager.isIgnoringBatteryOptimizations(packageName)) {
                val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                    data = Uri.parse("package:$packageName")
                }
                if (tryStartActivity(intent)) return
            }
        } catch (_: Exception) {
            // Fall through to the generic settings screen below.
        }

        // Last resort: the app's own details page, where a captain can at
        // least find battery/notification settings manually.
        val fallback = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
            data = Uri.parse("package:$packageName")
        }
        tryStartActivity(fallback)
    }
}
