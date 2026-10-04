import 'package:flutter/material.dart';

import '../monetization/ads.dart';
import '../monetization/supporter.dart';
import '../services/file_service.dart';
import '../state/app_state.dart';
import 'app_icons.dart';

/// The one place the app asks for money: a strip under the document.
///
/// Phones/tablets show an AdMob banner, desktop shows a small "成為支持者"
/// bar. Supporters see nothing.
class SupportSlot extends StatelessWidget {
  const SupportSlot({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([state.supporter, state.ads]),
      builder: (context, _) {
        final supporter = state.supporter;
        if (supporter.isSupporter) return const SizedBox.shrink();
        if (isMobilePlatform) {
          if (!state.ads.ready) return const SizedBox.shrink();
          return _Strip(child: const SafeArea(top: false, child: AdBanner()));
        }
        if (supporter.barDismissed) return const SizedBox.shrink();
        return _Strip(child: _SupportBar(supporter: supporter));
      },
    );
  }
}

class _Strip extends StatelessWidget {
  const _Strip({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border(top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.7))),
      ),
      child: child,
    );
  }
}

class _SupportBar extends StatelessWidget {
  const _SupportBar({required this.supporter});

  final SupporterController supporter;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final price = supporter.price;
    return SizedBox(
      height: 40,
      child: Padding(
        padding: const EdgeInsets.only(left: 14, right: 6),
        child: Row(
          children: [
            Icon(AppIcons.heart, size: 15, color: scheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '喜歡 MD Viewer 嗎？成為支持者即可移除這條提示。',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonal(
              onPressed: supporter.busy ? null : supporter.buy,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 28),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 13),
              ),
              child: Text(price == null ? '支持' : '支持 $price'),
            ),
            IconButton(
              tooltip: '暫時關閉',
              onPressed: supporter.dismissBar,
              iconSize: 15,
              visualDensity: VisualDensity.compact,
              color: scheme.onSurfaceVariant,
              icon: const Icon(AppIcons.close),
            ),
          ],
        ),
      ),
    );
  }
}
