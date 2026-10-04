import 'package:flutter/material.dart';
import 'package:html/dom.dart' as h;
import 'package:html/parser.dart' as html_parser;
import 'package:markdown/markdown.dart' as m;
import 'package:markdown_widget/markdown_widget.dart';

import 'nodes.dart';

final _tagPattern = RegExp(r'<\/?[a-zA-Z][^>]*>|<!--');

const _blockTags = {
  'p', 'div', 'center', 'section', 'article', 'header', 'footer', 'figure',
  'details', 'summary', 'blockquote', 'ul', 'ol', 'li', 'table', 'tr',
  'h1', 'h2', 'h3', 'h4', 'h5', 'h6',
};

const _hiddenTags = {'script', 'style', 'head', 'title', 'template', 'source', 'track'};

/// The markdown parser leaves raw HTML as text nodes. This converts the
/// common README subset (centered logos, `<img>`, `<br>`, `<b>`, `<a>`,
/// `<details>`…) into span nodes; anything else degrades to plain text, and
/// comments disappear instead of showing up as literal markup.
SpanNode? htmlTextGenerator(m.Node node, MarkdownConfig config, WidgetVisitor visitor) {
  if (node is! m.Text || !_tagPattern.hasMatch(node.text)) return null;
  try {
    final fragment = html_parser.parseFragment(node.text);
    final root = InlineStyleNode(config.p.textStyle);
    _HtmlConverter(config, visitor).addAll(fragment.nodes, root);
    return root;
  } catch (_) {
    return null;
  }
}

class _HtmlConverter {
  _HtmlConverter(this.config, this.visitor);

  final MarkdownConfig config;
  final WidgetVisitor visitor;

  void addAll(Iterable<h.Node> nodes, ElementNode parent) {
    for (final n in nodes) {
      add(n, parent);
    }
  }

  void add(h.Node node, ElementNode parent) {
    if (node is h.Text) {
      final text = node.text;
      if (text.trim().isEmpty) {
        // Indentation between tags; keep a single space between inline bits.
        if (!text.contains('\n')) parent.accept(TextNode(text: ' '));
        return;
      }
      parent.accept(TextNode(text: text.replaceAll(RegExp(r'\s+'), ' ')));
      return;
    }
    if (node is! h.Element) return; // comments, doctype…

    final tag = (node.localName ?? '').toLowerCase();
    if (_hiddenTags.contains(tag)) return;
    final attrs = node.attributes.map((k, v) => MapEntry(k.toString(), v));

    SpanNode? leaf;
    ElementNode? container;
    switch (tag) {
      case 'img':
        leaf = visitor.getNodeByElement(m.Element.empty('img')..attributes.addAll(attrs), config);
      case 'br':
        leaf = visitor.getNodeByElement(m.Element.empty('br'), config);
      case 'hr':
        leaf = visitor.getNodeByElement(m.Element.empty('hr'), config);
      case 'code' || 'kbd' || 'samp' || 'tt':
        leaf = visitor.getNodeByElement(m.Element('code', [m.Text(node.text)]), config);
      case 'pre':
        leaf = visitor.getNodeByElement(
            m.Element('pre', [m.Element('code', [m.Text(node.text)])]), config);
      case 'a':
        container = visitor.getNodeByElement(
            m.Element('a', [])..attributes['href'] = attrs['href'] ?? '', config) as ElementNode;
      case 'b' || 'strong':
        container = StrongNode();
      case 'i' || 'em' || 'cite':
        container = EmNode();
      case 's' || 'strike' || 'del':
        container = DelNode();
      case 'sup' || 'sub' || 'small':
        container = InlineStyleNode(const TextStyle(fontSize: 12));
      case 'u' || 'ins':
        container = InlineStyleNode(const TextStyle(decoration: TextDecoration.underline));
      case 'mark':
        container = InlineStyleNode(const TextStyle(backgroundColor: Color(0x66ffeb3b)));
      case 'summary':
        container = HtmlBlockNode(
          blockStyle: const TextStyle(fontWeight: FontWeight.w600),
          prefix: '▸ ',
        );
      case 'li':
        container = HtmlBlockNode(prefix: '•  ');
      default:
        if (_blockTags.contains(tag)) {
          container = HtmlBlockNode(
            align: _align(tag, attrs),
            blockStyle: _headingStyle(tag),
          );
        } else {
          container = InlineStyleNode();
        }
    }

    if (leaf != null) {
      parent.accept(leaf);
      return;
    }
    parent.accept(container);
    addAll(node.nodes, container!);
  }

  TextAlign _align(String tag, Map<String, String> attrs) {
    if (tag == 'center') return TextAlign.center;
    final align = (attrs['align'] ?? '').toLowerCase();
    final style = (attrs['style'] ?? '').toLowerCase().replaceAll(' ', '');
    if (align == 'center' || style.contains('text-align:center')) return TextAlign.center;
    if (align == 'right' || style.contains('text-align:right')) return TextAlign.right;
    return TextAlign.start;
  }

  TextStyle? _headingStyle(String tag) => switch (tag) {
        'h1' => config.h1.style,
        'h2' => config.h2.style,
        'h3' => config.h3.style,
        'h4' => config.h4.style,
        'h5' => config.h5.style,
        'h6' => config.h6.style,
        _ => null,
      };
}
