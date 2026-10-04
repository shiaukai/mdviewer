import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../layout/breakpoints.dart';
import '../services/file_service.dart';
import '../state/app_state.dart';
import 'app_icons.dart';
import 'common.dart';
import 'file_sidebar.dart';
import 'outline_view.dart';
import 'settings_panel.dart';
import 'support_slot.dart';
import 'toolbar_button.dart';

/// Desktop / tablet / phone-landscape layout: toolbar, resizable file
/// sidebar, document, and an outline that is docked when there is room
/// ([LayoutMode.wide]) or slides in from the right otherwise.
class DesktopShell extends StatelessWidget {
  const DesktopShell({super.key, required this.state, required this.mode});

  final AppState state;
  final LayoutMode mode;

  static const _outlineWidth = 260.0;

  @override
  Widget build(BuildContext context) {
    final doc = state.document;
    final width = MediaQuery.sizeOf(context).width;
    final dockOutline = mode == LayoutMode.wide && state.outlineOpen && doc != null;
    final maxSidebar = math.max(200.0, math.min(420.0, width * 0.4));
    final sidebarWidth = state.sidebarWidth.clamp(200.0, maxSidebar);

    return Scaffold(
      endDrawer: mode == LayoutMode.medium && doc != null
          ? Drawer(
              width: 300,
              child: SafeArea(
                child: Builder(
                  builder: (context) => _OutlinePanel(
                    state: state,
                    dense: false,
                    onSelected: () => Scaffold.of(context).closeEndDrawer(),
                  ),
                ),
              ),
            )
          : null,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Toolbar(state: state, mode: mode, outlineDocked: dockOutline),
            const Divider(height: 1),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (state.sidebarOpen) ...[
                    SizedBox(width: sidebarWidth, child: FileSidebar(state: state)),
                    _ResizeHandle(
                      onDrag: (dx) => state.setSidebarWidth((state.sidebarWidth + dx).clamp(200.0, maxSidebar)),
                      onEnd: () => state.setSidebarWidth(state.sidebarWidth, persist: true),
                    ),
                  ],
                  Expanded(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: documentArea(state, compact: false, showRecent: !state.sidebarOpen),
                        ),
                        if (doc != null)
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: ReadingProgress(controller: state.viewer),
                          ),
                      ],
                    ),
                  ),
                  if (dockOutline) ...[
                    const VerticalDivider(width: 1),
                    SizedBox(width: _outlineWidth, child: _OutlinePanel(state: state)),
                  ],
                ],
              ),
            ),
            SupportSlot(state: state),
          ],
        ),
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.state, required this.mode, required this.outlineDocked});

  final AppState state;
  final LayoutMode mode;
  final bool outlineDocked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final doc = state.document;
    final dark = theme.brightness == Brightness.dark;

    return SizedBox(
      height: 48,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            ToolbarButton(
              icon: AppIcons.sidebar,
              tooltip: '${state.sidebarOpen ? '隱藏' : '顯示'}側邊欄 (${shortcutLabel('B')})',
              selected: state.sidebarOpen,
              onPressed: state.toggleSidebar,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doc?.title ?? 'MD Viewer',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (doc?.path != null)
                    Text(
                      // On phones/tablets the path is the app's private copy.
                      isDesktopPlatform
                          ? '${p.dirname(doc!.path!)}  ·  ${doc.wordCount} 字'
                          : '${doc!.wordCount} 字',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, color: scheme.outline),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (doc?.path != null) ...[
              ToolbarButton(
                icon: AppIcons.reload,
                tooltip: '重新載入 (${shortcutLabel('R')})',
                onPressed: state.reload,
              ),
              const SizedBox(width: 2),
            ],
            ToolbarButton(
              icon: AppIcons.openFile,
              tooltip: '開啟檔案 (${shortcutLabel('O')})',
              onPressed: state.pickAndOpen,
            ),
            const ToolbarDivider(),
            ToolbarButton(
              icon: dark ? AppIcons.themeLight : AppIcons.themeDark,
              tooltip: dark ? '切換為淺色' : '切換為深色',
              onPressed: () => state.setThemeMode(dark ? ThemeMode.light : ThemeMode.dark),
            ),
            if (doc != null) ...[
              const SizedBox(width: 2),
              ToolbarButton(
                icon: AppIcons.outline,
                tooltip: '大綱',
                selected: outlineDocked,
                onPressed: () => mode == LayoutMode.wide
                    ? state.toggleOutline()
                    : Scaffold.of(context).openEndDrawer(),
              ),
            ],
            const SizedBox(width: 2),
            _MoreMenu(state: state),
          ],
        ),
      ),
    );
  }
}

/// Secondary actions, with shortcut hints like a native menu.
class _MoreMenu extends StatelessWidget {
  const _MoreMenu({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      alignmentOffset: const Offset(0, 6),
      menuChildren: [
        if (isDesktopPlatform)
          MenuItemButton(
            leadingIcon: const Icon(AppIcons.openFolder),
            shortcut: appShortcut(LogicalKeyboardKey.keyO, shift: true),
            onPressed: state.pickFolder,
            child: const Text('開啟資料夾…'),
          ),
        MenuItemButton(
          leadingIcon: const Icon(AppIcons.help),
          onPressed: state.openSample,
          child: const Text('使用說明'),
        ),
        if (state.document != null)
          MenuItemButton(
            leadingIcon: const Icon(AppIcons.close),
            onPressed: state.closeDocument,
            child: const Text('關閉文件'),
          ),
        const Divider(height: 9),
        MenuItemButton(
          leadingIcon: const Icon(AppIcons.settings),
          shortcut: appShortcut(LogicalKeyboardKey.comma),
          onPressed: () => showSettings(context, state, sheet: false),
          child: const Text('設定…'),
        ),
      ],
      builder: (context, controller, _) => ToolbarButton(
        icon: AppIcons.more,
        tooltip: '更多',
        selected: controller.isOpen,
        onPressed: () => controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}

class _OutlinePanel extends StatelessWidget {
  const _OutlinePanel({required this.state, this.onSelected, this.dense = true});

  final AppState state;
  final VoidCallback? onSelected;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 4),
            child: Text(
              '大綱',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant, letterSpacing: 0.3),
            ),
          ),
          Expanded(
            child: OutlineView(
              document: state.document,
              controller: state.viewer,
              onSelected: onSelected,
              dense: dense,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResizeHandle extends StatelessWidget {
  const _ResizeHandle({required this.onDrag, required this.onEnd});

  final ValueChanged<double> onDrag;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: (d) => onDrag(d.delta.dx),
        onHorizontalDragEnd: (_) => onEnd(),
        child: const SizedBox(
          width: 6,
          child: Center(child: VerticalDivider(width: 1)),
        ),
      ),
    );
  }
}
