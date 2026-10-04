import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

/// macOS App Sandbox keeps file access only for the current launch. This
/// stores a security-scoped bookmark for every file/folder the user grants
/// (picker, drag & drop, Finder) and re-activates them on the next launch.
/// No-op on other platforms.
class Bookmarks {
  static const _channel = MethodChannel('mdviewer/bookmarks');
  static const _kBookmarks = 'securityBookmarks';

  static bool get enabled => Platform.isMacOS;

  static SharedPreferences? _prefs;
  static Map<String, String> _byPath = {};

  /// Re-activates saved bookmarks. Call before touching recent files.
  static Future<void> restore(SharedPreferences prefs) async {
    if (!enabled) return;
    _prefs = prefs;
    try {
      _byPath = Map<String, String>.from(jsonDecode(prefs.getString(_kBookmarks) ?? '{}') as Map);
    } on FormatException {
      _byPath = {};
    }
    for (final entry in _byPath.entries.toList()) {
      try {
        final resolved = await _channel.invokeMapMethod<String, Object?>('resolve', entry.value);
        final path = resolved?['path'] as String?;
        if (resolved?['stale'] == true && path != null) {
          // The file moved or was replaced: refresh the bookmark.
          _byPath.remove(entry.key);
          await _create(path);
        }
      } on PlatformException catch (e) {
        debugPrint('Dropping bookmark for ${entry.key}: ${e.message}');
        _byPath.remove(entry.key);
      } on MissingPluginException {
        return;
      }
    }
    _save();
  }

  /// Saves access to [path]. Must run while access is granted, i.e. right
  /// after the user picked/dropped/opened it.
  static Future<void> remember(String path) async {
    if (!enabled || _byPath.containsKey(path)) return;
    await _create(path);
    _save();
  }

  /// Drops bookmarks no longer needed: keeps [paths] and folders containing them.
  static void retainOnly(Iterable<String> paths) {
    if (!enabled) return;
    final keep = paths.toList();
    _byPath.removeWhere((key, _) => !keep.any((k) => k == key || p.isWithin(key, k)));
    _save();
  }

  static Future<void> _create(String path) async {
    try {
      final data = await _channel.invokeMethod<String>('create', path);
      if (data != null) _byPath[path] = data;
    } on PlatformException catch (e) {
      debugPrint('Could not bookmark $path: ${e.message}');
    } on MissingPluginException {
      // Not running in the macOS runner (tests).
    }
  }

  static void _save() => _prefs?.setString(_kBookmarks, jsonEncode(_byPath));
}
