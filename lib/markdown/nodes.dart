import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:markdown_widget/markdown_widget.dart';

import '../models/md_document.dart';
import 'md_image.dart';
import '../ui/app_icons.dart';

/// `<img>` / `![]()` — resolved against the document, zoomable unless it is
/// the content of a link (badges usually are).
class ImageSpanNode extends SpanNode {
  ImageSpanNode(this.attributes, this.document);

  final Map<String, String> attributes;
  final MdDocument document;

  @override
  InlineSpan build() {
    var insideLink = false;
    for (SpanNode? n = parent; n != null; n = n.parent) {
      if (n is LinkNode) {
        insideLink = true;
        break;
      }
    }
    double? size(String key) =>
        double.tryParse((attributes[key] ?? '').replaceAll('px', '').trim());
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: MdImage(
        src: attributes['src'] ?? '',
        alt: attributes['alt'] ?? attributes['title'] ?? '',
        width: size('width'),
        height: size('height'),
        document: document,
        zoomable: !insideLink,
      ),
    );
  }
}

/// Link without the stock node's trailing space, which shows up as a gap
/// before punctuation ("見 README 。").
class MdLinkNode extends LinkNode {
  MdLinkNode(super.attributes, super.linkConfig);

  @override
  InlineSpan build() {
    final href = attributes['href'] ?? '';
    void onTap() => linkConfig.onTap?.call(href);
    return TextSpan(children: [for (final child in children) _tappable(child.build(), onTap)]);
  }

  static InlineSpan _tappable(InlineSpan span, VoidCallback onTap) {
    if (span is WidgetSpan) {
      return WidgetSpan(
        alignment: span.alignment,
        baseline: span.baseline,
        style: span.style,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(onTap: onTap, child: span.child),
        ),
      );
    }
    if (span is! TextSpan) return span;
    return TextSpan(
      text: span.text,
      style: span.style,
      children: span.children?.map((c) => _tappable(c, onTap)).toList(),
      recognizer: TapGestureRecognizer()..onTap = onTap,
      mouseCursor: SystemMouseCursors.click,
      semanticsLabel: span.semanticsLabel,
    );
  }
}

/// Blockquote that lays out each child block on its own line (the stock
/// node runs consecutive paragraphs together).
class QuoteNode extends ElementNode {
  QuoteNode(this.sideColor, this.textColor);

  final Color sideColor;
  final Color textColor;

  @override
  InlineSpan build() => WidgetSpan(
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.fromLTRB(16, 2, 0, 2),
          decoration: BoxDecoration(border: Border(left: BorderSide(color: sideColor, width: 4))),
          child: _column(children),
        ),
      );

  @override
  TextStyle? get style => TextStyle(color: textColor).merge(parentStyle);
}

enum AlertKind { note, tip, important, warning, caution }

/// GitHub alert: `> [!NOTE]`, `> [!WARNING]`, …
class AlertNode extends ElementNode {
  AlertNode(this.kind, this.dark);

  final AlertKind kind;
  final bool dark;

  static AlertKind? kindOf(String? cssClass) {
    final m = RegExp(r'markdown-alert-(\w+)').firstMatch(cssClass ?? '');
    if (m == null) return null;
    for (final k in AlertKind.values) {
      if (k.name == m.group(1)) return k;
    }
    return null;
  }

  (Color, IconData, String) get _look => switch (kind) {
        AlertKind.note => (dark ? const Color(0xff4493f8) : const Color(0xff0969da), AppIcons.alertNote, 'Note'),
        AlertKind.tip => (dark ? const Color(0xff3fb950) : const Color(0xff1a7f37), AppIcons.alertTip, 'Tip'),
        AlertKind.important => (dark ? const Color(0xffab7df8) : const Color(0xff8250df), AppIcons.alertImportant, 'Important'),
        AlertKind.warning => (dark ? const Color(0xffd29922) : const Color(0xff9a6700), AppIcons.alertWarning, 'Warning'),
        AlertKind.caution => (dark ? const Color(0xfff85149) : const Color(0xffd1242f), AppIcons.alertCaution, 'Caution'),
      };

  @override
  InlineSpan build() {
    final (color, icon, label) = _look;
    // First child is the generated "Note"/"Tip" title paragraph.
    final body = children.length > 1 ? children.sublist(1) : const <SpanNode>[];
    return WidgetSpan(
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.fromLTRB(14, 8, 12, 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: dark ? 0.10 : 0.06),
          border: Border(left: BorderSide(color: color, width: 4)),
          borderRadius: const BorderRadius.horizontal(right: Radius.circular(6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 17, color: color),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 15)),
            ]),
            if (body.isNotEmpty) ...[const SizedBox(height: 4), _column(body)],
          ],
        ),
      ),
    );
  }

  @override
  TextStyle? get style => parentStyle;
}

/// Block-level HTML element (`<p>`, `<div align="center">`, `<h1>` …):
/// takes the full line and honours `align`.
class HtmlBlockNode extends ElementNode {
  HtmlBlockNode({this.align = TextAlign.start, this.blockStyle, this.prefix});

  final TextAlign align;
  final TextStyle? blockStyle;
  final String? prefix;

  @override
  InlineSpan build() => WidgetSpan(
        child: SizedBox(
          width: double.infinity,
          child: Text.rich(
            TextSpan(children: [
              if (prefix != null) TextSpan(text: prefix, style: style),
              childrenSpan,
            ]),
            textAlign: align,
          ),
        ),
      );

  @override
  TextStyle? get style => parentStyle?.merge(blockStyle) ?? blockStyle;
}

/// Transparent inline container that only (optionally) adjusts style.
class InlineStyleNode extends ElementNode {
  InlineStyleNode([this.extra]);

  final TextStyle? extra;

  @override
  TextStyle? get style => parentStyle?.merge(extra) ?? extra;
}

Widget _column(List<SpanNode> nodes) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < nodes.length; i++)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
            child: Text.rich(nodes[i].build()),
          ),
      ],
    );
