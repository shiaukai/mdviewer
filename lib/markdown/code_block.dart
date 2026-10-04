import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:markdown_widget/markdown_widget.dart' show highLightSpans;

import '../ui/app_icons.dart';

final String monoFontFamily = Platform.isIOS || Platform.isMacOS
    ? 'Menlo'
    : Platform.isWindows
        ? 'Consolas'
        : 'monospace';

const monoFontFallback = ['Menlo', 'Consolas', 'Roboto Mono', 'Courier New', 'monospace'];

/// Fenced code block: language label, copy button, syntax highlighting and
/// horizontal scrolling for long lines.
class CodeBlock extends StatefulWidget {
  const CodeBlock({
    super.key,
    required this.code,
    required this.language,
    required this.dark,
  });

  final String code;
  final String language;
  final bool dark;

  @override
  State<CodeBlock> createState() => _CodeBlockState();
}

class _CodeBlockState extends State<CodeBlock> {
  final _scroll = ScrollController();
  bool _copied = false;
  Timer? _reset;

  @override
  void dispose() {
    _reset?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.code.trimRight()));
    if (!mounted) return;
    setState(() => _copied = true);
    _reset?.cancel();
    _reset = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = widget.dark ? atomOneDarkTheme : githubTheme;
    final background = theme['root']?.backgroundColor ??
        (widget.dark ? const Color(0xff282c34) : const Color(0xfff6f8fa));
    final baseStyle = TextStyle(
      fontFamily: monoFontFamily,
      fontFamilyFallback: monoFontFallback,
      fontSize: 13.5,
      height: 1.5,
      color: theme['root']?.color,
    );
    final code = widget.code.trimRight();
    final lang = widget.language.trim().toLowerCase();

    List<InlineSpan> spans;
    try {
      spans = highLightSpans(
        code,
        language: lang.isEmpty ? 'plaintext' : lang,
        theme: theme,
        textStyle: baseStyle,
      );
    } catch (_) {
      spans = [TextSpan(text: code, style: baseStyle)];
    }

    final muted = (theme['root']?.color ?? scheme.onSurface).withValues(alpha: 0.55);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 4, 0),
            child: Row(
              children: [
                Text(
                  lang.isEmpty ? 'text' : lang,
                  style: TextStyle(fontSize: 12, color: muted, fontFamily: monoFontFamily),
                ),
                const Spacer(),
                IconButton(
                  tooltip: _copied ? '已複製' : '複製',
                  visualDensity: VisualDensity.compact,
                  iconSize: 15,
                  color: muted,
                  onPressed: _copy,
                  icon: Icon(_copied ? AppIcons.copied : AppIcons.copy),
                ),
              ],
            ),
          ),
          Scrollbar(
            controller: _scroll,
            child: SingleChildScrollView(
              controller: _scroll,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              // Unhighlighted tokens carry no style; give them the base one.
              child: Text.rich(TextSpan(style: baseStyle, children: spans), softWrap: false),
            ),
          ),
        ],
      ),
    );
  }
}
