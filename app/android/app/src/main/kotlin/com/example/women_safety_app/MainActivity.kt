package com.example.women_safety_app

import android.Manifest
import android.app.AlarmManager
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
import android.media.AudioFocusRequest
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioTrack
import android.media.MediaPlayer
import android.net.Uri
import android.os.BatteryManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
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
import java.io.File
import kotlin.math.PI
import kotlin.math.exp
import kotlin.math.sin
import kotlin.math.sqrt

/**
 * Deterministic two-stage SOS hardware volume-key state machine (Section 5).
 * Stage 1: 3 rapid Volume Up presses arm an 8-second confirmation window only.
 * Stage 2: 3 rapid Volume Down presses within the armed window confirm SOS.
 * Normal volume adjustment is never consumed or blocked.
 */
class SosVolumeKeyStateMachine(
    private val maxTapDurationMs: Long = 650L,
    private val minInterTapGapMs: Long = 55L,
    private val maxInterTapGapMs: Long = 900L,
    private val maxSequenceSpanMs: Long = 2200L,
    private val armedWindowDurationMs: Long = 8000L,
    private val cooldownDurationMs: Long = 10000L
) {
    enum class State {
        IDLE,
        ARMED_AWAITING_VOLUME_DOWN
    }

    var state: State = State.IDLE
        private set

    var armedAtMs: Long = 0L
        private set

    var armedExpiresAtMs: Long = 0L
        private set

    var lastConfirmedAtMs: Long = 0L
        private set

    private val volumeUpTaps = mutableListOf<Long>()
    private val volumeDownTaps = mutableListOf<Long>()
    private var lastKeyDownMs: Long = 0L
    private var lastKeyDownCode: Int = -1
    private var holdDetected: Boolean = false

    fun reset(): Boolean {
        val wasArmed = state == State.ARMED_AWAITING_VOLUME_DOWN
        state = State.IDLE
        armedAtMs = 0L
        armedExpiresAtMs = 0L
        volumeUpTaps.clear()
        volumeDownTaps.clear()
        lastKeyDownMs = 0L
        lastKeyDownCode = -1
        holdDetected = false
        return wasArmed
    }

    fun checkExpired(nowMs: Long): Boolean {
        if (state == State.ARMED_AWAITING_VOLUME_DOWN && nowMs > armedExpiresAtMs) {
            reset()
            return true
        }
        return false
    }

    fun onKeyDown(keyCode: Int, repeatCount: Int, isLongPress: Boolean, nowMs: Long) {
        checkExpired(nowMs)
        if (repeatCount > 0 || isLongPress) {
            holdDetected = true
            volumeUpTaps.clear()
            volumeDownTaps.clear()
            return
        }
        if (lastKeyDownMs == 0L || keyCode != lastKeyDownCode || nowMs - lastKeyDownMs >= minInterTapGapMs) {
            holdDetected = false
            lastKeyDownMs = nowMs
            lastKeyDownCode = keyCode
        }
    }

    /**
     * Returns:
     * - "ARMED" when 3x Volume Up completes Stage 1
     * - "CONFIRMED" when 3x Volume Down completes Stage 2 within the armed window
     * - "CANCELLED" when an armed state is invalidated by wrong key or timeout
     * - null when normal volume adjustment occurs without state transition
     */
    fun onKeyUp(keyCode: Int, nowMs: Long): String? {
        val expired = checkExpired(nowMs)
        val pressDuration = (nowMs - lastKeyDownMs).coerceAtLeast(0L)
        if (holdDetected || pressDuration > maxTapDurationMs) {
            holdDetected = false
            volumeUpTaps.clear()
            volumeDownTaps.clear()
            return if (expired) "CANCELLED" else null
        }
        holdDetected = false

        if (nowMs - lastConfirmedAtMs < cooldownDurationMs) {
            return if (expired) "CANCELLED" else null
        }

        if (state == State.IDLE) {
            if (keyCode == KeyEvent.KEYCODE_VOLUME_UP) {
                volumeDownTaps.clear()
                if (volumeUpTaps.isNotEmpty()) {
                    val gap = nowMs - volumeUpTaps.last()
                    if (gap < minInterTapGapMs || gap > maxInterTapGapMs) {
                        volumeUpTaps.clear()
                    }
                }
                volumeUpTaps.removeAll { nowMs - it > maxSequenceSpanMs }
                volumeUpTaps.add(nowMs)
                if (volumeUpTaps.size >= 3) {
                    volumeUpTaps.clear()
                    state = State.ARMED_AWAITING_VOLUME_DOWN
                    armedAtMs = nowMs
                    armedExpiresAtMs = nowMs + armedWindowDurationMs
                    return "ARMED"
                }
            } else if (keyCode == KeyEvent.KEYCODE_VOLUME_DOWN) {
                // Pressing Volume Down while IDLE never arms or triggers SOS
                volumeUpTaps.clear()
                volumeDownTaps.clear()
            }
            return if (expired) "CANCELLED" else null
        }

        // State == ARMED_AWAITING_VOLUME_DOWN
        if (keyCode == KeyEvent.KEYCODE_VOLUME_DOWN) {
            if (volumeDownTaps.isNotEmpty()) {
                val gap = nowMs - volumeDownTaps.last()
                if (gap < minInterTapGapMs || gap > maxInterTapGapMs) {
                    volumeDownTaps.clear()
                }
            }
            volumeDownTaps.removeAll { nowMs - it > maxSequenceSpanMs }
            volumeDownTaps.add(nowMs)
            if (volumeDownTaps.size >= 3 && nowMs <= armedExpiresAtMs) {
                reset()
                lastConfirmedAtMs = nowMs
                return "CONFIRMED"
            }
            return null
        } else if (keyCode == KeyEvent.KEYCODE_VOLUME_UP) {
            // Pressing Volume Up while awaiting Volume Down cancels the armed window
            reset()
            return "CANCELLED"
        }

        return null
    }
}

class MainActivity : FlutterActivity(), SensorEventListener {
    private val channelName = "sakhi/native_actions"
    private val sosChannelId = "sakhi_sos_Confirmation_channel"
    private val sosNotificationId = 9112
    private val permissionRequestCode = 4412

    private var methodChannel: MethodChannel? = null
    private var pendingPermissionResult: MethodChannel.Result? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    private var sensorManager: SensorManager? = null
    private var accelerometer: Sensor? = null
    private var audioManager: AudioManager? = null
    private var audioFocusRequest: AudioFocusRequest? = null

    private var powerShortcutEnabled: Boolean = true
    private var shakeShortcutEnabled: Boolean = false
    private var shakeThresholdG: Float = 2.35f

    private val shakeTimestamps = mutableListOf<Long>()
    private var lastTriggerTimeMs: Long = 0L

    // Two-Stage SOS Hardware Volume-Key State Machine (Section 5)
    private val sosVolumeStateMachine = SosVolumeKeyStateMachine()
    private val sosExpiryRunnable = Runnable {
        if (sosVolumeStateMachine.checkExpired(System.currentTimeMillis())) {
            methodChannel?.invokeMethod(
                "onSosVolumeShortcutCancelled",
                mapOf("reason" to "TIMEOUT")
            )
        }
    }

    private var noisyAudioReceiverRegistered = false
    private var isActivityResumed = false

    private val wellnessChannelId = "sakhi_wellness_discreet_channel"
    private val wellnessNotificationId = 9215

    // Meditation Audio Engine (supports verified local cached file playback + 42-track harmonic fallback)
    @Volatile
    private var meditationPlaying = false
    @Volatile
    private var meditationPaused = false
    @Volatile
    private var meditationVolume = 0.65f
    @Volatile
    private var isDuckedForVoice = false
    @Volatile
    private var meditationTrackIndex = 0
    private var sessionRotationCounter = 0
    private var meditationThread: Thread? = null
    private var meditationAudioTrack: AudioTrack? = null
    private var meditationMediaPlayer: MediaPlayer? = null

    private val audioFocusListener = AudioManager.OnAudioFocusChangeListener { focusChange ->
        when (focusChange) {
            AudioManager.AUDIOFOCUS_LOSS -> {
                stopMeditationAudioAll()
                mainHandler.post {
                    methodChannel?.invokeMethod(
                        "onMeditationAudioInterruption",
                        mapOf("type" to "AUDIOFOCUS_LOSS", "action" to "STOPPED")
                    )
                }
            }
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> {
                pauseMeditationAudioAll()
                mainHandler.post {
                    methodChannel?.invokeMethod(
                        "onMeditationAudioInterruption",
                        mapOf("type" to "PHONE_CALL_OR_TRANSIENT_LOSS", "action" to "PAUSED")
                    )
                }
            }
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK -> {
                isDuckedForVoice = true
                applyEffectiveMeditationVolume()
            }
            AudioManager.AUDIOFOCUS_GAIN -> {
                isDuckedForVoice = false
                applyEffectiveMeditationVolume()
            }
        }
    }

    private val noisyAudioReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == AudioManager.ACTION_AUDIO_BECOMING_NOISY) {
                if (meditationPlaying) {
                    pauseMeditationAudioAll()
                    mainHandler.post {
                        methodChannel?.invokeMethod(
                            "onMeditationAudioInterruption",
                            mapOf("type" to "HEADPHONE_DISCONNECTED", "action" to "PAUSED")
                        )
                    }
                }
            }
        }
    }

    override fun shouldRestoreAndSaveState(): Boolean = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        sensorManager = getSystemService(Context.SENSOR_SERVICE) as? SensorManager
        accelerometer = sensorManager?.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        audioManager = getSystemService(Context.AUDIO_SERVICE) as? AudioManager
        createSosNotificationChannel()
        registerNoisyAudioReceiverIfNeeded()
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
                    val message = call.argument<String>("message")
                        ?: "Hello! I found your women-owned business on Sakhi."
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
                        } catch (_: Exception) {
                        }
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
                    if (!powerShortcutEnabled) {
                        cancelArmedSosVolumeShortcut("SHORTCUT_DISABLED")
                    }
                    updateSensorRegistration()
                    result.success(
                        mapOf(
                            "powerShortcutEnabled" to powerShortcutEnabled,
                            "shakeShortcutEnabled" to shakeShortcutEnabled,
                            "shakeThresholdG" to shakeThresholdG
                        )
                    )
                }

                "getSosVolumeShortcutState" -> {
                    val now = System.currentTimeMillis()
                    sosVolumeStateMachine.checkExpired(now)
                    result.success(
                        mapOf(
                            "state" to sosVolumeStateMachine.state.name,
                            "armedAtMs" to sosVolumeStateMachine.armedAtMs,
                            "expiresAtMs" to sosVolumeStateMachine.armedExpiresAtMs,
                            "remainingMs" to (sosVolumeStateMachine.armedExpiresAtMs - now).coerceAtLeast(0L)
                        )
                    )
                }

                "cancelArmedSosVolumeShortcut" -> {
                    cancelArmedSosVolumeShortcut("USER_CANCELLED")
                    result.success(mapOf("cancelled" to true))
                }

                "vibrateFeedback" -> {
                    vibrateAlert()
                    result.success(true)
                }

                "showSosPullDownNotification" -> {
                    val source = call.argument<String>("source") ?: "VOLUME_UP_3X_THEN_DOWN_3X"
                    showHighPrioritySosNotification(source)
                    result.success(true)
                }

                "startMeditationAudio" -> {
                    val vol = (call.argument<Double>("volume") ?: 0.65).toFloat().coerceIn(0f, 1f)
                    val requestedTrack = call.argument<Int>("trackIndex") ?: -1
                    val localFilePath = call.argument<String>("localFilePath")?.trim()
                    meditationVolume = vol
                    meditationTrackIndex = if (requestedTrack in 0..41) {
                        requestedTrack
                    } else {
                        (sessionRotationCounter++) % 42
                    }
                    requestMeditationAudioFocus()
                    if (!localFilePath.isNullOrEmpty() && File(localFilePath).isFile) {
                        val startedFile = startLocalFileMeditationAudio(localFilePath)
                        if (startedFile) {
                            result.success(
                                mapOf(
                                    "playing" to true,
                                    "mode" to "LOCAL_CACHED_FILE",
                                    "trackIndex" to meditationTrackIndex,
                                    "localFilePath" to localFilePath
                                )
                            )
                            return@setMethodCallHandler
                        }
                    }
                    startSynthesizedMeditationAudio()
                    result.success(
                        mapOf(
                            "playing" to true,
                            "mode" to "SYNTHESIZED_FALLBACK",
                            "trackIndex" to meditationTrackIndex
                        )
                    )
                }

                "pauseMeditationAudio" -> {
                    pauseMeditationAudioAll()
                    result.success(true)
                }

                "resumeMeditationAudio" -> {
                    resumeMeditationAudioAll()
                    result.success(true)
                }

                "stopMeditationAudio" -> {
                    stopMeditationAudioAll()
                    abandonMeditationAudioFocus()
                    result.success(true)
                }

                "setMeditationDucking" -> {
                    isDuckedForVoice = call.argument<Boolean>("ducked") ?: false
                    applyEffectiveMeditationVolume()
                    result.success(true)
                }

                "setMeditationVolume" -> {
                    val vol = (call.argument<Double>("volume") ?: 0.65).toFloat().coerceIn(0f, 1f)
                    meditationVolume = vol
                    applyEffectiveMeditationVolume()
                    result.success(true)
                }

                "setMeditationTrack" -> {
                    val idx = (call.argument<Int>("trackIndex") ?: 0).coerceIn(0, 41)
                    meditationTrackIndex = idx
                    result.success(mapOf("trackIndex" to meditationTrackIndex))
                }

                "scheduleDiscreetWellnessReminder" -> {
                    handleScheduleDiscreetWellnessReminder(call, result)
                }

                "cancelDiscreetWellnessReminder" -> {
                    val cancelled = cancelScheduledDiscreetWellnessReminder()
                    result.success(mapOf("cancelled" to cancelled))
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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "sakhi/safety_hardware")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "scheduleDiscreetWellnessReminder" -> {
                        handleScheduleDiscreetWellnessReminder(call, result)
                    }
                    "cancelDiscreetWellnessReminder" -> {
                        val cancelled = cancelScheduledDiscreetWellnessReminder()
                        result.success(mapOf("cancelled" to cancelled))
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun cancelArmedSosVolumeShortcut(reason: String) {
        mainHandler.removeCallbacks(sosExpiryRunnable)
        if (sosVolumeStateMachine.reset()) {
            mainHandler.post {
                methodChannel?.invokeMethod(
                    "onSosVolumeShortcutCancelled",
                    mapOf("reason" to reason)
                )
            }
        }
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        val code = event.keyCode
        if (powerShortcutEnabled &&
            (code == KeyEvent.KEYCODE_VOLUME_UP || code == KeyEvent.KEYCODE_VOLUME_DOWN)
        ) {
            val now = System.currentTimeMillis()
            if (event.action == KeyEvent.ACTION_DOWN) {
                sosVolumeStateMachine.onKeyDown(code, event.repeatCount, event.isLongPress, now)
            } else if (event.action == KeyEvent.ACTION_UP) {
                when (sosVolumeStateMachine.onKeyUp(code, now)) {
                    "ARMED" -> {
                        mainHandler.removeCallbacks(sosExpiryRunnable)
                        mainHandler.postDelayed(sosExpiryRunnable, 8100L)
                        // Subtle single vibration cue indicating Stage 1 armed
                        vibrateShortCue()
                        methodChannel?.invokeMethod(
                            "onSosVolumeShortcutArmed",
                            mapOf(
                                "armedAtMs" to sosVolumeStateMachine.armedAtMs,
                                "expiresAtMs" to sosVolumeStateMachine.armedExpiresAtMs,
                                "windowSeconds" to 8,
                                "instruction" to "SOS Armed: Press Volume Down 3 times within 8 seconds to confirm emergency dispatch, or tap Cancel."
                            )
                        )
                    }
                    "CONFIRMED" -> {
                        mainHandler.removeCallbacks(sosExpiryRunnable)
                        lastTriggerTimeMs = now
                        fireDiscreetSosTrigger("VOLUME_UP_3X_THEN_DOWN_3X", now, null)
                    }
                    "CANCELLED" -> {
                        mainHandler.removeCallbacks(sosExpiryRunnable)
                        methodChannel?.invokeMethod(
                            "onSosVolumeShortcutCancelled",
                            mapOf("reason" to "SEQUENCE_RESET")
                        )
                    }
                }
            }
        }
        // Always delegate to super so normal volume adjustment and accessibility controls work
        return super.dispatchKeyEvent(event)
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
                description = "High-priority pull-down confirmation alert for confirmed 2-stage SOS triggers"
                enableVibration(true)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            nm?.createNotificationChannel(channel)

            val wellnessChannel = NotificationChannel(
                wellnessChannelId,
                "Sakhi Discreet Wellness Check-Ins",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "Discreet lock-screen reminders for personal wellness and cycle calendar updates"
                enableVibration(false)
                lockscreenVisibility = Notification.VISIBILITY_PRIVATE
            }
            nm?.createNotificationChannel(wellnessChannel)
        }
    }

    private fun handleScheduleDiscreetWellnessReminder(
        call: io.flutter.plugin.common.MethodCall,
        result: MethodChannel.Result
    ) {
        val nextPeriodStart = (call.argument<String>("nextPeriodStart") ?: "").trim()
        val daysBefore = (call.argument<Int>("daysBefore") ?: 2).coerceIn(1, 7)
        val discreet = call.argument<Boolean>("discreet") ?: true
        val rawTitle = (call.argument<String>("title") ?: "Wellness Check-In").trim()
        val rawBody = (call.argument<String>("body")
            ?: "You have a personal calendar update waiting in your wellness tracker.").trim()

        val safeTitle = if (discreet) "Wellness Check-In" else rawTitle
        val safeBody = if (discreet) {
            "You have a personal calendar update waiting in your wellness tracker."
        } else {
            rawBody
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.POST_NOTIFICATIONS
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            result.error(
                "NOTIFICATION_PERMISSION_DENIED",
                "Notification permission is required to schedule cycle reminders.",
                null
            )
            return
        }

        val dateMatch = Regex("^(\\d{4})-(\\d{2})-(\\d{2})$").find(nextPeriodStart)
        if (dateMatch == null) {
            cancelScheduledDiscreetWellnessReminder()
            result.error(
                "INVALID_REMINDER_DATE",
                "Provide a valid nextPeriodStart date in YYYY-MM-DD format.",
                null
            )
            return
        }

        val year = dateMatch.groupValues[1].toIntOrNull() ?: 0
        val month = dateMatch.groupValues[2].toIntOrNull() ?: 0
        val day = dateMatch.groupValues[3].toIntOrNull() ?: 0
        if (year < 2024 || month !in 1..12 || day !in 1..31) {
            result.error("INVALID_REMINDER_DATE", "Out-of-range calendar date.", null)
            return
        }

        val calendar = java.util.Calendar.getInstance().apply {
            set(java.util.Calendar.YEAR, year)
            set(java.util.Calendar.MONTH, month - 1)
            set(java.util.Calendar.DAY_OF_MONTH, day)
            set(java.util.Calendar.HOUR_OF_DAY, 9)
            set(java.util.Calendar.MINUTE, 0)
            set(java.util.Calendar.SECOND, 0)
            set(java.util.Calendar.MILLISECOND, 0)
            add(java.util.Calendar.DAY_OF_YEAR, -daysBefore)
        }

        val triggerAtMillis = calendar.timeInMillis
        val nowMillis = System.currentTimeMillis()
        if (triggerAtMillis <= nowMillis) {
            cancelScheduledDiscreetWellnessReminder()
            result.success(
                mapOf(
                    "scheduled" to false,
                    "reason" to "Target reminder date is in the past; skipped immediate notification.",
                    "targetEpochMillis" to triggerAtMillis
                )
            )
            return
        }

        try {
            val prefs = getSharedPreferences("sakhi_wellness_reminders", Context.MODE_PRIVATE)
            prefs.edit()
                .putLong("triggerAtMillis", triggerAtMillis)
                .putString("title", safeTitle)
                .putString("body", safeBody)
                .putString("nextPeriodStart", nextPeriodStart)
                .putInt("daysBefore", daysBefore)
                .putBoolean("discreet", discreet)
                .apply()

            val scheduledOk = DiscreetWellnessReminderReceiver.scheduleAlarm(
                this,
                triggerAtMillis,
                safeTitle,
                safeBody
            )
            if (!scheduledOk) {
                result.error(
                    "ALARM_SCHEDULE_FAILED",
                    "System AlarmManager service was unavailable.",
                    null
                )
                return
            }
            result.success(
                mapOf(
                    "scheduled" to true,
                    "triggerAtMillis" to triggerAtMillis,
                    "nextPeriodStart" to nextPeriodStart,
                    "daysBefore" to daysBefore
                )
            )
        } catch (e: Exception) {
            result.error("SCHEDULE_EXCEPTION", e.message ?: "Failed to schedule reminder.", null)
        }
    }

    private fun cancelScheduledDiscreetWellnessReminder(): Boolean {
        return try {
            val prefs = getSharedPreferences("sakhi_wellness_reminders", Context.MODE_PRIVATE)
            prefs.edit().clear().apply()
            DiscreetWellnessReminderReceiver.cancelAlarm(this)
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            nm?.cancel(wellnessNotificationId)
            true
        } catch (_: Exception) {
            false
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
                .setContentTitle("Sakhi SOS Shortcut Confirmed ($cleanSource)")
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

    private fun requestMeditationAudioFocus() {
        val am = audioManager ?: return
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val req = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                    .setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_MEDIA)
                            .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                            .build()
                    )
                    .setAcceptsDelayedFocusGain(true)
                    .setWillPauseWhenDucked(false)
                    .setOnAudioFocusChangeListener(audioFocusListener, mainHandler)
                    .build()
                audioFocusRequest = req
                am.requestAudioFocus(req)
            } else {
                @Suppress("DEPRECATION")
                am.requestAudioFocus(
                    audioFocusListener,
                    AudioManager.STREAM_MUSIC,
                    AudioManager.AUDIOFOCUS_GAIN
                )
            }
        } catch (_: Exception) {
        }
    }

    private fun abandonMeditationAudioFocus() {
        val am = audioManager ?: return
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                audioFocusRequest?.let { am.abandonAudioFocusRequest(it) }
            } else {
                @Suppress("DEPRECATION")
                am.abandonAudioFocus(audioFocusListener)
            }
        } catch (_: Exception) {
        }
    }

    private fun applyEffectiveMeditationVolume() {
        val effective = (if (isDuckedForVoice) meditationVolume * 0.38f else meditationVolume).coerceIn(0f, 1f)
        try {
            meditationAudioTrack?.setVolume(effective)
        } catch (_: Exception) {
        }
        try {
            meditationMediaPlayer?.setVolume(effective, effective)
        } catch (_: Exception) {
        }
    }

    private fun startLocalFileMeditationAudio(localFilePath: String): Boolean {
        stopMeditationAudioAll()
        return try {
            val mp = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .build()
                )
                setDataSource(localFilePath)
                isLooping = true
                prepare()
            }
            val effective = (if (isDuckedForVoice) meditationVolume * 0.38f else meditationVolume).coerceIn(0f, 1f)
            mp.setVolume(effective, effective)
            mp.start()
            meditationMediaPlayer = mp
            meditationPlaying = true
            meditationPaused = false
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun pauseMeditationAudioAll() {
        meditationPaused = true
        try {
            if (meditationMediaPlayer?.isPlaying == true) {
                meditationMediaPlayer?.pause()
            }
        } catch (_: Exception) {
        }
        try {
            meditationAudioTrack?.pause()
        } catch (_: Exception) {
        }
    }

    private fun resumeMeditationAudioAll() {
        if (!meditationPlaying) return
        meditationPaused = false
        try {
            meditationMediaPlayer?.start()
        } catch (_: Exception) {
        }
        try {
            meditationAudioTrack?.play()
        } catch (_: Exception) {
        }
    }

    private fun stopMeditationAudioAll() {
        meditationPlaying = false
        meditationPaused = false
        try {
            meditationMediaPlayer?.stop()
        } catch (_: Exception) {
        }
        try {
            meditationMediaPlayer?.release()
        } catch (_: Exception) {
        }
        meditationMediaPlayer = null
        try {
            meditationThread?.join(250L)
        } catch (_: Exception) {
        }
        meditationThread = null
        meditationAudioTrack = null
    }

    private fun startSynthesizedMeditationAudio() {
        stopMeditationAudioAll()
        meditationPlaying = true
        meditationPaused = false
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
                    AudioManager.STREAM_MUSIC,
                    sampleRate,
                    AudioFormat.CHANNEL_OUT_MONO,
                    AudioFormat.ENCODING_PCM_16BIT,
                    minBuf,
                    AudioTrack.MODE_STREAM
                )
            }

            meditationAudioTrack = track
            try {
                applyEffectiveMeditationVolume()
                track.play()
                val pcm = ShortArray(bufferSamples)
                var sampleIndex = 0L
                val scales = arrayOf(
                    doubleArrayOf(216.0, 288.0, 324.0, 384.0, 432.0, 512.0),
                    doubleArrayOf(174.61, 220.0, 261.63, 329.63, 392.0, 440.0),
                    doubleArrayOf(196.0, 246.94, 293.66, 392.0, 493.88, 587.33),
                    doubleArrayOf(240.0, 270.0, 300.0, 360.0, 400.0, 480.0),
                    doubleArrayOf(144.0, 216.0, 288.0, 324.0, 384.0, 432.0),
                    doubleArrayOf(264.0, 330.0, 396.0, 528.0, 660.0, 792.0)
                )
                while (meditationPlaying) {
                    if (meditationPaused) {
                        Thread.sleep(80L)
                        continue
                    }
                    val activeScale = scales[meditationTrackIndex % scales.size]
                    val effVol = if (isDuckedForVoice) meditationVolume * 0.38f else meditationVolume
                    for (i in 0 until bufferSamples) {
                        val t = sampleIndex.toDouble() / sampleRate.toDouble()
                        val padRoot = activeScale[0] * 0.5
                        val padFifth = padRoot * 1.5
                        val breathSwell = 0.45 + 0.35 * sin(2.0 * PI * 0.08 * t)
                        val warmPad = (sin(2.0 * PI * padRoot * t) * 0.30 +
                            sin(2.0 * PI * padFifth * t) * 0.16) * breathSwell

                        val noteInterval = 3.5
                        val noteIdx = ((t / noteInterval).toInt()) % activeScale.size
                        val noteAge = t % noteInterval
                        val noteFreq = activeScale[noteIdx]
                        val attack = (noteAge / 0.12).coerceIn(0.0, 1.0)
                        val decay = exp(-noteAge * 1.35)
                        val bellEnv = attack * decay
                        val bellTone = (sin(2.0 * PI * noteFreq * t) * 0.42 +
                            sin(2.0 * PI * (noteFreq * 2.0) * t) * 0.12 * exp(-noteAge * 2.4)) * bellEnv

                        val t2 = t + 1.75
                        val noteIdx2 = ((t2 / noteInterval).toInt() + 2) % activeScale.size
                        val noteAge2 = t2 % noteInterval
                        val attack2 = (noteAge2 / 0.15).coerceIn(0.0, 1.0)
                        val bellTone2 = sin(2.0 * PI * activeScale[noteIdx2] * t) * 0.22 * attack2 * exp(-noteAge2 * 1.5)

                        val mixed = (warmPad + bellTone + bellTone2) * effVol
                        pcm[i] = (mixed * 7200.0).toInt().coerceIn(-28000, 28000).toShort()
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

    override fun onResume() {
        super.onResume()
        isActivityResumed = true
        // Reset any partially armed volume-key sequence across lifecycle transitions (Section 5.6)
        cancelArmedSosVolumeShortcut("ACTIVITY_RESUMED")
        updateSensorRegistration()
    }

    override fun onPause() {
        isActivityResumed = false
        // Reset armed volume-key sequence on pause so stale armed states never linger (Section 5.6)
        cancelArmedSosVolumeShortcut("ACTIVITY_PAUSED")
        super.onPause()
        if (!shakeShortcutEnabled) {
            sensorManager?.unregisterListener(this)
        }
    }

    override fun onDestroy() {
        mainHandler.removeCallbacks(sosExpiryRunnable)
        stopMeditationAudioAll()
        abandonMeditationAudioFocus()
        sensorManager?.unregisterListener(this)
        if (noisyAudioReceiverRegistered) {
            try {
                unregisterReceiver(noisyAudioReceiver)
            } catch (_: Exception) {
            }
            noisyAudioReceiverRegistered = false
        }
        super.onDestroy()
    }

    private fun registerNoisyAudioReceiverIfNeeded() {
        if (noisyAudioReceiverRegistered) return
        try {
            val filter = IntentFilter(AudioManager.ACTION_AUDIO_BECOMING_NOISY)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(noisyAudioReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
            } else {
                registerReceiver(noisyAudioReceiver, filter)
            }
            noisyAudioReceiverRegistered = true
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

    private fun vibrateShortCue() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vm = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
                vm?.defaultVibrator?.vibrate(
                    VibrationEffect.createOneShot(90L, VibrationEffect.DEFAULT_AMPLITUDE)
                )
            } else {
                @Suppress("DEPRECATION")
                val v = getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    v?.vibrate(VibrationEffect.createOneShot(90L, VibrationEffect.DEFAULT_AMPLITUDE))
                } else {
                    @Suppress("DEPRECATION")
                    v?.vibrate(90L)
                }
            }
        } catch (_: Exception) {
        }
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

class DiscreetWellnessReminderReceiver : BroadcastReceiver() {
    companion object {
        const val ACTION_REMINDER = "com.example.women_safety_app.ACTION_DISCREET_WELLNESS_REMINDER"
        private const val CHANNEL_ID = "sakhi_wellness_discreet_channel"
        private const val NOTIFICATION_ID = 9215
        private const val REQUEST_CODE = 9215

        fun scheduleAlarm(
            context: Context,
            triggerAtMillis: Long,
            title: String,
            body: String
        ): Boolean {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
                ?: return false
            val intent = Intent(context, DiscreetWellnessReminderReceiver::class.java).apply {
                action = ACTION_REMINDER
                putExtra("title", title)
                putExtra("body", body)
            }
            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
            val pendingIntent = PendingIntent.getBroadcast(context, REQUEST_CODE, intent, flags)
            alarmManager.cancel(pendingIntent)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
                alarmManager.setWindow(
                    AlarmManager.RTC_WAKEUP,
                    triggerAtMillis,
                    15 * 60 * 1000L,
                    pendingIntent
                )
            } else {
                alarmManager.set(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
            }
            return true
        }

        fun cancelAlarm(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
            val intent = Intent(context, DiscreetWellnessReminderReceiver::class.java).apply {
                action = ACTION_REMINDER
            }
            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_NO_CREATE
            }
            val pendingIntent = PendingIntent.getBroadcast(context, REQUEST_CODE, intent, flags)
            if (pendingIntent != null) {
                alarmManager.cancel(pendingIntent)
                pendingIntent.cancel()
            }
        }
    }

    override fun onReceive(context: Context?, intent: Intent?) {
        val ctx = context ?: return
        val action = intent?.action ?: return
        val prefs = ctx.getSharedPreferences("sakhi_wellness_reminders", Context.MODE_PRIVATE)

        if (action == Intent.ACTION_BOOT_COMPLETED || action == Intent.ACTION_MY_PACKAGE_REPLACED) {
            val triggerAt = prefs.getLong("triggerAtMillis", 0L)
            if (triggerAt > System.currentTimeMillis()) {
                val title = prefs.getString("title", "Wellness Check-In") ?: "Wellness Check-In"
                val body = prefs.getString(
                    "body",
                    "You have a personal calendar update waiting in your wellness tracker."
                ) ?: "You have a personal calendar update waiting in your wellness tracker."
                scheduleAlarm(ctx, triggerAt, title, body)
            }
            return
        }

        if (action == ACTION_REMINDER) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                ContextCompat.checkSelfPermission(
                    ctx,
                    Manifest.permission.POST_NOTIFICATIONS
                ) != PackageManager.PERMISSION_GRANTED
            ) {
                return
            }
            val title = intent.getStringExtra("title")
                ?: prefs.getString("title", "Wellness Check-In")
                ?: "Wellness Check-In"
            val body = intent.getStringExtra("body")
                ?: prefs.getString(
                    "body",
                    "You have a personal calendar update waiting in your wellness tracker."
                )
                ?: "You have a personal calendar update waiting in your wellness tracker."

            val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val wellnessChannel = NotificationChannel(
                    CHANNEL_ID,
                    "Sakhi Discreet Wellness Check-Ins",
                    NotificationManager.IMPORTANCE_DEFAULT
                ).apply {
                    description = "Discreet lock-screen reminders for personal wellness and cycle calendar updates"
                    enableVibration(false)
                    lockscreenVisibility = Notification.VISIBILITY_PRIVATE
                }
                nm.createNotificationChannel(wellnessChannel)
            }
            val launchIntent = Intent(ctx, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
            val pendingIntent = PendingIntent.getActivity(ctx, 215, launchIntent, pendingFlags)
            val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(ctx, CHANNEL_ID)
            } else {
                @Suppress("DEPRECATION")
                Notification.Builder(ctx)
            }
            builder
                .setSmallIcon(android.R.drawable.ic_popup_reminder)
                .setContentTitle(title)
                .setContentText(body)
                .setContentIntent(pendingIntent)
                .setAutoCancel(true)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                builder.setVisibility(Notification.VISIBILITY_PRIVATE)
            }
            nm.notify(NOTIFICATION_ID, builder.build())
            prefs.edit().remove("triggerAtMillis").apply()
        }
    }
}
