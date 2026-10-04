import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/md_document.dart';

bool get isDesktopPlatform =>
    Platform.isMacOS || Platform.isWindows || Platform.isLinux;

bool get isMobilePlatform => Platform.isIOS || Platform.isAndroid;

/// A node in the folder tree shown in the desktop sidebar.
class FolderNode {
  FolderNode(this.path, this.isDirectory, [this.children = const []]);

  final String path;
  final bool isDirectory;
  final List<FolderNode> children;

  String get name => p.basename(path);
}

class FileService {
  static const _ignoredDirs = {'node_modules', 'build', 'Pods', 'DerivedData'};

  /// Shows the system file picker. Returns a readable local path.
  ///
  /// On mobile the picked file is copied into the app's library folder,
  /// because the picker's cached copy can be purged by the OS at any time.
  static Future<String?> pickMarkdownFile() async {
    final result = await FilePicker.pickFiles(
      dialogTitle: 'Open Markdown',
      // Android maps extensions to MIME types and greys out .md files on
      // many devices, so let the user pick anything there.
      type: Platform.isAndroid ? FileType.any : FileType.custom,
      allowedExtensions: Platform.isAndroid
          ? null
          : ['md', 'markdown', 'mdown', 'mkd', 'mkdn', 'txt'],
      lockParentWindow: true,
    );
    final path = result?.files.single.path;
    if (path == null) return null;
    return isMobilePlatform ? importToLibrary(path) : path;
  }

  static Future<String?> pickFolder({String? initialDirectory}) => FilePicker.getDirectoryPath(
        dialogTitle: 'Open Folder',
        lockParentWindow: true,
        initialDirectory: initialDirectory,
      );

  /// Whether the folder's contents can be read (false inside the macOS
  /// sandbox until the user grants the folder).
  static bool canReadFolder(String dir) {
    try {
      Directory(dir).listSync(followLinks: false);
      return true;
    } on FileSystemException {
      return false;
    }
  }

  static Future<Directory> libraryDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'Library'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  /// Copies an external file into the app library and returns the new path.
  static Future<String> importToLibrary(String source) async {
    final dir = await libraryDir();
    if (p.isWithin(dir.path, source)) return source;
    final target = p.join(dir.path, p.basename(source));
    await File(source).copy(target);
    return target;
  }

  static Future<bool> isInLibrary(String path) async =>
      isMobilePlatform && p.isWithin((await libraryDir()).path, path);

  static Future<MdDocument> load(String path) async {
    final bytes = await File(path).readAsBytes();
    return MdDocument(
      path: path,
      title: p.basename(path),
      content: decode(bytes),
    );
  }

  static String decode(List<int> bytes) {
    try {
      return utf8.decode(bytes);
    } on FormatException {
      // Not UTF-8: fall back to Latin-1 rather than refusing to open.
      return latin1.decode(bytes);
    }
  }

  /// Scans [root] for markdown files in a background isolate.
  static Future<FolderNode> scanFolder(String root) => compute(_scan, root);

  static FolderNode _scan(String root) {
    var budget = 5000;
    FolderNode walk(Directory dir, int depth) {
      final dirs = <FolderNode>[];
      final files = <FolderNode>[];
      List<FileSystemEntity> entries;
      try {
        entries = dir.listSync(followLinks: false);
      } on FileSystemException {
        entries = const [];
      }
      for (final e in entries) {
        if (budget <= 0) break;
        final name = p.basename(e.path);
        if (name.startsWith('.')) continue;
        if (e is Directory) {
          if (depth >= 8 || _ignoredDirs.contains(name)) continue;
          final child = walk(e, depth + 1);
          if (child.children.isNotEmpty) dirs.add(child);
        } else if (e is File && isMarkdownPath(e.path)) {
          files.add(FolderNode(e.path, false));
          budget--;
        }
      }
      int byName(FolderNode a, FolderNode b) =>
          a.name.toLowerCase().compareTo(b.name.toLowerCase());
      dirs.sort(byName);
      files.sort(byName);
      return FolderNode(dir.path, true, [...dirs, ...files]);
    }

    return walk(Directory(root), 0);
  }

  /// Emits whenever [path] changes on disk (debounced).
  ///
  /// Watches the parent directory so atomic saves (write temp + rename),
  /// which most editors use, are still caught.
  static Stream<void> watch(String path) {
    if (!isDesktopPlatform) return const Stream.empty();
    final name = p.basename(path).toLowerCase();
    late StreamController<void> controller;
    StreamSubscription<FileSystemEvent>? sub;
    Timer? debounce;
    controller = StreamController<void>(
      onListen: () {
        void changed() {
          debounce?.cancel();
          debounce = Timer(const Duration(milliseconds: 250), () => controller.add(null));
        }

        // The file alone, when the sandbox doesn't grant its folder.
        void watchFile() {
          try {
            sub = File(path).watch().listen((_) => changed(), onError: (_) {});
          } on FileSystemException {
            // Watching unsupported here; auto-reload is best effort.
          }
        }

        if (!canReadFolder(p.dirname(path))) {
          watchFile();
          return;
        }
        try {
          sub = Directory(p.dirname(path)).watch().listen((event) {
            final hit = p.basename(event.path).toLowerCase() == name ||
                (event is FileSystemMoveEvent &&
                    p.basename(event.destination ?? '').toLowerCase() == name);
            if (hit) changed();
          }, onError: (_) {});
        } on FileSystemException {
          watchFile();
        }
      },
      onCancel: () {
        debounce?.cancel();
        return sub?.cancel();
      },
    );
    return controller.stream;
  }
}
