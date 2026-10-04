import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../brand.dart';

/// "Easier Life 簡單點生活 出品" with the brand mark. Links to the brand
/// website once [Brand.website] is set.
class BrandCredit extends StatelessWidget {
  const BrandCredit({super.key, this.compact = false});

  /// Smaller variant for the welcome screen footer.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final size = compact ? 16.0 : 18.0;
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.25),
          child: Image.asset(Brand.logoAsset, width: size, height: size, filterQuality: FilterQuality.medium),
        ),
        const SizedBox(width: 6),
        Text(
          compact ? 'by ${Brand.name} · ${Brand.nameZh}' : '${Brand.name} ${Brand.nameZh} 出品',
          style: TextStyle(fontSize: compact ? 12 : 12.5, color: scheme.onSurfaceVariant),
        ),
      ],
    );
    if (Brand.website.isEmpty) return content;
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () => launchUrl(Uri.parse(Brand.website), mode: LaunchMode.externalApplication),
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), child: content),
    );
  }
}
