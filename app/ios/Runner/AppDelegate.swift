import AudioToolbox
import CoreLocation
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let channelName = "sakhi/native_actions"
  private var nativeChannel: FlutterMethodChannel?
  private var powerShortcutEnabled: Bool = true
  private var shakeShortcutEnabled: Bool = false
  private var shakeThresholdG: Double = 2.35
  private let locationManager = CLLocationManager()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
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

      case "composeSms":
        let recipients = (args?["recipients"] as? String) ?? ""
        let body = (args?["body"] as? String) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let smsUrlString = "sms:\(recipients)&body=\(encodedBody)"
        if let url = URL(string: smsUrlString), UIApplication.shared.canOpenURL(url) {
          UIApplication.shared.open(url, options: [:]) { success in
            result(success)
          }
        } else {
          result(true)
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
}
