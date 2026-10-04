import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/app_state.dart';
import '../state/viewer_controller.dart';
import 'app_icons.dart';
import 'markdown_view.dart';
import 'welcome_view.dart';

/// ⌘ on macOS, Ctrl elsewhere.
SingleActivator appShortcut(LogicalKeyboardKey key, {bool shift = false}) =>
    SingleActivator(key, meta: Platform.isMacOS, control: !Platform.isMacOS, shift: shift);

/// "⌘O" on macOS, "Ctrl+O" elsewhere.
String shortcutLabel(String key, {bool shift = false}) => Platform.isMacOS
    ? '${shift ? '⇧' : ''}⌘$key'
    : 'Ctrl+${shift ? 'Shift+' : ''}$key';

/// The open document, or the welcome screen.
///
/// The viewer is keyed by file path: reloading the same file keeps its
/// state, opening another file starts fresh. When the layout switches, the
/// viewer is rebuilt elsewhere and restores its position from the controller.
Widget documentArea(AppState state, {required bool compact, bool showRecent = true}) {
  final doc = state.document;
  if (doc == null) {
    if (state.loading) return const Center(child: CircularProgressIndicator());
    return WelcomeView(state: state, showRecent: showRecent);
  }
  final viewer = MarkdownView(
    key: ValueKey(doc.path ?? 'asset:${doc.title}'),
    document: doc,
    controller: state.viewer,
    onLinkTap: state.openLink,
    textScale: state.textScale,
    compact: compact,
  );
  if (!state.needsFolderAccess) return viewer;
  return Column(
    children: [
      _FolderAccessBanner(onGrant: state.grantFolderAccess),
      Expanded(child: viewer),
    ],
  );
}

/// macOS sandbox: opening one file doesn't grant the files next to it.
class _FolderAccessBanner extends StatelessWidget {
  const _FolderAccessBanner({required this.onGrant});

  final VoidCallback onGrant;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.secondaryContainer.withValues(alpha: 0.6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 10, 8),
        child: Row(
          children: [
            Icon(AppIcons.info, size: 16, color: scheme.onSecondaryContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '這份文件引用了同資料夾的圖片或檔案，需要你授權這個資料夾才能顯示。',
                style: TextStyle(fontSize: 13, color: scheme.onSecondaryContainer),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonal(onPressed: onGrant, child: const Text('授權資料夾')),
          ],
        ),
      ),
    );
  }
}

class ReadingProgress extends StatelessWidget {
  const ReadingProgress({super.key, required this.controller});

  final ViewerController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: controller.progress,
      builder: (context, value, _) => LinearProgressIndicator(
        value: value,
        minHeight: 2,
        backgroundColor: Colors.transparent,
      ),
    );
  }
}
