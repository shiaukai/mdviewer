import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../services/file_service.dart';
import '../state/app_state.dart';
import 'app_icons.dart';

/// Folder tree (desktop) and recent files. Used docked on desktop and inside
/// the drawer on phones.
class FileSidebar extends StatelessWidget {
  const FileSidebar({super.key, required this.state, this.onOpened});

  final AppState state;

  /// Called after a file is opened (closes the drawer on phones).
  final VoidCallback? onOpened;

  Future<void> _open(String path) async {
    onOpened?.call();
    await state.openPath(path);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rows = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed: () {
                onOpened?.call();
                state.pickAndOpen();
              },
              icon: const Icon(AppIcons.openFile, size: 16),
              label: const Text('開啟檔案'),
            ),
            if (isDesktopPlatform)
              OutlinedButton.icon(
                onPressed: state.pickFolder,
                icon: const Icon(AppIcons.openFolder, size: 16),
                label: const Text('開啟資料夾'),
              ),
          ],
        ),
      ),
    ];

    final folder = state.folderPath;
    if (folder != null && isDesktopPlatform) {
      rows.add(_SectionHeader(
        icon: AppIcons.folder,
        title: p.basename(folder).isEmpty ? folder : p.basename(folder),
        tooltip: folder,
        actions: [
          IconButton(
            tooltip: '重新整理',
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            onPressed: state.scanning ? null : state.refreshFolder,
            icon: const Icon(AppIcons.reload),
          ),
          IconButton(
            tooltip: '關閉資料夾',
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            onPressed: state.closeFolder,
            icon: const Icon(AppIcons.close),
          ),
        ],
      ));
      final tree = state.folderTree;
      if (tree == null) {
        rows.add(const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))),
        ));
      } else if (tree.children.isEmpty) {
        rows.add(_hint(context, '這個資料夾裡沒有 Markdown 檔案'));
      } else {
        _addTree(rows, tree.children, 0, context);
      }
    }

    rows.add(_SectionHeader(
      icon: isMobilePlatform ? AppIcons.library : AppIcons.history,
      title: isMobilePlatform ? '我的檔案' : '最近開啟',
    ));
    if (state.recent.isEmpty) {
      rows.add(_hint(context, isMobilePlatform ? '開啟的檔案會保存在這裡' : '還沒有開啟過檔案'));
    }
    for (final path in state.recent) {
      final selected = state.document?.path == path;
      rows.add(_FileRow(
        icon: AppIcons.file,
        name: p.basename(path),
        subtitle: isMobilePlatform ? null : _shortDir(path),
        selected: selected,
        indent: 0,
        onTap: () => _open(path),
        onRemove: () => _confirmRemove(context, path),
        removeTooltip: isMobilePlatform ? '刪除' : '從清單移除',
      ));
    }

    return Material(
      color: scheme.surfaceContainerLow,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 16),
        children: rows,
      ),
    );
  }

  void _addTree(List<Widget> rows, List<FolderNode> nodes, int depth, BuildContext context) {
    for (final node in nodes) {
      if (node.isDirectory) {
        final open = state.expandedDirs.contains(node.path);
        rows.add(_FileRow(
          icon: open ? AppIcons.collapse : AppIcons.expand,
          name: node.name,
          indent: depth,
          onTap: () => state.toggleDir(node.path),
        ));
        if (open) _addTree(rows, node.children, depth + 1, context);
      } else {
        rows.add(_FileRow(
          icon: AppIcons.file,
          name: node.name,
          indent: depth,
          selected: state.document?.path == node.path,
          onTap: () => _open(node.path),
        ));
      }
    }
  }

  Future<void> _confirmRemove(BuildContext context, String path) async {
    if (isMobilePlatform) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('刪除檔案？'),
          content: Text('會刪除 App 內保存的「${p.basename(path)}」，原始檔案不受影響。'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('刪除')),
          ],
        ),
      );
      if (ok != true) return;
    }
    await state.removeRecent(path);
  }

  static String _shortDir(String path) {
    final dir = p.dirname(path);
    final parts = p.split(dir);
    return parts.length <= 3 ? dir : p.joinAll(['…', ...parts.sublist(parts.length - 2)]);
  }

  Widget _hint(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
        child: Text(text, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.outline)),
      );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title, this.tooltip, this.actions = const []});

  final IconData icon;
  final String title;
  final String? tooltip;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant, letterSpacing: 0.3),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 6, 2),
      child: SizedBox(
        height: 32,
        child: Row(
          children: [
            Icon(icon, size: 15, color: scheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(child: tooltip == null ? label : Tooltip(message: tooltip!, child: label)),
            ...actions,
          ],
        ),
      ),
    );
  }
}

class _FileRow extends StatefulWidget {
  const _FileRow({
    required this.icon,
    required this.name,
    required this.indent,
    required this.onTap,
    this.subtitle,
    this.selected = false,
    this.onRemove,
    this.removeTooltip,
  });

  final IconData icon;
  final String name;
  final String? subtitle;
  final int indent;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onRemove;
  final String? removeTooltip;

  @override
  State<_FileRow> createState() => _FileRowState();
}

class _FileRowState extends State<_FileRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = widget.selected ? scheme.onSecondaryContainer : scheme.onSurface;
    // Phones have no hover, so the remove button is always visible there.
    final showRemove = widget.onRemove != null && (_hover || isMobilePlatform);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: Material(
          color: widget.selected ? scheme.secondaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: isMobilePlatform ? 48 : 34),
              child: Padding(
                padding: EdgeInsets.only(left: 8 + widget.indent * 16.0, right: 4),
                child: Row(
                  children: [
                    Icon(widget.icon, size: 16, color: widget.selected ? fg : scheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(widget.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 14, color: fg, fontWeight: widget.selected ? FontWeight.w600 : null)),
                            if (widget.subtitle != null)
                              Text(widget.subtitle!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 11.5, color: scheme.outline)),
                          ],
                        ),
                      ),
                    ),
                    if (showRemove)
                      IconButton(
                        tooltip: widget.removeTooltip,
                        iconSize: 16,
                        visualDensity: VisualDensity.compact,
                        onPressed: widget.onRemove,
                        icon: Icon(isMobilePlatform ? AppIcons.delete : AppIcons.close),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
