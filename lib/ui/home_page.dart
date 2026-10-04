import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../layout/breakpoints.dart';
import '../models/md_document.dart';
import '../services/file_service.dart';
import '../state/app_state.dart';
import 'desktop_shell.dart';
import 'mobile_shell.dart';
import 'common.dart';
import 'settings_panel.dart';
import 'app_icons.dart';

/// Picks the shell from the window size. Rotating a phone, resizing a
/// window, or entering split view on a tablet switches layouts live.
class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.state});

  final AppState state;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _dragging = false;

  AppState get state => widget.state;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final mode = Breakpoints.of(MediaQuery.sizeOf(context));
        Widget shell = mode.isDesktop
            ? DesktopShell(state: state, mode: mode)
            : MobileShell(state: state);

        if (isDesktopPlatform) {
          shell = DropTarget(
            onDragEntered: (_) => setState(() => _dragging = true),
            onDragExited: (_) => setState(() => _dragging = false),
            onDragDone: (details) {
              setState(() => _dragging = false);
              _onDrop(details.files.map((f) => f.path).toList());
            },
            child: Stack(
              children: [
                shell,
                if (_dragging) const Positioned.fill(child: _DropOverlay()),
              ],
            ),
          );
        }

        return CallbackShortcuts(
          bindings: _shortcuts(mode),
          child: Focus(autofocus: true, child: shell),
        );
      },
    );
  }

  Map<ShortcutActivator, VoidCallback> _shortcuts(LayoutMode mode) {
    const key = appShortcut;
    return {
      key(LogicalKeyboardKey.keyO): state.pickAndOpen,
      if (isDesktopPlatform) key(LogicalKeyboardKey.keyO, shift: true): state.pickFolder,
      key(LogicalKeyboardKey.keyR): state.reload,
      key(LogicalKeyboardKey.keyB): state.toggleSidebar,
      key(LogicalKeyboardKey.equal): () => state.zoom(1),
      key(LogicalKeyboardKey.equal, shift: true): () => state.zoom(1),
      key(LogicalKeyboardKey.numpadAdd): () => state.zoom(1),
      key(LogicalKeyboardKey.minus): () => state.zoom(-1),
      key(LogicalKeyboardKey.numpadSubtract): () => state.zoom(-1),
      key(LogicalKeyboardKey.digit0): () => state.zoom(0),
      key(LogicalKeyboardKey.comma): () => showSettings(context, state, sheet: !mode.isDesktop),
    };
  }

  Future<void> _onDrop(List<String> paths) async {
    for (final path in paths) {
      if (Directory(path).existsSync()) {
        await state.openFolder(path);
        return;
      }
      if (isMarkdownPath(path) || p.extension(path).toLowerCase() == '.txt') {
        await state.openPath(path);
        return;
      }
    }
    state.toast('請拖曳 Markdown 檔案（.md）或資料夾');
  }
}

class _DropOverlay extends StatelessWidget {
  const _DropOverlay();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IgnorePointer(
      child: Container(
        color: scheme.primary.withValues(alpha: 0.08),
        padding: const EdgeInsets.all(16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: scheme.primary, width: 2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(AppIcons.drop, size: 44, color: scheme.primary),
                const SizedBox(height: 8),
                Text('放開以開啟', style: TextStyle(fontSize: 18, color: scheme.primary, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
