import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var scheduleBridge: ScheduleBridge?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    let launched = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    if let controller = window?.rootViewController as? FlutterViewController {
      scheduleBridge = ScheduleBridge(messenger: controller.binaryMessenger)
    }
    return launched
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    scheduleBridge?.refresh()
  }
}
