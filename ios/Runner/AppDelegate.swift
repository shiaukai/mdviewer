import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var fileChannel: FlutterMethodChannel?
  /// Files received before Dart asked for them.
  private var pendingFiles: [String] = []
  private var dartReady = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "mdviewer/files", binaryMessenger: controller.binaryMessenger)
      channel.setMethodCallHandler { [weak self] call, result in
        guard let self = self, call.method == "getInitialFiles" else {
          result(FlutterMethodNotImplemented)
          return
        }
        result(self.pendingFiles)
        self.pendingFiles.removeAll()
        self.dartReady = true
      }
      fileChannel = channel
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// "Open in MD Viewer" from the Files app / share sheet. The system hands
  /// over a copy in Documents/Inbox; move it somewhere Dart can import from.
  override func application(
    _ app: UIApplication, open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    guard url.isFileURL else {
      return super.application(app, open: url, options: options)
    }
    let scoped = url.startAccessingSecurityScopedResource()
    defer { if scoped { url.stopAccessingSecurityScopedResource() } }

    let fm = FileManager.default
    let dir = fm.temporaryDirectory.appendingPathComponent("incoming", isDirectory: true)
    let target = dir.appendingPathComponent(url.lastPathComponent)
    do {
      try fm.createDirectory(at: dir, withIntermediateDirectories: true)
      if fm.fileExists(atPath: target.path) { try fm.removeItem(at: target) }
      try fm.copyItem(at: url, to: target)
    } catch {
      return false
    }
    if url.path.contains("/Documents/Inbox/") { try? fm.removeItem(at: url) }

    if dartReady {
      fileChannel?.invokeMethod("openFile", arguments: target.path)
    } else {
      pendingFiles.append(target.path)
    }
    return true
  }
}
