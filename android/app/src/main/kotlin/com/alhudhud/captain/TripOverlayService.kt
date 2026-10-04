package com.alhudhud.captain

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.IBinder
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.ImageButton
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.app.NotificationCompat

// A plain full-screen-intent notification (see NewTripAlert) only
// auto-launches its Activity over a LOCKED screen - Android platform
// behavior, unaffected by any permission grant. The only way to interrupt a
// captain who's unlocked and using another app, the same way an incoming
// call or Truecaller/WhatsApp's call UI does, is a real window drawn on top
// of everything else via SYSTEM_ALERT_WINDOW ("display over other apps").
// This service owns exactly one such window: a compact card the captain can
// tap to jump straight into the app, or dismiss without opening it.
class TripOverlayService : Service() {
    private var windowManager: WindowManager? = null
    private var overlayView: View? = null

    companion object {
        const val EXTRA_CUSTOMER_NAME = "customerName"
        const val EXTRA_PICKUP = "pickup"
        const val ACTION_HIDE = "com.alhudhud.captain.action.HIDE_TRIP_OVERLAY"
        private const val SERVICE_CHANNEL_ID = "trip_overlay_service"
        private const val SERVICE_NOTIFICATION_ID = 9001
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        // MainActivity starts this with startForegroundService() since the
        // captain's Dart isolate that requests the overlay is very often
        // running while the app itself is backgrounded (they've switched to
        // another app) - Android requires promoting to a real foreground
        // service within 5 seconds of that call or it kills the service.
        // LOW importance keeps this housekeeping notification silent and
        // out of the way; the actual ring/alert still comes from
        // NewTripAlert's own separate high-importance channel.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(
                NotificationChannel(
                    SERVICE_CHANNEL_ID,
                    "خدمة تنبيه المشاوير",
                    NotificationManager.IMPORTANCE_LOW,
                ),
            )
        }
        val notification = NotificationCompat.Builder(this, SERVICE_CHANNEL_ID)
            .setContentTitle("الهدهد")
            .setSmallIcon(applicationInfo.icon)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .build()
        startForeground(SERVICE_NOTIFICATION_ID, notification)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Lets NewTripAlert.stop() dismiss an already-showing card the
        // moment the request is accepted, ignored, or times out elsewhere
        // in the app - otherwise it would keep floating on screen for a
        // trip that's no longer up for grabs.
        if (intent?.action == ACTION_HIDE) {
            removeOverlay()
            stopSelf()
            return START_NOT_STICKY
        }
        val customerName = intent?.getStringExtra(EXTRA_CUSTOMER_NAME)
        val pickup = intent?.getStringExtra(EXTRA_PICKUP)
        showOverlay(customerName, pickup)
        return START_NOT_STICKY
    }

    private fun showOverlay(customerName: String?, pickup: String?) {
        // Replace any card already showing (e.g. a newer trip request)
        // instead of stacking a second one on top.
        removeOverlay()

        val wm = getSystemService(WINDOW_SERVICE) as WindowManager
        windowManager = wm

        val density = resources.displayMetrics.density
        fun dp(v: Int) = (v * density).toInt()

        val card = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(16), dp(14), dp(16), dp(14))
            background = GradientDrawable().apply {
                setColor(Color.WHITE)
                cornerRadius = dp(18).toFloat()
                setStroke(dp(1), Color.parseColor("#FFED9E35"))
            }
            elevation = dp(8).toFloat()
        }

        val textColumn = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
        }
        textColumn.addView(TextView(this).apply {
            text = "🚕 مشوار جديد!"
            setTextColor(Color.parseColor("#0B3D3A"))
            textSize = 15f
            setTypeface(typeface, android.graphics.Typeface.BOLD)
        })
        val subtitle = listOfNotNull(customerName, pickup).joinToString(" - ")
        if (subtitle.isNotEmpty()) {
            textColumn.addView(TextView(this).apply {
                text = subtitle
                setTextColor(Color.parseColor("#6B6B6B"))
                textSize = 12f
                maxLines = 1
            })
        }
        textColumn.addView(TextView(this).apply {
            text = "اضغط لعرض تفاصيل الطلب"
            setTextColor(Color.parseColor("#FFED9E35"))
            textSize = 12f
            setTypeface(typeface, android.graphics.Typeface.BOLD)
            setPadding(0, dp(4), 0, 0)
        })
        textColumn.setOnClickListener { openApp() }
        card.addView(textColumn)

        card.addView(ImageButton(this).apply {
            setImageResource(android.R.drawable.ic_menu_close_clear_cancel)
            background = null
            setColorFilter(Color.parseColor("#9AA0A6"))
            layoutParams = LinearLayout.LayoutParams(dp(28), dp(28))
            setOnClickListener {
                removeOverlay()
                stopSelf()
            }
        })
        card.setOnClickListener { openApp() }

        // A MATCH_PARENT-width window ignores any x offset for centering -
        // the side margins have to come from padding on a full-width
        // container instead, with the actual styled card as its only child.
        val root = LinearLayout(this).apply {
            setPadding(dp(12), 0, dp(12), 0)
            addView(card)
        }

        val overlayType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            overlayType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP
            y = dp(40)
        }

        try {
            wm.addView(root, params)
            overlayView = root
        } catch (_: Exception) {
            // Permission not granted or window type unsupported on this
            // device/ROM - the existing ring/notification alert still fires.
            stopSelf()
        }
    }

    private fun openApp() {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        startActivity(intent)
        removeOverlay()
        stopSelf()
    }

    private fun removeOverlay() {
        overlayView?.let {
            try {
                windowManager?.removeView(it)
            } catch (_: Exception) {
                // Already removed - nothing to do.
            }
        }
        overlayView = null
    }

    override fun onDestroy() {
        removeOverlay()
        super.onDestroy()
    }
}
