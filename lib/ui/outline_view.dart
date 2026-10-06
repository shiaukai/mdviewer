import 'package:flutter/material.dart';

import '../models/md_document.dart';
import '../state/viewer_controller.dart';

/// Table of contents. Highlights the section being read and keeps it in view.
class OutlineView extends StatefulWidget {
  const OutlineView({
    super.key,
    required this.document,
    required this.controller,
    this.onSelected,
    this.scrollController,
    this.dense = true,
  });

  final MdDocument? document;
  final ViewerController controller;

  /// Called after a heading is tapped (closes sheets / drawers).
  final VoidCallback? onSelected;

  /// Supplied by a DraggableScrollableSheet on phones.
  final ScrollController? scrollController;

  final bool dense;

  @override
  State<OutlineView> createState() => _OutlineViewState();
}

class _OutlineViewState extends State<OutlineView> {
  ScrollController? _ownScroll;

  ScrollController get _scroll =>
      widget.scrollController ?? (_ownScroll ??= ScrollController());

  double get _itemExtent => widget.dense ? 34 : 46;

  @override
  void initState() {
    super.initState();
    widget.controller.currentHeading.addListener(_reveal);
    WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(animate: false));
  }

  @override
  void didUpdateWidget(OutlineView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.currentHeading.removeListener(_reveal);
      widget.controller.currentHeading.addListener(_reveal);
    }
  }

  @override
  void dispose() {
    widget.controller.currentHeading.removeListener(_reveal);
    _ownScroll?.dispose();
    super.dispose();
  }

  /// Scrolls the outline so the current heading is visible.
  void _reveal({bool animate = true}) {
    if (!mounted || !_scroll.hasClients) return;
    final index = widget.controller.currentHeading.value;
    if (index < 0) return;
    final pos = _scroll.position;
    final top = index * _itemExtent + 8;
    final bottom = top + _itemExtent;
    double? target;
    if (top < pos.pixels) {
      target = top - _itemExtent;
    } else if (bottom > pos.pixels + pos.viewportDimension) {
      target = bottom - pos.viewportDimension + _itemExtent;
    }
    if (target == null) return;
    target = target.clamp(pos.minScrollExtent, pos.maxScrollExtent);
    if (animate) {
      _scroll.animateTo(target, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    } else {
      _scroll.jumpTo(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    final headings = widget.document?.headings ?? const <MdHeading>[];
    final scheme = Theme.of(context).colorScheme;
    if (headings.isEmpty) {
      return ListView(
        controller: _scroll,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              widget.document == null ? '尚未開啟文件' : '這份文件沒有標題',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.outline),
            ),
          ),
        ],
      );
    }
    final minLevel = headings.map((h) => h.level).reduce((a, b) => a < b ? a : b);

    return ValueListenableBuilder<int>(
      valueListenable: widget.controller.currentHeading,
      builder: (context, current, _) => ListView.builder(
        controller: _scroll,
        padding: EdgeInsets.only(top: 8, bottom: 8 + MediaQuery.paddingOf(context).bottom),
        itemExtent: _itemExtent,
        itemCount: headings.length,
        itemBuilder: (context, i) {
          final h = headings[i];
          final selected = i == current;
          final depth = h.level - minLevel;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
            child: Material(
              color: selected ? scheme.secondaryContainer : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () {
                  widget.controller.currentHeading.value = i;
                  widget.controller.jumpToHeading(h);
                  widget.onSelected?.call();
                },
                child: Padding(
                  padding: EdgeInsets.only(left: 12 + depth * 14.0, right: 10),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      h.text.isEmpty ? '(無標題)' : h.text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: widget.dense ? 13.5 : 15.5,
                        fontWeight: depth == 0 || selected ? FontWeight.w600 : FontWeight.w400,
                        color: selected
                            ? scheme.onSecondaryContainer
                            : depth == 0
                                ? scheme.onSurface
                                : scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
