import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/md_document.dart';
import '../monetization/ads.dart';
import '../monetization/store_config.dart';
import '../monetization/supporter.dart';
import '../services/bookmarks.dart';
import '../services/file_service.dart';
import 'viewer_controller.dart';

class AppState extends ChangeNotifier {
  AppState._(this._prefs, {required this.monetized})
      : themeMode = ThemeMode.values[(_prefs.getInt(_kTheme) ?? 0)
            .clamp(0, ThemeMode.values.length - 1)],
        textScale = _prefs.getDouble(_kTextScale) ?? 1.0,
        sidebarOpen = _prefs.getBool(_kSidebar) ?? true,
        outlineOpen = _prefs.getBool(_kOutline) ?? true,
        sidebarWidth = _prefs.getDouble(_kSidebarWidth) ?? 260,
        recent = _prefs.getStringList(_kRecent) ?? [],
        folderPath = _prefs.getString(_kFolder);

  static const _kTheme = 'themeMode';
  static const _kTextScale = 'textScale';
  static const _kSidebar = 'sidebarOpen';
  static const _kOutline = 'outlineOpen';
  static const _kSidebarWidth = 'sidebarWidth';
  static const _kRecent = 'recentFiles';
  static const _kFolder = 'folderPath';
  static const _kLastFile = 'lastFile';

  static const minTextScale = 0.8;
  static const maxTextScale = 1.6;

  static Future<AppState> load({bool monetized = StoreConfig.enabled}) async =>
      AppState._(await SharedPreferences.getInstance(), monetized: monetized);

  /// Official store build: show ads / the support bar and the supporter
  /// purchase. Off for builds from source.
  final bool monetized;

  final SharedPreferences _prefs;
  final viewer = ViewerController();
  late final supporter = SupporterController(_prefs)..onMessage = toast;
  final ads = AdsController();
  final messengerKey = GlobalKey<ScaffoldMessengerState>();

  ThemeMode themeMode;
  double textScale;

  /// Desktop layout panels (user preference; narrow widths may still hide
  /// the outline panel).
  bool sidebarOpen;
  bool outlineOpen;
  double sidebarWidth;

  /// Recently opened files. On mobile these are copies in the app library.
  List<String> recent;

  /// Folder shown in the desktop sidebar.
  String? folderPath;
  FolderNode? folderTree;
  bool scanning = false;

  /// Expanded sub-folders in the sidebar tree (kept across layout switches).
  final expandedDirs = <String>{};

  MdDocument? document;
  bool loading = false;

  /// macOS sandbox: the open document's folder isn't readable yet.
  bool _folderLocked = false;

  /// Show the "grant folder" banner: the document has relative images/links
  /// that the sandbox won't let us read.
  bool get needsFolderAccess =>
      Bookmarks.enabled && _folderLocked && (document?.hasLocalReferences ?? false);

  StreamSubscription<void>? _watchSub;

  int get _recentLimit => isMobilePlatform ? 200 : 20;

  // ---------------------------------------------------------------- startup

  /// Opens [launchFiles] if any, otherwise restores the previous session.
  Future<void> restore(List<String> launchFiles) async {
    await Bookmarks.restore(_prefs);
    if (folderPath != null && isDesktopPlatform) {
      // Also drops a folder the sandbox no longer lets us read.
      if (FileService.canReadFolder(folderPath!)) {
        unawaited(_scanFolder());
      } else {
        folderPath = null;
        await _prefs.remove(_kFolder);
      }
    }
    final launch = launchFiles.where((f) => File(f).existsSync()).toList();
    if (launch.isNotEmpty) {
      await openExternal(launch.first);
      return;
    }
    final last = _prefs.getString(_kLastFile);
    if (last != null && File(last).existsSync()) await openPath(last);
  }

  // -------------------------------------------------------------- documents

  Future<void> pickAndOpen() async {
    try {
      final path = await FileService.pickMarkdownFile();
      if (path != null) await openPath(path);
    } on PlatformException catch (e) {
      toast('無法開啟檔案選擇器：${e.message ?? e.code}');
    }
  }

  /// Opens a file handed over by the OS. On mobile it is imported first.
  Future<void> openExternal(String path) async {
    if (isDesktopPlatform && Directory(path).existsSync()) {
      await openFolder(path);
      return;
    }
    try {
      final local = isMobilePlatform ? await FileService.importToLibrary(path) : path;
      await openPath(local);
    } on FileSystemException catch (e) {
      toast('無法開啟：${e.message}');
    }
  }

  Future<void> openPath(String path, {String? anchor}) async {
    if (!File(path).existsSync()) {
      toast('無法開啟「${p.basename(path)}」：檔案可能已移動或刪除');
      if (recent.remove(path)) _saveRecent();
      notifyListeners();
      return;
    }
    loading = true;
    notifyListeners();
    try {
      final doc = await FileService.load(path);
      _showDocument(doc, anchor: anchor);
      _addRecent(path);
      _revealInTree(path);
      await Bookmarks.remember(path);
      await _prefs.setString(_kLastFile, path);
    } on FileSystemException catch (e) {
      toast('無法讀取：${e.message}');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> openSample() async {
    final content = await rootBundle.loadString('assets/sample.md');
    _showDocument(MdDocument(
      title: '使用說明.md',
      content: content,
      assetBase: 'assets',
    ));
    await _prefs.remove(_kLastFile);
    notifyListeners();
  }

  Future<void> reload({bool silent = false}) async {
    final path = document?.path;
    if (path == null) return;
    try {
      final doc = await FileService.load(path);
      if (doc.content == document?.content && silent) return;
      _showDocument(doc);
      if (!silent) toast('已重新載入');
      notifyListeners();
    } on FileSystemException {
      if (!silent) toast('檔案已不存在');
    }
  }

  void closeDocument() {
    document = null;
    _watchSub?.cancel();
    _watchSub = null;
    viewer.reset();
    _prefs.remove(_kLastFile);
    notifyListeners();
  }

  void _showDocument(MdDocument doc, {String? anchor}) {
    final sameFile = doc.path != null && doc.path == document?.path;
    if (!sameFile) {
      viewer.reset(anchor: anchor);
      _watchSub?.cancel();
      _watchSub = doc.path == null
          ? null
          : FileService.watch(doc.path!).listen((_) => reload(silent: true));
    } else if (anchor != null) {
      viewer.pendingAnchor = anchor;
    }
    document = doc;
    _folderLocked = Bookmarks.enabled && doc.directory != null && !FileService.canReadFolder(doc.directory!);
  }

  /// Asks the user to grant the document's folder (macOS sandbox), then
  /// re-renders so relative images load.
  Future<void> grantFolderAccess() async {
    final dir = document?.directory;
    if (dir == null) return;
    final picked = await FileService.pickFolder(initialDirectory: dir);
    if (picked == null) return;
    await Bookmarks.remember(picked);
    if (!await _recheckFolderAccess()) {
      toast('請選擇文件所在的資料夾（或它的上層資料夾）');
    }
  }

  /// After the user granted a folder: if the open document's folder became
  /// readable, re-render it so relative images load. Returns whether it is
  /// readable now.
  Future<bool> _recheckFolderAccess() async {
    final doc = document;
    if (!_folderLocked || doc?.directory == null) return true;
    if (!FileService.canReadFolder(doc!.directory!)) return false;
    PaintingBinding.instance.imageCache.clear();
    document = null; // Fresh viewer, so images are requested again.
    await openPath(doc.path!);
    return true;
  }

  // ------------------------------------------------------------------ links

  Future<void> openLink(String href) async {
    href = href.trim();
    if (href.isEmpty) return;
    final doc = document;

    if (href.startsWith('#')) {
      final heading = doc?.headingForSlug(Uri.decodeComponent(href.substring(1)));
      if (heading != null) viewer.jumpToHeading(heading);
      return;
    }

    final uri = Uri.tryParse(href);
    if (uri != null && uri.hasScheme && uri.scheme != 'file' && uri.scheme.length > 1) {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        toast('無法開啟連結：$href');
      }
      return;
    }

    // Relative or file:// link to another local file.
    final hash = href.indexOf('#');
    final target = hash >= 0 ? href.substring(0, hash) : href;
    final anchor = hash >= 0 ? Uri.decodeComponent(href.substring(hash + 1)) : null;
    final dir = doc?.directory;
    if (dir == null) return;
    String resolved;
    try {
      resolved = uri != null && uri.scheme == 'file'
          ? uri.toFilePath()
          : p.normalize(p.join(dir, Uri.decodeFull(target)));
    } on Object {
      resolved = p.normalize(p.join(dir, target));
    }
    if (!File(resolved).existsSync()) {
      toast('找不到連結的檔案：${p.basename(resolved)}');
      return;
    }
    if (isMarkdownPath(resolved)) {
      await openPath(resolved, anchor: anchor);
    } else if (!await launchUrl(Uri.file(resolved))) {
      toast('無法開啟：${p.basename(resolved)}');
    }
  }

  // ----------------------------------------------------------------- recent

  void _addRecent(String path) {
    recent
      ..remove(path)
      ..insert(0, path);
    if (recent.length > _recentLimit) recent = recent.sublist(0, _recentLimit);
    _saveRecent();
  }

  Future<void> removeRecent(String path) async {
    recent.remove(path);
    _saveRecent();
    // On mobile the entry is the app's own copy; drop it with the entry.
    if (await FileService.isInLibrary(path)) {
      if (document?.path == path) closeDocument();
      try {
        await File(path).delete();
      } on FileSystemException {
        // Already gone.
      }
    }
    notifyListeners();
  }

  void _saveRecent() {
    _prefs.setStringList(_kRecent, recent);
    Bookmarks.retainOnly([...recent, ?folderPath]);
  }

  // ----------------------------------------------------------------- folder

  Future<void> pickFolder() async {
    final path = await FileService.pickFolder();
    if (path == null) return;
    await openFolder(path);
  }

  Future<void> openFolder(String path) async {
    if (path != folderPath) expandedDirs.clear();
    await Bookmarks.remember(path);
    folderPath = path;
    sidebarOpen = true;
    await _prefs.setString(_kFolder, path);
    await _scanFolder();
    await _recheckFolderAccess();
  }

  Future<void> refreshFolder() => _scanFolder();

  /// Expands the folders leading to [file] in the sidebar tree.
  void _revealInTree(String file) {
    final root = folderPath;
    if (root == null || !p.isWithin(root, file)) return;
    for (var dir = p.dirname(file); p.isWithin(root, dir); dir = p.dirname(dir)) {
      expandedDirs.add(dir);
    }
  }

  void toggleDir(String path) {
    if (!expandedDirs.remove(path)) expandedDirs.add(path);
    notifyListeners();
  }

  void closeFolder() {
    folderPath = null;
    folderTree = null;
    expandedDirs.clear();
    _prefs.remove(_kFolder);
    Bookmarks.retainOnly(recent);
    notifyListeners();
  }

  Future<void> _scanFolder() async {
    final path = folderPath;
    if (path == null) return;
    scanning = true;
    notifyListeners();
    try {
      final tree = await FileService.scanFolder(path);
      if (folderPath == path) folderTree = tree;
    } finally {
      scanning = false;
      notifyListeners();
    }
  }

  // --------------------------------------------------------------- settings

  void setThemeMode(ThemeMode mode) {
    themeMode = mode;
    _prefs.setInt(_kTheme, mode.index);
    notifyListeners();
  }

  void setTextScale(double value) {
    textScale = double.parse(value.clamp(minTextScale, maxTextScale).toStringAsFixed(2));
    _prefs.setDouble(_kTextScale, textScale);
    notifyListeners();
  }

  void zoom(int step) => setTextScale(step == 0 ? 1.0 : textScale + step * 0.1);

  void toggleSidebar() {
    sidebarOpen = !sidebarOpen;
    _prefs.setBool(_kSidebar, sidebarOpen);
    notifyListeners();
  }

  void toggleOutline() {
    outlineOpen = !outlineOpen;
    _prefs.setBool(_kOutline, outlineOpen);
    notifyListeners();
  }

  void setSidebarWidth(double width, {bool persist = false}) {
    sidebarWidth = width;
    if (persist) _prefs.setDouble(_kSidebarWidth, width);
    notifyListeners();
  }

  void toast(String message) {
    final messenger = messengerKey.currentState;
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 2)));
  }

  @override
  void dispose() {
    supporter.dispose();
    ads.dispose();
    _watchSub?.cancel();
    super.dispose();
  }
}
