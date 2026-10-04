import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path/path.dart' as p;

import '../models/md_document.dart';
import '../ui/app_icons.dart';

/// Image in a markdown document. Resolves remote URLs, data URIs, paths
/// relative to the document, and bundled assets; supports SVG.
class MdImage extends StatelessWidget {
  const MdImage({
    super.key,
    required this.src,
    required this.document,
    this.alt = '',
    this.width,
    this.height,
    this.zoomable = true,
  });

  final String src;
  final String alt;
  final double? width;
  final double? height;
  final MdDocument document;

  /// False when the image sits inside a link, so taps follow the link.
  final bool zoomable;

  @override
  Widget build(BuildContext context) {
    final image = _build(context, width: width, height: height);
    if (!zoomable) return image;
    return MouseRegion(
      cursor: SystemMouseCursors.zoomIn,
      child: GestureDetector(
        onTap: () => _openViewer(context),
        child: image,
      ),
    );
  }

  Widget _build(BuildContext context, {double? width, double? height, BoxFit fit = BoxFit.contain}) {
    Widget error(BuildContext context, Object e, StackTrace? s) => _ErrorImage(alt: alt, src: src);
    final source = src.trim();
    final lower = source.toLowerCase();

    if (lower.startsWith('data:')) {
      final comma = source.indexOf(',');
      if (comma < 0 || !lower.substring(0, comma).contains('base64')) {
        return _ErrorImage(alt: alt, src: src);
      }
      try {
        final bytes = base64Decode(source.substring(comma + 1).replaceAll(RegExp(r'\s'), ''));
        if (lower.startsWith('data:image/svg')) {
          return SvgPicture.memory(bytes, width: width, height: height, fit: fit);
        }
        return Image.memory(bytes, width: width, height: height, fit: fit, errorBuilder: error);
      } on FormatException {
        return _ErrorImage(alt: alt, src: src);
      }
    }

    final uri = Uri.tryParse(source);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      if (_looksLikeSvg(uri)) {
        return SvgPicture(
          _BadgeSafeSvgLoader(source),
          width: width,
          height: height,
          fit: fit,
          placeholderBuilder: (_) => SizedBox(width: width ?? 24, height: height ?? 20),
          errorBuilder: error,
        );
      }
      return Image.network(source, width: width, height: height, fit: fit, errorBuilder: error);
    }

    String decoded;
    try {
      decoded = Uri.decodeFull(source);
    } on ArgumentError {
      decoded = source;
    }
    final isSvg = p.extension(decoded).toLowerCase() == '.svg';

    if (document.path != null) {
      final file = File(uri != null && uri.scheme == 'file'
          ? uri.toFilePath()
          : p.isAbsolute(decoded)
              ? decoded
              : p.normalize(p.join(document.directory!, decoded)));
      if (isSvg) {
        return SvgPicture.file(file, width: width, height: height, fit: fit, errorBuilder: error);
      }
      return Image.file(file, width: width, height: height, fit: fit, errorBuilder: error);
    }

    if (document.assetBase != null) {
      final asset = p.posix.normalize(p.posix.join(document.assetBase!, decoded));
      if (isSvg) {
        return SvgPicture.asset(asset, width: width, height: height, fit: fit, errorBuilder: error);
      }
      return Image.asset(asset, width: width, height: height, fit: fit, errorBuilder: error);
    }
    return _ErrorImage(alt: alt, src: src);
  }

  static bool _looksLikeSvg(Uri uri) =>
      uri.path.toLowerCase().endsWith('.svg') ||
      uri.host.endsWith('shields.io') ||
      uri.host == 'badgen.net' ||
      uri.host.endsWith('badge.fury.io');

  void _openViewer(BuildContext context) {
    Navigator.of(context).push(PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: true,
      pageBuilder: (context, animation, _) => FadeTransition(
        opacity: animation,
        child: _ImageViewer(
          title: alt,
          child: _build(context, fit: BoxFit.contain),
        ),
      ),
    ));
  }
}

/// flutter_svg applies a group's `scale()` to shapes but not to `<text>`.
/// shields.io-style badges draw their labels at 10× inside
/// `<g transform="scale(.1)">`, which renders as giant clipped glyphs, so
/// bake that scale into the text before parsing.
class _BadgeSafeSvgLoader extends SvgNetworkLoader {
  const _BadgeSafeSvgLoader(super.url);

  static final _scaledGroup = RegExp(r'<g transform="scale\(\.1\)">');
  static final _textTag = RegExp(r'<text\b[^>]*>');
  static final _textAttr = RegExp(r'\b(x|y|textLength)="([\d.]+)"');

  @override
  String provideSvg(Uint8List? message) {
    final svg = super.provideSvg(message);
    if (!_scaledGroup.hasMatch(svg)) return svg;
    return svg
        .replaceAll(_scaledGroup, '<g>')
        .replaceAll('font-size="110"', 'font-size="11"')
        .replaceAllMapped(
          _textTag,
          (tag) => tag[0]!.replaceAllMapped(
            _textAttr,
            (a) => '${a[1]}="${double.parse(a[2]!) / 10}"',
          ),
        );
  }

  @override
  bool operator ==(Object other) => other is _BadgeSafeSvgLoader && other.url == url;

  @override
  int get hashCode => Object.hash(runtimeType, url);
}

class _ErrorImage extends StatelessWidget {
  const _ErrorImage({required this.alt, required this.src});

  final String alt;
  final String src;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: src,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(AppIcons.brokenImage, size: 16, color: scheme.error),
          if (alt.isNotEmpty) ...[
            const SizedBox(width: 4),
            Flexible(
              child: Text(alt, style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant)),
            ),
          ],
        ],
      ),
    );
  }
}

class _ImageViewer extends StatelessWidget {
  const _ImageViewer({required this.child, required this.title});

  final Widget child;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.88),
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: InteractiveViewer(
                maxScale: 8,
                child: Center(child: Padding(padding: const EdgeInsets.all(24), child: child)),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: '關閉',
                    color: Colors.white,
                    icon: const Icon(AppIcons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
