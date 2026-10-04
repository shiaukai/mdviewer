import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../brand.dart';
import '../services/file_service.dart';
import '../state/app_state.dart';
import 'app_icons.dart';
import 'brand_credit.dart';

/// Theme and text size. A dialog on desktop layouts, a bottom sheet on phones.
Future<void> showSettings(BuildContext context, AppState state, {required bool sheet}) {
  final body = ListenableBuilder(
    listenable: Listenable.merge([state, state.supporter, state.ads]),
    builder: (context, _) => SingleChildScrollView(child: _SettingsBody(state: state)),
  );
  if (sheet) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: body,
      ),
    );
  }
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('設定'),
      content: SizedBox(width: 360, child: body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('完成')),
      ],
    ),
  );
}

class _SettingsBody extends StatelessWidget {
  const _SettingsBody({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('外觀', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.system, label: Text('系統'), icon: Icon(AppIcons.themeSystem, size: 16)),
              ButtonSegment(value: ThemeMode.light, label: Text('淺色'), icon: Icon(AppIcons.themeLight, size: 16)),
              ButtonSegment(value: ThemeMode.dark, label: Text('深色'), icon: Icon(AppIcons.themeDark, size: 16)),
            ],
            selected: {state.themeMode},
            onSelectionChanged: (s) => state.setThemeMode(s.first),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Text('文字大小', style: theme.textTheme.titleSmall),
            const Spacer(),
            Text('${(state.textScale * 100).round()}%'),
            TextButton(
              onPressed: state.textScale == 1.0 ? null : () => state.setTextScale(1.0),
              child: const Text('重設'),
            ),
          ],
        ),
        Row(
          children: [
            const Icon(AppIcons.textSmaller, size: 18),
            Expanded(
              child: Slider(
                value: state.textScale,
                min: AppState.minTextScale,
                max: AppState.maxTextScale,
                divisions: ((AppState.maxTextScale - AppState.minTextScale) * 10).round(),
                label: '${(state.textScale * 100).round()}%',
                onChanged: state.setTextScale,
              ),
            ),
            const Icon(AppIcons.textLarger, size: 18),
          ],
        ),
        const SizedBox(height: 12),
        _SupporterSection(state: state),
        const Divider(height: 32),
        const _AboutRow(),
      ],
    );
  }
}

class _SupporterSection extends StatelessWidget {
  const _SupporterSection({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final supporter = state.supporter;
    final muted = TextStyle(fontSize: 13, color: scheme.onSurfaceVariant, height: 1.5);
    final apple = Platform.isIOS || Platform.isMacOS;

    final children = <Widget>[Text('支持者', style: theme.textTheme.titleSmall), const SizedBox(height: 8)];
    if (supporter.isSupporter) {
      children.add(Row(children: [
        Icon(AppIcons.heart, size: 16, color: scheme.primary),
        const SizedBox(width: 8),
        const Expanded(child: Text('你是支持者，謝謝你的支持！')),
      ]));
    } else {
      final price = supporter.price == null ? '' : '（${supporter.price}）';
      children
        ..add(Text(
          [
            isMobilePlatform ? '一次買斷即可移除廣告' : '一次買斷即可移除底部提示',
            '，也支持 ${Brand.name} 繼續做簡單好用的小工具。',
            if (apple) '在 iPhone、iPad 與 Mac 上通用。',
          ].join(''),
          style: muted,
        ))
        ..add(const SizedBox(height: 10))
        ..add(Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton.icon(
              onPressed: supporter.busy ? null : supporter.buy,
              icon: const Icon(AppIcons.heart, size: 16),
              label: Text(isMobilePlatform ? '移除廣告$price' : '成為支持者$price'),
            ),
            TextButton(
              onPressed: supporter.busy ? null : supporter.restore,
              child: const Text('恢復購買'),
            ),
          ],
        ));
    }
    if (state.ads.privacyOptionsRequired && !supporter.isSupporter) {
      children.add(TextButton.icon(
        onPressed: state.ads.showPrivacyOptions,
        icon: const Icon(AppIcons.shield, size: 16),
        label: const Text('廣告隱私權設定'),
      ));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }
}

class _AboutRow extends StatelessWidget {
  const _AboutRow();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final version = snapshot.data == null ? '' : '${snapshot.data!.version} (${snapshot.data!.buildNumber})';
        return Row(
          children: [
            SvgPicture.asset('assets/images/logo.svg', width: 28, height: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('MD Viewer', style: TextStyle(fontWeight: FontWeight.w600)),
                  Text('版本 $version · Apache-2.0 開源',
                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 4),
                  const BrandCredit(),
                ],
              ),
            ),
            TextButton(
              onPressed: () => showLicensePage(
                context: context,
                applicationName: 'MD Viewer',
                applicationVersion: version,
                applicationIcon: Padding(
                  padding: const EdgeInsets.all(12),
                  child: SvgPicture.asset('assets/images/logo.svg', width: 56, height: 56),
                ),
                applicationLegalese: '${Brand.copyright}\n'
                    '程式碼以 Apache License 2.0 授權；名稱與圖示不在授權範圍內。',
              ),
              child: const Text('開源授權'),
            ),
          ],
        );
      },
    );
  }
}
