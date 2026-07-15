import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let playbackStreamHandler = UnsupportedPlaybackEventStreamHandler()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let messenger = engineBridge.pluginRegistry
      .registrar(forPlugin: "PlaybackTelemetry")!
      .messenger()
    FlutterMethodChannel(
      name: "ai.companion.companion_mobile/playback_telemetry/methods",
      binaryMessenger: messenger
    ).setMethodCallHandler { call, result in
      if call.method == "arm" {
        // AVAudioSession exposes route/interruption state, not a reliable first
        // remote-frame render callback. Do not report a synthetic timestamp.
        result(["status": "unsupported"])
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    FlutterEventChannel(
      name: "ai.companion.companion_mobile/playback_telemetry/events",
      binaryMessenger: messenger
    ).setStreamHandler(playbackStreamHandler)
  }
}

private final class UnsupportedPlaybackEventStreamHandler: NSObject, FlutterStreamHandler {
  func onListen(withArguments arguments: Any?, eventSink events: FlutterEventSink?) -> FlutterError? {
    // No events: iOS lacks a public, renderer-specific first-frame callback in
    // the current dependency stack. The Dart layer records missing coverage.
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    return nil
  }
}
