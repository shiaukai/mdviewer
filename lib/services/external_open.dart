import 'package:flutter/services.dart';

/// Files handed to the app by the OS ("Open with…", double-click in Finder,
/// "Open in" from the iOS Files app, Android VIEW intents).
///
/// The native side buffers paths that arrive before Dart is ready; Dart pulls
/// them once with `getInitialFiles`, then receives `openFile` pushes.
/// Windows passes files as command-line arguments to `main` instead.
class ExternalOpen {
  static const _channel = MethodChannel('mdviewer/files');

  static Future<List<String>> listen(void Function(String path) onOpen) async {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'openFile' && call.arguments is String) {
        onOpen(call.arguments as String);
      }
    });
    try {
      return await _channel.invokeListMethod<String>('getInitialFiles') ?? [];
    } on MissingPluginException {
      return [];
    }
  }
}
