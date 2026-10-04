import 'package:flutter/widgets.dart';

/// Phone portrait → [mobile]. Everything else (tablets in any orientation,
/// phones rotated to landscape, desktop windows) → desktop layout, which
/// itself has a [medium] and a [wide] tier.
enum LayoutMode {
  /// Single column: app bar, file drawer, outline bottom sheet.
  mobile,

  /// Sidebar + document; outline opens as an overlay panel.
  medium,

  /// Sidebar + document + outline panel side by side.
  wide;

  bool get isDesktop => this != mobile;
}

class Breakpoints {
  /// Material's compact/medium boundary. Tablets are ≥ 600 even in portrait
  /// (iPad mini is 744), so they always get the desktop layout.
  static const double desktop = 600;

  /// Phones in landscape are short and wide (iPhone SE: 667×375). Treat any
  /// landscape window this wide as desktop even if it's under [desktop].
  static const double landscapeDesktop = 480;

  /// Wide enough to keep the outline docked next to the document.
  static const double wide = 1000;

  static LayoutMode of(Size size) {
    final landscape = size.width > size.height;
    if (size.width >= wide) return LayoutMode.wide;
    if (size.width >= desktop || (landscape && size.width >= landscapeDesktop)) {
      return LayoutMode.medium;
    }
    return LayoutMode.mobile;
  }
}
