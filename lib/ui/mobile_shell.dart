import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../state/app_state.dart';
import 'common.dart';
import 'file_sidebar.dart';
import 'outline_view.dart';
import 'settings_panel.dart';
import 'support_slot.dart';
import 'app_icons.dart';

enum _MenuAction { open, reload, sample, settings, close }

/// Phone portrait: app bar + full-width document. Files live in the drawer,
/// the outline in a bottom sheet within thumb reach.
class MobileShell extends StatelessWidget {
  const MobileShell({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final doc = state.document;
    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            tooltip: '檔案',
            icon: const Icon(AppIcons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Text(doc?.title ?? 'MD Viewer', maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (doc != null)
            IconButton(
              tooltip: '大綱',
              icon: const Icon(AppIcons.outline),
              onPressed: () => _showOutline(context),
            ),
          PopupMenuButton<_MenuAction>(
            icon: const Icon(AppIcons.moreVertical),
            onSelected: (action) => _onMenu(context, action),
            itemBuilder: (context) => [
              const PopupMenuItem(value: _MenuAction.open, child: _MenuRow(AppIcons.openFile, '開啟檔案')),
              if (doc?.path != null)
                const PopupMenuItem(value: _MenuAction.reload, child: _MenuRow(AppIcons.reload, '重新載入')),
              const PopupMenuItem(value: _MenuAction.sample, child: _MenuRow(AppIcons.help, '使用說明')),
              const PopupMenuItem(value: _MenuAction.settings, child: _MenuRow(AppIcons.settings, '設定')),
              if (doc != null)
                const PopupMenuItem(value: _MenuAction.close, child: _MenuRow(AppIcons.close, '關閉文件')),
            ],
          ),
        ],
        bottom: doc == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: ReadingProgress(controller: state.viewer),
              ),
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Builder(
            builder: (context) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
                  child: Row(
                    children: [
                      SvgPicture.asset('assets/images/logo.svg', width: 32, height: 32),
                      const SizedBox(width: 12),
                      Text('MD Viewer',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                Expanded(
                  child: FileSidebar(
                    state: state,
                    onOpened: () => Scaffold.of(context).closeDrawer(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(top: false, bottom: false, child: documentArea(state, compact: true)),
      bottomNavigationBar: SupportSlot(state: state),
    );
  }

  void _onMenu(BuildContext context, _MenuAction action) {
    switch (action) {
      case _MenuAction.open:
        state.pickAndOpen();
      case _MenuAction.reload:
        state.reload();
      case _MenuAction.sample:
        state.openSample();
      case _MenuAction.settings:
        showSettings(context, state, sheet: true);
      case _MenuAction.close:
        state.closeDocument();
    }
  }

  void _showOutline(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.92,
        builder: (context, scrollController) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Text('大綱', style: Theme.of(context).textTheme.titleMedium),
            ),
            Expanded(
              child: OutlineView(
                document: state.document,
                controller: state.viewer,
                scrollController: scrollController,
                dense: false,
                onSelected: () => Navigator.pop(sheetContext),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        children: [Icon(icon, size: 18), const SizedBox(width: 12), Text(label)],
      );
}
