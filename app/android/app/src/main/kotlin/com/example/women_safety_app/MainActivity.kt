package com.example.women_safety_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.location.LocationManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlin.math.sqrt

class MainActivity : FlutterActivity(), SensorEventListener {
    private val channelName = "sakhi/native_actions"
    private var methodChannel: MethodChannel? = null

    private var sensorManager: SensorManager? = null
    private var accelerometer: Sensor? = null

    private var powerShortcutEnabled: Boolean = true
    private var shakeShortcutEnabled: Boolean = false
    private var shakeThresholdG: Float = 2.35f

    private val shakeTimestamps = mutableListOf<Long>()
    private var lastTriggerTimeMs: Long = 0L

    private val hardwareKeyTimestamps = mutableListOf<Long>()
    private val powerScreenTimestamps = mutableListOf<Long>()
    private var screenReceiverRegistered = false

    private val screenToggleReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (!powerShortcutEnabled) return
            val action = intent?.action ?: return
            if (action == Intent.ACTION_SCREEN_OFF || action == Intent.ACTION_SCREEN_ON) {
                val now = System.currentTimeMillis()
                powerScreenTimestamps.removeAll { now - it > 2500L }
                powerScreenTimestamps.add(now)
                if (powerScreenTimestamps.size >= 3 && now - lastTriggerTimeMs > 4000L) {
                    powerScreenTimestamps.clear()
                    lastTriggerTimeMs = now
                    vibrateAlert()
                    runOnUiThread {
                        methodChannel?.invokeMethod(
                            "onDiscreetTrigger",
                            mapOf("source" to "POWER_BUTTON_3X", "timestamp" to now)
                        )
                    }
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        sensorManager = getSystemService(Context.SENSOR_SERVICE) as? SensorManager
        accelerometer = sensorManager?.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        registerPowerReceiverIfNeeded()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        methodChannel = channel

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "dialNumber" -> {
                    val rawNumber = call.argument<String>("number") ?: "112"
                    val cleaned = rawNumber.replace(Regex("[^0-9+]"), "")
                    val dialNumber = if (cleaned.isNotEmpty()) cleaned else "112"
                    try {
                        val intent = Intent(Intent.ACTION_DIAL).apply {
                            data = Uri.parse("tel:$dialNumber")
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("DIAL_ERROR", e.message, null)
                    }
                }
                "openExternalUrl" -> {
                    val url = call.argument<String>("url") ?: ""
                    if (url.isBlank()) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    try {
                        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("URL_ERROR", e.message, null)
                    }
                }
                "composeSms" -> {
                    val recipients = call.argument<String>("recipients") ?: ""
                    val body = call.argument<String>("body") ?: ""
                    try {
                        val uri = Uri.parse("smsto:$recipients")
                        val intent = Intent(Intent.ACTION_SENDTO, uri).apply {
                            putExtra("sms_body", body)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SMS_ERROR", e.message, null)
                    }
                }
                "configureShortcuts" -> {
                    powerShortcutEnabled = call.argument<Boolean>("powerShortcutEnabled") ?: true
                    shakeShortcutEnabled = call.argument<Boolean>("shakeShortcutEnabled") ?: false
                    val sensitivity = call.argument<Double>("shakeThresholdG") ?: 2.35
                    shakeThresholdG = sensitivity.toFloat().coerceIn(1.5f, 4.0f)
                    updateSensorRegistration()
                    result.success(
                        mapOf(
                            "powerShortcutEnabled" to powerShortcutEnabled,
                            "shakeShortcutEnabled" to shakeShortcutEnabled,
                            "shakeThresholdG" to shakeThresholdG
                        )
                    )
                }
                "vibrateFeedback" -> {
                    vibrateAlert()
                    result.success(true)
                }
                "getLastKnownNativeLocation" -> {
                    try {
                        val locManager = getSystemService(Context.LOCATION_SERVICE) as? LocationManager
                        val providers = locManager?.getProviders(true) ?: emptyList()
                        var bestLocation: android.location.Location? = null
                        for (provider in providers) {
                            try {
                                val l = locManager?.getLastKnownLocation(provider) ?: continue
                                if (bestLocation == null || l.accuracy < bestLocation.accuracy) {
                                    bestLocation = l
                                }
                            } catch (_: SecurityException) {
                            }
                        }
                        if (bestLocation != null) {
                            result.success(
                                mapOf(
                                    "latitude" to bestLocation.latitude,
                                    "longitude" to bestLocation.longitude,
                                    "accuracy" to bestLocation.accuracy.toDouble()
                                )
                            )
                        } else {
                            result.success(null)
                        }
                    } catch (e: Exception) {
                        result.success(null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (powerShortcutEnabled && event.action == KeyEvent.ACTION_DOWN) {
            val code = event.keyCode
            if (code == KeyEvent.KEYCODE_VOLUME_DOWN ||
                code == KeyEvent.KEYCODE_VOLUME_UP ||
                code == KeyEvent.KEYCODE_POWER
            ) {
                val now = System.currentTimeMillis()
                hardwareKeyTimestamps.removeAll { now - it > 1800L }
                hardwareKeyTimestamps.add(now)
                if (hardwareKeyTimestamps.size >= 3 && now - lastTriggerTimeMs > 3500L) {
                    hardwareKeyTimestamps.clear()
                    lastTriggerTimeMs = now
                    vibrateAlert()
                    methodChannel?.invokeMethod(
                        "onDiscreetTrigger",
                        mapOf("source" to "HARDWARE_KEY_3X", "timestamp" to now)
                    )
                }
            }
        }
        return super.dispatchKeyEvent(event)
    }

    override fun onResume() {
        super.onResume()
        updateSensorRegistration()
    }

    override fun onPause() {
        super.onPause()
        if (!shakeShortcutEnabled) {
            sensorManager?.unregisterListener(this)
        }
    }

    override fun onDestroy() {
        sensorManager?.unregisterListener(this)
        if (screenReceiverRegistered) {
            try {
                unregisterReceiver(screenToggleReceiver)
            } catch (_: Exception) {
            }
            screenReceiverRegistered = false
        }
        super.onDestroy()
    }

    private fun registerPowerReceiverIfNeeded() {
        if (screenReceiverRegistered) return
        try {
            val filter = IntentFilter().apply {
                addAction(Intent.ACTION_SCREEN_OFF)
                addAction(Intent.ACTION_SCREEN_ON)
            }
            registerReceiver(screenToggleReceiver, filter)
            screenReceiverRegistered = true
        } catch (_: Exception) {
        }
    }

    private fun updateSensorRegistration() {
        sensorManager?.unregisterListener(this)
        if (shakeShortcutEnabled && accelerometer != null) {
            sensorManager?.registerListener(
                this,
                accelerometer,
                SensorManager.SENSOR_DELAY_UI
            )
        }
    }

    override fun onSensorChanged(event: SensorEvent?) {
        if (!shakeShortcutEnabled || event?.sensor?.type != Sensor.TYPE_ACCELEROMETER) return
        val x = event.values[0]
        val y = event.values[1]
        val z = event.values[2]
        val gX = x / SensorManager.GRAVITY_EARTH
        val gY = y / SensorManager.GRAVITY_EARTH
        val gZ = z / SensorManager.GRAVITY_EARTH
        val gForce = sqrt(gX * gX + gY * gY + gZ * gZ)

        if (gForce > shakeThresholdG) {
            val now = System.currentTimeMillis()
            if (shakeTimestamps.isNotEmpty() && now - shakeTimestamps.last() < 180L) {
                return
            }
            shakeTimestamps.removeAll { now - it > 1600L }
            shakeTimestamps.add(now)
            if (shakeTimestamps.size >= 3 && now - lastTriggerTimeMs > 3500L) {
                shakeTimestamps.clear()
                lastTriggerTimeMs = now
                vibrateAlert()
                methodChannel?.invokeMethod(
                    "onDiscreetTrigger",
                    mapOf("source" to "SHAKE_GESTURE", "gForce" to gForce.toDouble(), "timestamp" to now)
                )
            }
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    private fun vibrateAlert() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vm = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
                vm?.defaultVibrator?.vibrate(
                    VibrationEffect.createWaveform(longArrayOf(0, 120, 80, 180), -1)
                )
            } else {
                @Suppress("DEPRECATION")
                val v = getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    v?.vibrate(VibrationEffect.createOneShot(200, VibrationEffect.DEFAULT_AMPLITUDE))
                } else {
                    @Suppress("DEPRECATION")
                    v?.vibrate(200)
                }
            }
        } catch (_: Exception) {
        }
    }
}
