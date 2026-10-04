import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private var fileChannel: FlutterMethodChannel?
  /// Files opened from Finder before Dart asked for them.
  private var pendingFiles: [String] = []
  private var dartReady = false

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  /// Called by MainFlutterWindow once the engine exists.
  func attachFileChannel(binaryMessenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "mdviewer/files", binaryMessenger: binaryMessenger)
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

  /// Double-click / "Open With" in Finder, or dropping a file on the Dock icon.
  override func application(_ application: NSApplication, open urls: [URL]) {
    for url in urls where url.isFileURL {
      if dartReady {
        fileChannel?.invokeMethod("openFile", arguments: url.path)
      } else {
        pendingFiles.append(url.path)
      }
    }
    // Keep forwarding to plugins that listen for URLs.
    super.application(application, open: urls)
  }
}
