import 'package:flutter/material.dart';
import 'package:markdown_widget/markdown_widget.dart';

import '../models/md_document.dart';
import 'code_block.dart';
import 'html_support.dart';
import 'nodes.dart';
import '../ui/app_icons.dart';

class _Heading extends HeadingConfig {
  const _Heading(this.tag, this.style, {this.divider});

  @override
  final String tag;
  @override
  final TextStyle style;
  @override
  final HeadingDivider? divider;

  @override
  EdgeInsets get padding => const EdgeInsets.only(top: 12, bottom: 2);
}

/// Markdown styling derived from the app's Material theme, so documents
/// follow light/dark mode and the color scheme.
MarkdownConfig buildMarkdownConfig({
  required ThemeData theme,
  required ValueChanged<String> onLinkTap,
}) {
  final scheme = theme.colorScheme;
  final dark = theme.brightness == Brightness.dark;
  final text = scheme.onSurface;
  final divider = HeadingDivider(color: scheme.outlineVariant, space: 6);

  TextStyle heading(double size, {FontWeight weight = FontWeight.w700, Color? color}) =>
      TextStyle(fontSize: size, height: 1.3, fontWeight: weight, color: color ?? text);

  return MarkdownConfig(configs: [
    PConfig(textStyle: TextStyle(fontSize: 16, height: 1.65, color: text)),
    _Heading('h1', heading(30), divider: divider),
    _Heading('h2', heading(24), divider: divider),
    _Heading('h3', heading(20)),
    _Heading('h4', heading(17.5)),
    _Heading('h5', heading(16)),
    _Heading('h6', heading(15, color: scheme.onSurfaceVariant)),
    LinkConfig(
      style: TextStyle(
        color: scheme.primary,
        decoration: TextDecoration.underline,
        decorationColor: scheme.primary.withValues(alpha: 0.35),
      ),
      onTap: onLinkTap,
    ),
    CodeConfig(
      style: TextStyle(
        fontFamily: monoFontFamily,
        fontFamilyFallback: monoFontFallback,
        fontSize: 14,
        color: dark ? const Color(0xffe6edf3) : const Color(0xff1f2328),
        backgroundColor: dark ? const Color(0x33a5b4c8) : const Color(0x1a818b98),
      ),
    ),
    PreConfig(builder: (code, language) => CodeBlock(code: code, language: language, dark: dark)),
    HrConfig(height: 1, color: scheme.outlineVariant),
    TableConfig(
      border: TableBorder.all(color: scheme.outlineVariant, width: 1),
      headerRowDecoration: BoxDecoration(color: scheme.surfaceContainerHighest),
      headPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      bodyPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      wrapper: (table) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: table,
      ),
    ),
    ListConfig(marginLeft: 28, marginBottom: 2),
    CheckBoxConfig(
      builder: (checked) => Padding(
        padding: const EdgeInsets.only(top: 3, right: 2),
        child: Icon(
          checked ? AppIcons.taskDone : AppIcons.taskTodo,
          size: 17,
          color: checked ? scheme.primary : scheme.outline,
        ),
      ),
    ),
  ]);
}

MarkdownGenerator buildMarkdownGenerator({
  required ThemeData theme,
  required MdDocument document,
}) {
  final scheme = theme.colorScheme;
  final dark = theme.brightness == Brightness.dark;
  return MarkdownGenerator(
    blockSyntaxList: extraBlockSyntaxes,
    linesMargin: const EdgeInsets.symmetric(vertical: 6),
    textGenerator: htmlTextGenerator,
    generators: [
      SpanNodeGeneratorWithTag(
        tag: 'a',
        generator: (e, config, visitor) => MdLinkNode(e.attributes, config.a),
      ),
      SpanNodeGeneratorWithTag(
        tag: 'img',
        generator: (e, config, visitor) => ImageSpanNode(e.attributes, document),
      ),
      SpanNodeGeneratorWithTag(
        tag: 'blockquote',
        generator: (e, config, visitor) => QuoteNode(scheme.outlineVariant, scheme.onSurfaceVariant),
      ),
      SpanNodeGeneratorWithTag(
        tag: 'div',
        generator: (e, config, visitor) {
          final kind = AlertNode.kindOf(e.attributes['class']);
          return kind == null ? InlineStyleNode() : AlertNode(kind, dark);
        },
      ),
    ],
  );
}
