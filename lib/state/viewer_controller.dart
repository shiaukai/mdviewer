import 'package:flutter/foundation.dart';

import '../models/md_document.dart';

/// Bridges the markdown viewer and the widgets around it (outline, progress
/// bar, link handling).
///
/// It outlives the viewer widget itself: when the layout switches between
/// phone and desktop (e.g. rotating a phone), the viewer is rebuilt in a new
/// place in the tree and restores the reading position from [restoreBlock].
class ViewerController {
  /// Index into [MdDocument.headings] of the section being read; -1 = none.
  final currentHeading = ValueNotifier<int>(-1);

  /// Scroll progress, 0..1.
  final progress = ValueNotifier<double>(0);

  /// First visible top-level block.
  int restoreBlock = 0;

  /// Anchor to jump to once the next document is laid out.
  String? pendingAnchor;

  void Function(int blockIndex, {bool animate})? _jump;

  void attach(void Function(int blockIndex, {bool animate}) jump) => _jump = jump;

  void detach(Function jump) {
    // Tear-offs of the same method compare equal but aren't identical.
    if (_jump == jump) _jump = null;
  }

  void reset({String? anchor}) {
    restoreBlock = 0;
    pendingAnchor = anchor;
    currentHeading.value = -1;
    progress.value = 0;
  }

  void jumpToBlock(int blockIndex, {bool animate = true}) =>
      _jump?.call(blockIndex, animate: animate);

  void jumpToHeading(MdHeading heading) => jumpToBlock(heading.blockIndex);
}
