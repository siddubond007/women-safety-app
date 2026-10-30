package com.example.women_safety_app

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.location.LocationManager
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.net.Uri
import android.os.BatteryManager
import android.os.Build
import android.os.Bundle
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.telephony.SmsManager
import android.telephony.SubscriptionManager
import android.view.KeyEvent
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlin.math.PI
import kotlin.math.sin
import kotlin.math.sqrt

class MainActivity : FlutterActivity(), SensorEventListener {
    private val channelName = "sakhi/native_actions"
    private val sosChannelId = "sakhi_sos_Confirmation_channel"
    private val sosNotificationId = 9112
    private val permissionRequestCode = 4412

    private var methodChannel: MethodChannel? = null
    private var pendingPermissionResult: MethodChannel.Result? = null

    private var sensorManager: SensorManager? = null
    private var accelerometer: Sensor? = null

    private var powerShortcutEnabled: Boolean = true
    private var shakeShortcutEnabled: Boolean = false
    private var shakeThresholdG: Float = 2.35f

    private val shakeTimestamps = mutableListOf<Long>()
    private var lastTriggerTimeMs: Long = 0L

    // Distinct short-tap tracking (prevents holding volume key from triggering SOS,
    // while reliably capturing rapid 3x clicks of Volume Up/Down or Power)
    private val hardwareKeyTimestamps = mutableListOf<Long>()
    private var lastVolumeKeyDownMs: Long = 0L
    private var lastVolumeKeyCode: Int = -1
    private var volumeKeyHoldDetected: Boolean = false

    // Background volume & power button tracking
    private val powerScreenTimestamps = mutableListOf<Long>()
    private val backgroundVolumeTimestamps = mutableListOf<Long>()
    private var lastBackgroundVolumeChangeMs: Long = 0L
    private var screenReceiverRegistered = false
    private var isActivityResumed = false

    // Synthesized Meditation Audio Engine (432Hz + 528Hz harmonic singing bowls)
    @Volatile
    private var meditationPlaying = false
    @Volatile
    private var meditationVolume = 0.75f
    private var meditationThread: Thread? = null
    private var meditationAudioTrack: AudioTrack? = null

    private val screenAndVolumeReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (!powerShortcutEnabled) return
            val action = intent?.action ?: return
            val now = System.currentTimeMillis()

            if (action == Intent.ACTION_SCREEN_OFF || action == Intent.ACTION_SCREEN_ON) {
                powerScreenTimestamps.removeAll { now - it > 5000L }
                powerScreenTimestamps.add(now)
                if (powerScreenTimestamps.size >= 3 && now - lastTriggerTimeMs > 3000L) {
                    powerScreenTimestamps.clear()
                    lastTriggerTimeMs = now
                    fireDiscreetSosTrigger("POWER_BUTTON_3X", now, null)
                }
            } else if (action == "android.media.VOLUME_CHANGED_ACTION" && !isActivityResumed) {
                val delta = now - lastBackgroundVolumeChangeMs
                lastBackgroundVolumeChangeMs = now
                // Ignore rapid auto-repeat events (< 95ms) when user holds down volume button
                if (delta in 1L..95L) {
                    backgroundVolumeTimestamps.clear()
                    return
                }
                backgroundVolumeTimestamps.removeAll { now - it > 3500L }
                backgroundVolumeTimestamps.add(now)
                if (backgroundVolumeTimestamps.size >= 3 && now - lastTriggerTimeMs > 3000L) {
                    backgroundVolumeTimestamps.clear()
                    lastTriggerTimeMs = now
                    fireDiscreetSosTrigger("HARDWARE_KEY_3X", now, null)
                }
            }
        }
    }

    override fun shouldRestoreAndSaveState(): Boolean = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        sensorManager = getSystemService(Context.SENSOR_SERVICE) as? SensorManager
        accelerometer = sensorManager?.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        createSosNotificationChannel()
        registerPowerAndVolumeReceiverIfNeeded()
        handleSosNotificationIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleSosNotificationIntent(intent)
    }

    private fun handleSosNotificationIntent(intent: Intent?) {
        val triggerSource = intent?.getStringExtra("sakhi_sos_trigger_source") ?: return
        intent.removeExtra("sakhi_sos_trigger_source")
        val now = System.currentTimeMillis()
        window?.decorView?.postDelayed({
            methodChannel?.invokeMethod(
                "onDiscreetTrigger",
                mapOf(
                    "source" to triggerSource,
                    "timestamp" to now,
                    "fromNotification" to true
                )
            )
        }, 350L)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        methodChannel = channel

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "moveAppToBackground" -> {
                    moveTaskToBack(true)
                    result.success(true)
                }

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

                "openWhatsAppChat" -> {
                    val rawPhone = call.argument<String>("phone") ?: ""
                    val message = call.argument<String>("message") ?: "Hello! I found your women-owned business on Sakhi."
                    val preferBusiness = call.argument<Boolean>("preferBusiness")
                    var digits = rawPhone.replace(Regex("[^0-9]"), "")
                    if (digits.length == 10) {
                        digits = "91$digits"
                    }
                    val encodedMsg = Uri.encode(message)
                    val deepLinkUri = if (digits.isNotEmpty()) {
                        Uri.parse("whatsapp://send?phone=$digits&text=$encodedMsg")
                    } else {
                        Uri.parse("whatsapp://send?text=$encodedMsg")
                    }
                    val webUri = if (digits.isNotEmpty()) {
                        Uri.parse("https://api.whatsapp.com/send?phone=$digits&text=$encodedMsg")
                    } else {
                        Uri.parse("https://api.whatsapp.com/send?text=$encodedMsg")
                    }
                    val packageOrder = when (preferBusiness) {
                        true -> listOf("com.whatsapp.w4b", "com.whatsapp")
                        false -> listOf("com.whatsapp", "com.whatsapp.w4b")
                        else -> emptyList()
                    }
                    var launched = false
                    for (pkg in packageOrder) {
                        try {
                            val pkgIntent = Intent(Intent.ACTION_VIEW, deepLinkUri).apply {
                                setPackage(pkg)
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            if (pkgIntent.resolveActivity(packageManager) != null) {
                                startActivity(pkgIntent)
                                launched = true
                                break
                            }
                        } catch (_: Exception) {}
                    }
                    if (!launched) {
                        try {
                            val directIntent = Intent(Intent.ACTION_VIEW, deepLinkUri).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(directIntent)
                            launched = true
                        } catch (_: Exception) {
                            try {
                                val fallbackIntent = Intent(Intent.ACTION_VIEW, webUri).apply {
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                startActivity(fallbackIntent)
                                launched = true
                            } catch (e: Exception) {
                                result.error("WHATSAPP_ERROR", e.message, null)
                                return@setMethodCallHandler
                            }
                        }
                    }
                    result.success(launched)
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

                "getBatteryLevel" -> {
                    result.success(readRealBatteryPercentage())
                }

                "requestSmsAndSimPermissions" -> {
                    val needed = mutableListOf<String>()
                    if (ContextCompat.checkSelfPermission(this, Manifest.permission.SEND_SMS) != PackageManager.PERMISSION_GRANTED) {
                        needed.add(Manifest.permission.SEND_SMS)
                    }
                    if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_PHONE_STATE) != PackageManager.PERMISSION_GRANTED) {
                        needed.add(Manifest.permission.READ_PHONE_STATE)
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                        ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
                    ) {
                        needed.add(Manifest.permission.POST_NOTIFICATIONS)
                    }
                    if (needed.isEmpty()) {
                        result.success(
                            mapOf(
                                "smsGranted" to true,
                                "simGranted" to true,
                                "simCards" to readAvailableSimCards()
                            )
                        )
                    } else {
                        pendingPermissionResult = result
                        ActivityCompat.requestPermissions(
                            this,
                            needed.toTypedArray(),
                            permissionRequestCode
                        )
                    }
                }

                "getAvailableSimCards" -> {
                    result.success(readAvailableSimCards())
                }

                "sendDirectEmergencySms" -> {
                    val recipientsRaw = call.argument<String>("recipients") ?: ""
                    val recipientsListArg = call.argument<List<String>>("recipientList")
                    val body = call.argument<String>("body") ?: ""
                    val subscriptionId = call.argument<Int>("subscriptionId") ?: -1

                    val allTargets = mutableListOf<String>()
                    if (recipientsListArg != null) {
                        allTargets.addAll(recipientsListArg)
                    }
                    if (recipientsRaw.isNotBlank()) {
                        allTargets.addAll(recipientsRaw.split(",", ";"))
                    }
                    val cleanedRecipients = allTargets
                        .map { it.trim().replace(Regex("[^0-9+]"), "") }
                        .filter { it.length >= 8 }
                        .distinct()

                    if (cleanedRecipients.isEmpty() || body.isBlank()) {
                        result.success(
                            mapOf(
                                "sentDirectly" to false,
                                "sentCount" to 0,
                                "reason" to "No valid emergency contact numbers or message body."
                            )
                        )
                        return@setMethodCallHandler
                    }

                    val hasSmsPermission = ContextCompat.checkSelfPermission(
                        this,
                        Manifest.permission.SEND_SMS
                    ) == PackageManager.PERMISSION_GRANTED

                    if (hasSmsPermission) {
                        try {
                            val smsManager: SmsManager = if (subscriptionId >= 0) {
                                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                                    getSystemService(SmsManager::class.java)
                                        ?.createForSubscriptionId(subscriptionId)
                                        ?: SmsManager.getDefault()
                                } else {
                                    @Suppress("DEPRECATION")
                                    SmsManager.getSmsManagerForSubscriptionId(subscriptionId)
                                }
                            } else {
                                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                                    getSystemService(SmsManager::class.java) ?: SmsManager.getDefault()
                                } else {
                                    @Suppress("DEPRECATION")
                                    SmsManager.getDefault()
                                }
                            }

                            var sentCount = 0
                            for (phone in cleanedRecipients) {
                                val parts = smsManager.divideMessage(body)
                                if (parts.size > 1) {
                                    smsManager.sendMultipartTextMessage(phone, null, parts, null, null)
                                } else {
                                    smsManager.sendTextMessage(phone, null, body, null, null)
                                }
                                sentCount++
                            }
                            vibrateAlert()
                            result.success(
                                mapOf(
                                    "sentDirectly" to true,
                                    "sentCount" to sentCount,
                                    "recipients" to cleanedRecipients
                                )
                            )
                        } catch (e: Exception) {
                            launchFallbackSmsIntent(cleanedRecipients.joinToString(";"), body)
                            result.success(
                                mapOf(
                                    "sentDirectly" to false,
                                    "sentCount" to 0,
                                    "fallbackLaunched" to true,
                                    "reason" to (e.message ?: "Carrier SMS error")
                                )
                            )
                        }
                    } else {
                        launchFallbackSmsIntent(cleanedRecipients.joinToString(";"), body)
                        result.success(
                            mapOf(
                                "sentDirectly" to false,
                                "sentCount" to 0,
                                "fallbackLaunched" to true,
                                "reason" to "SMS permission not granted; opened default SMS composer."
                            )
                        )
                    }
                }

                "composeSms" -> {
                    val recipients = call.argument<String>("recipients") ?: ""
                    val body = call.argument<String>("body") ?: ""
                    val hasSmsPermission = ContextCompat.checkSelfPermission(
                        this,
                        Manifest.permission.SEND_SMS
                    ) == PackageManager.PERMISSION_GRANTED
                    if (hasSmsPermission && recipients.isNotBlank() && body.isNotBlank()) {
                        try {
                            val smsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                                getSystemService(SmsManager::class.java) ?: SmsManager.getDefault()
                            } else {
                                @Suppress("DEPRECATION")
                                SmsManager.getDefault()
                            }
                            val targets = recipients
                                .split(",", ";")
                                .map { it.trim().replace(Regex("[^0-9+]"), "") }
                                .filter { it.length >= 8 }
                                .distinct()
                            for (phone in targets) {
                                val parts = smsManager.divideMessage(body)
                                smsManager.sendMultipartTextMessage(phone, null, parts, null, null)
                            }
                            result.success(true)
                            return@setMethodCallHandler
                        } catch (_: Exception) {
                        }
                    }
                    val ok = launchFallbackSmsIntent(recipients, body)
                    result.success(ok)
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

                "showSosPullDownNotification" -> {
                    val source = call.argument<String>("source") ?: "HARDWARE_KEY_3X"
                    showHighPrioritySosNotification(source)
                    result.success(true)
                }

                "startMeditationAudio" -> {
                    val vol = (call.argument<Double>("volume") ?: 0.75).toFloat().coerceIn(0f, 1f)
                    meditationVolume = vol
                    startSynthesizedMeditationAudio()
                    result.success(true)
                }

                "pauseMeditationAudio", "stopMeditationAudio" -> {
                    stopSynthesizedMeditationAudio()
                    result.success(true)
                }

                "setMeditationVolume" -> {
                    val vol = (call.argument<Double>("volume") ?: 0.75).toFloat().coerceIn(0f, 1f)
                    meditationVolume = vol
                    try {
                        meditationAudioTrack?.setVolume(vol)
                    } catch (_: Exception) {
                    }
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
                    } catch (_: Exception) {
                        result.success(null)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == permissionRequestCode) {
            val smsGranted = ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.SEND_SMS
            ) == PackageManager.PERMISSION_GRANTED
            val simGranted = ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.READ_PHONE_STATE
            ) == PackageManager.PERMISSION_GRANTED
            pendingPermissionResult?.success(
                mapOf(
                    "smsGranted" to smsGranted,
                    "simGranted" to simGranted,
                    "simCards" to readAvailableSimCards()
                )
            )
            pendingPermissionResult = null
        }
    }

    private fun readRealBatteryPercentage(): Int {
        try {
            val bm = getSystemService(Context.BATTERY_SERVICE) as? BatteryManager
            val capacity = bm?.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY) ?: -1
            if (capacity in 1..100) {
                return capacity
            }
        } catch (_: Exception) {
        }
        try {
            val batteryIntent = registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
            val level = batteryIntent?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
            val scale = batteryIntent?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
            if (level >= 0 && scale > 0) {
                return ((level.toFloat() / scale.toFloat()) * 100f).toInt().coerceIn(1, 100)
            }
        } catch (_: Exception) {
        }
        return -1
    }

    private fun readAvailableSimCards(): List<Map<String, Any>> {
        val sims = mutableListOf<Map<String, Any>>()
        val hasPhoneState = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.READ_PHONE_STATE
        ) == PackageManager.PERMISSION_GRANTED
        if (!hasPhoneState) {
            return sims
        }
        try {
            val subManager = getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE) as? SubscriptionManager
            val activeList = subManager?.activeSubscriptionInfoList ?: emptyList()
            for (info in activeList) {
                sims.add(
                    mapOf(
                        "subscriptionId" to info.subscriptionId,
                        "simSlotIndex" to info.simSlotIndex,
                        "carrierName" to (info.carrierName?.toString() ?: "SIM ${info.simSlotIndex + 1}"),
                        "displayName" to (info.displayName?.toString() ?: "SIM ${info.simSlotIndex + 1}")
                    )
                )
            }
        } catch (_: SecurityException) {
        } catch (_: Exception) {
        }
        return sims
    }

    private fun launchFallbackSmsIntent(recipients: String, body: String): Boolean {
        return try {
            val uri = Uri.parse("smsto:$recipients")
            val intent = Intent(Intent.ACTION_SENDTO, uri).apply {
                putExtra("sms_body", body)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        val code = event.keyCode
        if (powerShortcutEnabled &&
            (code == KeyEvent.KEYCODE_VOLUME_DOWN ||
                code == KeyEvent.KEYCODE_VOLUME_UP ||
                code == KeyEvent.KEYCODE_POWER)
        ) {
            val now = System.currentTimeMillis()
            if (event.action == KeyEvent.ACTION_DOWN) {
                // Ignore key auto-repeats & long-presses when user holds down volume button
                if (event.repeatCount > 0 || event.isLongPress) {
                    volumeKeyHoldDetected = true
                    hardwareKeyTimestamps.clear()
                    return super.dispatchKeyEvent(event)
                }
                if (lastVolumeKeyDownMs == 0L || code != lastVolumeKeyCode || now - lastVolumeKeyDownMs > 50L) {
                    volumeKeyHoldDetected = false
                    lastVolumeKeyDownMs = now
                    lastVolumeKeyCode = code
                }
            } else if (event.action == KeyEvent.ACTION_UP) {
                val pressDurationMs = (now - lastVolumeKeyDownMs).coerceAtLeast(0L)
                if (!volumeKeyHoldDetected && pressDurationMs <= 850L) {
                    hardwareKeyTimestamps.removeAll { now - it > 3500L }
                    hardwareKeyTimestamps.add(now)
                    if (hardwareKeyTimestamps.size >= 3 && now - lastTriggerTimeMs > 3000L) {
                        hardwareKeyTimestamps.clear()
                        lastTriggerTimeMs = now
                        fireDiscreetSosTrigger("HARDWARE_KEY_3X", now, null)
                    }
                } else if (pressDurationMs > 850L) {
                    // Held too long -> clear tap sequence so holding never triggers SOS
                    hardwareKeyTimestamps.clear()
                }
                volumeKeyHoldDetected = false
            }
        }
        return super.dispatchKeyEvent(event)
    }

    private fun fireDiscreetSosTrigger(source: String, timestamp: Long, gForce: Double?) {
        vibrateAlert()
        showHighPrioritySosNotification(source)
        runOnUiThread {
            val payload = mutableMapOf<String, Any>(
                "source" to source,
                "timestamp" to timestamp
            )
            if (gForce != null) {
                payload["gForce"] = gForce
            }
            methodChannel?.invokeMethod("onDiscreetTrigger", payload)
        }
    }

    private fun createSosNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                sosChannelId,
                "Sakhi Emergency SOS Confirmation",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "High-priority pull-down confirmation alert for 3x Power/Volume SOS triggers"
                enableVibration(true)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            nm?.createNotificationChannel(channel)
        }
    }

    private fun showHighPrioritySosNotification(source: String) {
        try {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return
            val launchIntent = Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra("sakhi_sos_trigger_source", source)
            }
            val pendingFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
            val pendingIntent = PendingIntent.getActivity(this, 112, launchIntent, pendingFlags)
            val cleanSource = source.replace("_", " ")

            val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(this, sosChannelId)
            } else {
                @Suppress("DEPRECATION")
                Notification.Builder(this)
            }

            builder
                .setSmallIcon(android.R.drawable.ic_dialog_alert)
                .setContentTitle("Sakhi SOS Shortcut Detected ($cleanSource)")
                .setContentText("Tap immediately to confirm & dispatch live SOS alert to your trusted contacts.")
                .setContentIntent(pendingIntent)
                .setAutoCancel(true)

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                builder.setCategory(Notification.CATEGORY_ALARM)
                builder.setVisibility(Notification.VISIBILITY_PUBLIC)
                builder.setFullScreenIntent(pendingIntent, true)
            }

            nm.notify(sosNotificationId, builder.build())
        } catch (_: Exception) {
        }
    }

    private fun startSynthesizedMeditationAudio() {
        if (meditationPlaying) return
        meditationPlaying = true
        meditationThread = Thread {
            val sampleRate = 24000
            val bufferSamples = 2400
            val minBuf = AudioTrack.getMinBufferSize(
                sampleRate,
                AudioFormat.CHANNEL_OUT_MONO,
                AudioFormat.ENCODING_PCM_16BIT
            ).coerceAtLeast(bufferSamples * 2)

            val track = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                AudioTrack.Builder()
                    .setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_MEDIA)
                            .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                            .build()
                    )
                    .setAudioFormat(
                        AudioFormat.Builder()
                            .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                            .setSampleRate(sampleRate)
                            .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                            .build()
                    )
                    .setBufferSizeInBytes(minBuf)
                    .setTransferMode(AudioTrack.MODE_STREAM)
                    .build()
            } else {
                @Suppress("DEPRECATION")
                AudioTrack(
                    android.media.AudioManager.STREAM_MUSIC,
                    sampleRate,
                    AudioFormat.CHANNEL_OUT_MONO,
                    AudioFormat.ENCODING_PCM_16BIT,
                    minBuf,
                    AudioTrack.MODE_STREAM
                )
            }

            meditationAudioTrack = track
            try {
                track.setVolume(meditationVolume)
                track.play()
                val pcm = ShortArray(bufferSamples)
                var sampleIndex = 0L
                while (meditationPlaying) {
                    for (i in 0 until bufferSamples) {
                        val t = sampleIndex.toDouble() / sampleRate.toDouble()
                        val breathEnvelope = 0.65 + 0.35 * sin(2.0 * PI * 0.12 * t)
                        val chimeEnvelope = 0.5 + 0.5 * sin(2.0 * PI * 0.05 * t)
                        val wave432 = sin(2.0 * PI * 432.0 * t) * 0.38
                        val wave216 = sin(2.0 * PI * 216.0 * t) * 0.32
                        val wave528 = sin(2.0 * PI * 528.0 * t) * 0.20 * chimeEnvelope
                        val wave648 = sin(2.0 * PI * 648.0 * t) * 0.10 * chimeEnvelope
                        val mixed = (wave432 + wave216 + wave528 + wave648) * breathEnvelope * meditationVolume
                        pcm[i] = (mixed * 11000.0).toInt().coerceIn(-32000, 32000).toShort()
                        sampleIndex++
                    }
                    track.write(pcm, 0, bufferSamples)
                }
            } catch (_: Exception) {
            } finally {
                try {
                    track.stop()
                    track.release()
                } catch (_: Exception) {
                }
            }
        }.apply {
            isDaemon = true
            start()
        }
    }

    private fun stopSynthesizedMeditationAudio() {
        meditationPlaying = false
        try {
            meditationThread?.join(250L)
        } catch (_: Exception) {
        }
        meditationThread = null
        meditationAudioTrack = null
    }

    override fun onResume() {
        super.onResume()
        isActivityResumed = true
        updateSensorRegistration()
    }

    override fun onPause() {
        isActivityResumed = false
        super.onPause()
        // Keep accelerometer registered when shake shortcut is enabled so background shake works
        if (!shakeShortcutEnabled) {
            sensorManager?.unregisterListener(this)
        }
    }

    override fun onDestroy() {
        stopSynthesizedMeditationAudio()
        sensorManager?.unregisterListener(this)
        if (screenReceiverRegistered) {
            try {
                unregisterReceiver(screenAndVolumeReceiver)
            } catch (_: Exception) {
            }
            screenReceiverRegistered = false
        }
        super.onDestroy()
    }

    private fun registerPowerAndVolumeReceiverIfNeeded() {
        if (screenReceiverRegistered) return
        try {
            val filter = IntentFilter().apply {
                addAction(Intent.ACTION_SCREEN_OFF)
                addAction(Intent.ACTION_SCREEN_ON)
                addAction("android.media.VOLUME_CHANGED_ACTION")
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(screenAndVolumeReceiver, filter, Context.RECEIVER_EXPORTED)
            } else {
                registerReceiver(screenAndVolumeReceiver, filter)
            }
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
                SensorManager.SENSOR_DELAY_GAME
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
            shakeTimestamps.removeAll { now - it > 2200L }
            shakeTimestamps.add(now)
            if (shakeTimestamps.size >= 3 && now - lastTriggerTimeMs > 3000L) {
                shakeTimestamps.clear()
                lastTriggerTimeMs = now
                fireDiscreetSosTrigger("SHAKE_GESTURE", now, gForce.toDouble())
            }
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
        // No-op
    }

    private fun vibrateAlert() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vm = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
                vm?.defaultVibrator?.vibrate(
                    VibrationEffect.createWaveform(longArrayOf(0, 180, 90, 240), -1)
                )
            } else {
                @Suppress("DEPRECATION")
                val v = getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    v?.vibrate(VibrationEffect.createWaveform(longArrayOf(0, 180, 90, 240), -1))
                } else {
                    @Suppress("DEPRECATION")
                    v?.vibrate(400)
                }
            }
        } catch (_: Exception) {
        }
    }
}
