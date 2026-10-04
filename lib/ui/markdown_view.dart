import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

import '../markdown/md_theme.dart';
import '../models/md_document.dart';
import '../services/file_service.dart';
import '../state/viewer_controller.dart';

/// Renders a document as a lazily built list of top-level blocks, so long
/// files stay fast and the outline can jump straight to any heading.
class MarkdownView extends StatefulWidget {
  const MarkdownView({
    super.key,
    required this.document,
    required this.controller,
    required this.onLinkTap,
    this.textScale = 1.0,
    this.compact = false,
  });

  final MdDocument document;
  final ViewerController controller;
  final ValueChanged<String> onLinkTap;
  final double textScale;

  /// Phone layout: tighter margins.
  final bool compact;

  @override
  State<MarkdownView> createState() => _MarkdownViewState();
}

class _MarkdownViewState extends State<MarkdownView> {
  static const _maxContentWidth = 860.0;

  final _scroll = ScrollController();
  final _list = ListController();
  final _focus = FocusNode(debugLabel: 'markdown');

  final _viewportKey = GlobalKey();

  List<Widget> _blocks = const [];
  Object? _blocksKey;
  Object? _error;

  /// Keys on heading blocks, to read their on-screen position.
  Map<int, GlobalKey> _headingKeys = const {};

  @override
  void initState() {
    super.initState();
    widget.controller.attach(_jumpTo);
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (isDesktopPlatform) _focus.requestFocus();
      _restorePosition();
    });
  }

  @override
  void didUpdateWidget(MarkdownView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.detach(_jumpTo);
      widget.controller.attach(_jumpTo);
    }
    if (widget.controller.pendingAnchor != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _restorePosition();
      });
    }
  }

  @override
  void dispose() {
    widget.controller.detach(_jumpTo);
    _scroll.dispose();
    _list.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _restorePosition() {
    final c = widget.controller;
    final anchor = c.pendingAnchor;
    c.pendingAnchor = null;
    final heading = anchor == null ? null : widget.document.headingForSlug(anchor);
    if (heading != null) {
      _jumpTo(heading.blockIndex, animate: false);
    } else if (c.restoreBlock > 0) {
      _jumpTo(c.restoreBlock, animate: false);
    }
    _onScroll();
  }

  void _jumpTo(int index, {bool animate = true}) {
    if (!_list.isAttached || !_scroll.hasClients || _blocks.isEmpty) return;
    index = index.clamp(0, _blocks.length - 1);
    if (animate) {
      _list.animateToItem(
        index: index,
        scrollController: _scroll,
        alignment: 0,
        duration: (_) => const Duration(milliseconds: 280),
        curve: (_) => Curves.easeOutCubic,
      );
    } else {
      _list.jumpToItem(index: index, scrollController: _scroll, alignment: 0);
    }
  }

  void _onScroll() {
    if (!_list.isAttached || !_scroll.hasClients) return;
    final pos = _scroll.position;
    widget.controller.progress.value =
        pos.maxScrollExtent <= 0 ? 1 : (pos.pixels / pos.maxScrollExtent).clamp(0.0, 1.0);
    // Scroll notifications arrive before the list is laid out at the new
    // offset; read item positions once the frame is done.
    if (_positionUpdatePending) return;
    _positionUpdatePending = true;
    WidgetsBinding.instance
      ..addPostFrameCallback((_) {
        _positionUpdatePending = false;
        if (mounted) _updatePosition();
      })
      ..ensureVisualUpdate();
  }

  bool _positionUpdatePending = false;

  void _updatePosition() {
    if (!_list.isAttached || !_scroll.hasClients) return;
    final c = widget.controller;
    final range = _list.visibleRange;
    if (range != null) c.restoreBlock = range.$1;
    c.currentHeading.value = _currentHeading(_scroll.position, range);
  }

  /// The section being read: the last heading at or above the top edge.
  /// At the very bottom, the last heading that is on screen.
  int _currentHeading(ScrollPosition pos, (int, int)? range) {
    final headings = widget.document.headings;
    var result = -1;
    if (range == null) return result;
    if (pos.maxScrollExtent > 0 && pos.pixels >= pos.maxScrollExtent - 4) {
      for (var i = 0; i < headings.length && headings[i].blockIndex <= range.$2; i++) {
        result = i;
      }
      return result;
    }
    final viewport = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (viewport == null || !viewport.attached) return result;
    final top = viewport.localToGlobal(Offset.zero).dy;
    for (var i = 0; i < headings.length; i++) {
      final block = headings[i].blockIndex;
      if (block < range.$1) {
        result = i;
        continue;
      }
      if (block > range.$2) break;
      final box = _headingKeys[block]?.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) break;
      if (box.localToGlobal(Offset.zero).dy - top > 32) break;
      result = i;
    }
    return result;
  }

  void _ensureBlocks(ThemeData theme) {
    final key = (widget.document, theme.colorScheme, theme.brightness);
    if (key == _blocksKey) return;
    _blocksKey = key;
    try {
      final config = buildMarkdownConfig(
        theme: theme,
        // Read widget at tap time so a rebuilt parent's callback is used.
        onLinkTap: (href) => widget.onLinkTap(href),
      );
      _blocks = buildMarkdownGenerator(theme: theme, document: widget.document)
          .buildWidgets(widget.document.source, config: config);
      _headingKeys = {
        for (final h in widget.document.headings) h.blockIndex: GlobalKey(),
      };
      _error = null;
    } catch (e) {
      _blocks = const [];
      _error = e;
    }
  }

  @override
  Widget build(BuildContext context) {
    _ensureBlocks(Theme.of(context));
    if (_error != null) return _RawFallback(document: widget.document, error: _error!);
    if (_blocks.isEmpty) {
      return Center(
        child: Text('這份文件是空的', style: TextStyle(color: Theme.of(context).colorScheme.outline)),
      );
    }

    final mq = MediaQuery.of(context);
    final scaler = TextScaler.linear(mq.textScaler.scale(16) / 16 * widget.textScale);

    return MediaQuery(
      data: mq.copyWith(textScaler: scaler),
      child: LayoutBuilder(builder: (context, constraints) {
        final minSide = widget.compact ? 18.0 : 40.0;
        final side = math.max(minSide, (constraints.maxWidth - _maxContentWidth * widget.textScale) / 2);
        Widget list = SuperListView.builder(
          key: _viewportKey,
          controller: _scroll,
          listController: _list,
          padding: EdgeInsets.fromLTRB(
            side,
            widget.compact ? 12 : 28,
            side,
            64 + mq.padding.bottom,
          ),
          itemCount: _blocks.length,
          itemBuilder: (context, index) {
            final key = _headingKeys[index];
            return key == null ? _blocks[index] : KeyedSubtree(key: key, child: _blocks[index]);
          },
        );
        // Desktop platforms get a scrollbar from the default scroll behavior.
        if (!isDesktopPlatform) {
          list = Scrollbar(controller: _scroll, interactive: true, child: list);
        }
        // PrimaryScrollController + Focus: arrow / page keys scroll the doc.
        return PrimaryScrollController(
          controller: _scroll,
          child: Focus(
            focusNode: _focus,
            child: SelectionArea(child: list),
          ),
        );
      }),
    );
  }
}

class _RawFallback extends StatelessWidget {
  const _RawFallback({required this.document, required this.error});

  final MdDocument document;
  final Object error;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Card(
          color: scheme.errorContainer,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text('無法排版這份文件，以下顯示原始內容。\n$error',
                style: TextStyle(color: scheme.onErrorContainer)),
          ),
        ),
        const SizedBox(height: 16),
        SelectableText(document.content),
      ],
    );
  }
}
