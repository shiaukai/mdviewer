import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Every icon in the app comes from one line-icon set (Lucide: 24-unit grid,
/// uniform stroke), so toolbar, menus and lists share the same weight and
/// optical size. Swap the set here, not at call sites.
abstract final class AppIcons {
  // Toolbar / app bar
  static const IconData sidebar = LucideIcons.panelLeft;
  static const IconData outline = LucideIcons.tableOfContents;
  static const IconData reload = LucideIcons.rotateCw;
  static const IconData openFile = LucideIcons.fileInput;
  static const IconData openFolder = LucideIcons.folderOpen;
  static const IconData more = LucideIcons.ellipsis;
  static const IconData moreVertical = LucideIcons.ellipsisVertical;
  static const IconData menu = LucideIcons.menu;
  static const IconData settings = LucideIcons.settings2;
  static const IconData help = LucideIcons.bookOpen;
  static const IconData close = LucideIcons.x;
  static const IconData heart = LucideIcons.heart;
  static const IconData info = LucideIcons.info;
  static const IconData shield = LucideIcons.shieldCheck;

  // Theme
  static const IconData themeSystem = LucideIcons.sunMoon;
  static const IconData themeLight = LucideIcons.sun;
  static const IconData themeDark = LucideIcons.moon;
  static const IconData textSmaller = LucideIcons.aArrowDown;
  static const IconData textLarger = LucideIcons.aArrowUp;

  // Files
  static const IconData file = LucideIcons.fileText;
  static const IconData folder = LucideIcons.folder;
  static const IconData expand = LucideIcons.chevronRight;
  static const IconData collapse = LucideIcons.chevronDown;
  static const IconData history = LucideIcons.history;
  static const IconData library = LucideIcons.library;
  static const IconData delete = LucideIcons.trash2;
  static const IconData drop = LucideIcons.fileDown;

  // Content
  static const IconData copy = LucideIcons.copy;
  static const IconData taskDone = LucideIcons.squareCheckBig;
  static const IconData taskTodo = LucideIcons.square;
  static const IconData copied = LucideIcons.check;
  static const IconData brokenImage = LucideIcons.imageOff;
  static const IconData alertNote = LucideIcons.info;
  static const IconData alertTip = LucideIcons.lightbulb;
  static const IconData alertImportant = LucideIcons.messageSquareWarning;
  static const IconData alertWarning = LucideIcons.triangleAlert;
  static const IconData alertCaution = LucideIcons.octagonAlert;
}
