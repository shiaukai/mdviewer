import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var bookmarks: BookmarkChannel?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // Remember the window size; start at a comfortable reading size.
    if !self.setFrameUsingName("MainWindow") {
      self.setContentSize(NSSize(width: 1200, height: 800))
      self.center()
    }
    self.setFrameAutosaveName("MainWindow")
    self.minSize = NSSize(width: 360, height: 480)

    RegisterGeneratedPlugins(registry: flutterViewController)
    let messenger = flutterViewController.engine.binaryMessenger
    (NSApp.delegate as? AppDelegate)?.attachFileChannel(binaryMessenger: messenger)
    bookmarks = BookmarkChannel(messenger: messenger)

    super.awakeFromNib()
  }
}

/// App Sandbox only lets the app read files the user picked, dropped or opened
/// from Finder, and only until it quits. Security-scoped bookmarks carry that
/// permission over to later launches (recent files, the sidebar folder,
/// folders granted for relative images).
final class BookmarkChannel {
  private let channel: FlutterMethodChannel
  /// Resolved URLs stay accessible for the app's lifetime.
  private var accessed: [URL] = []

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "mdviewer/bookmarks", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "create":
      // Only succeeds while the app currently has access to the path.
      guard let path = call.arguments as? String else {
        result(FlutterError(code: "bad_args", message: "Expected a path", details: nil))
        return
      }
      do {
        let data = try URL(fileURLWithPath: path).bookmarkData(
          options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
        result(data.base64EncodedString())
      } catch {
        result(FlutterError(code: "create_failed", message: error.localizedDescription, details: nil))
      }
    case "resolve":
      guard let encoded = call.arguments as? String, let data = Data(base64Encoded: encoded) else {
        result(FlutterError(code: "bad_args", message: "Expected bookmark data", details: nil))
        return
      }
      do {
        var stale = false
        let url = try URL(
          resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil,
          bookmarkDataIsStale: &stale)
        if url.startAccessingSecurityScopedResource() {
          accessed.append(url)
        }
        result(["path": url.path, "stale": stale])
      } catch {
        result(FlutterError(code: "resolve_failed", message: error.localizedDescription, details: nil))
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
