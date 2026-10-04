import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path/path.dart' as p;

import '../services/file_service.dart';
import '../state/app_state.dart';
import 'app_icons.dart';
import 'brand_credit.dart';

/// Shown when no document is open.
class WelcomeView extends StatelessWidget {
  const WelcomeView({super.key, required this.state, this.showRecent = true});

  final AppState state;

  /// The desktop sidebar already lists recent files.
  final bool showRecent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final recent = showRecent ? state.recent.take(5).toList() : const <String>[];
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset('assets/images/logo.svg', width: 96, height: 96),
              const SizedBox(height: 20),
              Text('MD Viewer', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                isDesktopPlatform ? '開啟或拖曳 Markdown 檔案到這裡開始閱讀' : '開啟 Markdown 檔案開始閱讀',
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 28),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: state.pickAndOpen,
                    icon: const Icon(AppIcons.openFile, size: 18),
                    label: const Text('開啟檔案'),
                  ),
                  if (isDesktopPlatform)
                    OutlinedButton.icon(
                      onPressed: state.pickFolder,
                      icon: const Icon(AppIcons.openFolder, size: 18),
                      label: const Text('開啟資料夾'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: state.openSample,
                icon: const Icon(AppIcons.help, size: 18),
                label: const Text('看看使用說明'),
              ),
              if (recent.isNotEmpty) ...[
                const SizedBox(height: 28),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('最近開啟', style: theme.textTheme.titleSmall?.copyWith(color: scheme.onSurfaceVariant)),
                ),
                const SizedBox(height: 4),
                for (final path in recent)
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    leading: const Icon(AppIcons.file, size: 20),
                    title: Text(p.basename(path), maxLines: 1, overflow: TextOverflow.ellipsis),
                    onTap: () => state.openPath(path),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
              ],
              const SizedBox(height: 36),
              const BrandCredit(compact: true),
            ],
          ),
        ),
      ),
    );
  }
}
