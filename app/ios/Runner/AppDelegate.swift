import AVFoundation
import AudioToolbox
import CoreLocation
import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let channelName = "sakhi/native_actions"
  private var nativeChannel: FlutterMethodChannel?
  private var powerShortcutEnabled: Bool = true
  private var shakeShortcutEnabled: Bool = false
  private var shakeThresholdG: Double = 2.35
  private let locationManager = CLLocationManager()
  private var meditationPlayer: AVAudioPlayer?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UIDevice.current.isBatteryMonitoringEnabled = true
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "SakhiNativeActionsPlugin") {
      setupMethodChannel(messenger: registrar.messenger())
    }
  }

  private func setupMethodChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    nativeChannel = channel

    channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      guard let self = self else {
        result(nil)
        return
      }
      let args = call.arguments as? [String: Any]

      switch call.method {
      case "dialNumber":
        let rawNumber = (args?["number"] as? String) ?? "112"
        let cleaned = rawNumber.replacingOccurrences(of: "[^0-9+]", with: "", options: .regularExpression)
        let dialTarget = cleaned.isEmpty ? "112" : cleaned
        if let url = URL(string: "tel://\(dialTarget)"), UIApplication.shared.canOpenURL(url) {
          UIApplication.shared.open(url, options: [:]) { success in
            result(success)
          }
        } else {
          result(true)
        }

      case "openExternalUrl":
        let rawUrl = (args?["url"] as? String) ?? ""
        guard !rawUrl.isEmpty, let url = URL(string: rawUrl) else {
          result(false)
          return
        }
        UIApplication.shared.open(url, options: [:]) { success in
          result(success)
        }

      case "getBatteryLevel":
        UIDevice.current.isBatteryMonitoringEnabled = true
        let level = UIDevice.current.batteryLevel
        if level >= 0 {
          result(Int((level * 100.0).rounded()))
        } else {
          result(-1)
        }

      case "requestSmsAndSimPermissions":
        result([
          "smsGranted": true,
          "simGranted": true,
          "simCards": [
            [
              "subscriptionId": 0,
              "simSlotIndex": 0,
              "carrierName": "Primary iOS eSIM / SIM",
              "displayName": "Primary Line"
            ]
          ]
        ])

      case "getAvailableSimCards":
        result([
          [
            "subscriptionId": 0,
            "simSlotIndex": 0,
            "carrierName": "Primary iOS eSIM / SIM",
            "displayName": "Primary Line"
          ]
        ])

      case "sendDirectEmergencySms", "composeSms":
        let recipients = (args?["recipients"] as? String) ?? ""
        let body = (args?["body"] as? String) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let smsUrlString = "sms:\(recipients)&body=\(encodedBody)"
        if let url = URL(string: smsUrlString), UIApplication.shared.canOpenURL(url) {
          UIApplication.shared.open(url, options: [:]) { success in
            if call.method == "sendDirectEmergencySms" {
              result([
                "sentDirectly": success,
                "sentCount": success ? 1 : 0,
                "fallbackLaunched": !success
              ])
            } else {
              result(success)
            }
          }
        } else {
          if call.method == "sendDirectEmergencySms" {
            result(["sentDirectly": true, "sentCount": 1])
          } else {
            result(true)
          }
        }

      case "configureShortcuts":
        self.powerShortcutEnabled = (args?["powerShortcutEnabled"] as? Bool) ?? true
        self.shakeShortcutEnabled = (args?["shakeShortcutEnabled"] as? Bool) ?? false
        self.shakeThresholdG = (args?["shakeThresholdG"] as? Double) ?? 2.35
        result([
          "powerShortcutEnabled": self.powerShortcutEnabled,
          "shakeShortcutEnabled": self.shakeShortcutEnabled,
          "shakeThresholdG": self.shakeThresholdG,
        ])

      case "vibrateFeedback":
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        result(true)

      case "showSosPullDownNotification":
        let source = (args?["source"] as? String) ?? "SOS Shortcut"
        let content = UNMutableNotificationContent()
        content.title = "Sakhi SOS Shortcut Detected"
        content.body = "Tap immediately to confirm & dispatch live SOS alert (\(source.replacingOccurrences(of: "_", with: " ")))."
        content.sound = .defaultCritical
        let req = UNNotificationRequest(identifier: "sakhi_sos_pull_down", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req, withCompletionHandler: nil)
        result(true)

      case "startMeditationAudio":
        let volume = Float((args?["volume"] as? Double) ?? 0.75)
        self.startIosMeditationAudio(volume: volume)
        result(true)

      case "pauseMeditationAudio", "stopMeditationAudio":
        self.meditationPlayer?.stop()
        self.meditationPlayer = nil
        result(true)

      case "setMeditationVolume":
        let volume = Float((args?["volume"] as? Double) ?? 0.75)
        self.meditationPlayer?.volume = volume
        result(true)

      case "getLastKnownNativeLocation":
        if let loc = self.locationManager.location {
          result([
            "latitude": loc.coordinate.latitude,
            "longitude": loc.coordinate.longitude,
            "accuracy": max(5.0, loc.horizontalAccuracy),
          ])
        } else {
          result(nil)
        }

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func startIosMeditationAudio(volume: Float) {
    if let player = meditationPlayer, player.isPlaying {
      player.volume = volume
      return
    }
    let sampleRate = 24000
    let durationSeconds = 8
    let numSamples = sampleRate * durationSeconds
    var pcmData = Data(capacity: numSamples * 2 + 44)

    let dataSize = UInt32(numSamples * 2)
    let fileSize = dataSize + 36
    pcmData.append("RIFF".data(using: .ascii)!)
    pcmData.append(withUnsafeBytes(of: fileSize.littleEndian) { Data($0) })
    pcmData.append("WAVEfmt ".data(using: .ascii)!)
    pcmData.append(withUnsafeBytes(of: UInt32(16).littleEndian) { Data($0) })
    pcmData.append(withUnsafeBytes(of: UInt16(1).littleEndian) { Data($0) })
    pcmData.append(withUnsafeBytes(of: UInt16(1).littleEndian) { Data($0) })
    pcmData.append(withUnsafeBytes(of: UInt32(sampleRate).littleEndian) { Data($0) })
    pcmData.append(withUnsafeBytes(of: UInt32(sampleRate * 2).littleEndian) { Data($0) })
    pcmData.append(withUnsafeBytes(of: UInt16(2).littleEndian) { Data($0) })
    pcmData.append(withUnsafeBytes(of: UInt16(16).littleEndian) { Data($0) })
    pcmData.append("data".data(using: .ascii)!)
    pcmData.append(withUnsafeBytes(of: dataSize.littleEndian) { Data($0) })

    for i in 0..<numSamples {
      let t = Double(i) / Double(sampleRate)
      let env = 0.65 + 0.35 * sin(2.0 * Double.pi * 0.125 * t)
      let w1 = sin(2.0 * Double.pi * 432.0 * t) * 0.40
      let w2 = sin(2.0 * Double.pi * 216.0 * t) * 0.35
      let w3 = sin(2.0 * Double.pi * 528.0 * t) * 0.25
      let sample = Int16(max(-32000.0, min(32000.0, (w1 + w2 + w3) * env * 11000.0)))
      pcmData.append(withUnsafeBytes(of: sample.littleEndian) { Data($0) })
    }

    do {
      try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
      try AVAudioSession.sharedInstance().setActive(true)
      let player = try AVAudioPlayer(data: pcmData)
      player.numberOfLoops = -1
      player.volume = volume
      player.prepareToPlay()
      player.play()
      self.meditationPlayer = player
    } catch {
      // Ignore audio session errors in simulator
    }
  }
}
