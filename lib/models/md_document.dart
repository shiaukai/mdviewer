import 'package:markdown/markdown.dart' as m;
import 'package:path/path.dart' as p;

/// Block syntaxes added on top of GitHub Flavored Markdown.
/// Shared by the renderer and the outline parser so block indices line up.
final List<m.BlockSyntax> extraBlockSyntaxes = [const m.AlertBlockSyntax()];

/// Same line splitting rule markdown_widget uses internally.
final RegExp lineSplitter = RegExp(r'(\r?\n)|(\r)');

const markdownExtensions = {'.md', '.markdown', '.mdown', '.mkd', '.mkdn'};

bool isMarkdownPath(String path) =>
    markdownExtensions.contains(p.extension(path).toLowerCase());

/// A heading in the document outline.
class MdHeading {
  const MdHeading({
    required this.level,
    required this.text,
    required this.blockIndex,
    required this.slug,
  });

  final int level;
  final String text;

  /// Index of the top-level block (= list item in the viewer) holding it.
  final int blockIndex;

  /// GitHub-style anchor, used for `[link](#anchor)`.
  final String slug;
}

class MdDocument {
  MdDocument({
    required this.content,
    required this.title,
    this.path,
    this.assetBase,
  });

  /// Absolute file path; null for bundled documents.
  final String? path;

  /// Asset directory for bundled documents (resolves relative images).
  final String? assetBase;

  final String title;
  final String content;

  /// Markdown fed to the renderer (front matter turned into a code block).
  late final String source = _preprocess(content);

  late final List<MdHeading> headings = _extractHeadings(source);

  String? get directory => path == null ? null : p.dirname(path!);

  /// References images or links relative to the file (needs folder access
  /// in the macOS sandbox).
  late final bool hasLocalReferences = RegExp(
    r'''\]\(\s*(?!https?:|mailto:|data:|#)[^)\s]|<img[^>]+src=["'](?!https?:|data:)''',
    caseSensitive: false,
  ).hasMatch(source);

  int get wordCount {
    final cjk = RegExp(r'[\u3400-\u9fff\uf900-\ufaff\u3040-\u30ff\uac00-\ud7af]');
    final cjkCount = cjk.allMatches(content).length;
    final latin = content
        .replaceAll(cjk, ' ')
        .split(RegExp(r'\s+'))
        .where((w) => RegExp(r'[A-Za-z0-9]').hasMatch(w))
        .length;
    return cjkCount + latin;
  }

  MdHeading? headingForSlug(String slug) {
    final target = slug.toLowerCase();
    for (final h in headings) {
      if (h.slug == target) return h;
    }
    return null;
  }

  static String _preprocess(String raw) {
    var text = raw.startsWith('﻿') ? raw.substring(1) : raw;
    // YAML front matter → fenced yaml block, so it doesn't render as
    // a setext heading.
    final fm = RegExp(r'^---[ \t]*\r?\n([\s\S]*?)\r?\n(---|\.\.\.)[ \t]*(\r?\n|$)')
        .firstMatch(text);
    if (fm != null) {
      text = '```yaml\n${fm.group(1)}\n```\n\n${text.substring(fm.end)}';
    }
    return text;
  }

  static List<MdHeading> _extractHeadings(String source) {
    final doc = m.Document(
      extensionSet: m.ExtensionSet.gitHubFlavored,
      encodeHtml: false,
      blockSyntaxes: extraBlockSyntaxes,
    );
    final nodes = doc.parseLines(source.split(lineSplitter));
    final result = <MdHeading>[];
    final used = <String, int>{};
    for (var i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      if (node is! m.Element) continue;
      final match = RegExp(r'^h([1-6])$').firstMatch(node.tag);
      if (match == null) continue;
      final text = node.textContent.trim();
      var slug = slugify(text);
      final seen = used[slug];
      used[slug] = (seen ?? -1) + 1;
      if (seen != null) slug = '$slug-${seen + 1}';
      result.add(MdHeading(
        level: int.parse(match.group(1)!),
        text: text,
        blockIndex: i,
        slug: slug,
      ));
    }
    return result;
  }

  /// GitHub's anchor algorithm: lowercase, drop punctuation, spaces → '-'.
  static String slugify(String text) => text
      .toLowerCase()
      .replaceAll(RegExp(r'[^\p{L}\p{N}\p{M}\s_-]', unicode: true), '')
      .trim()
      .replaceAll(RegExp(r'\s'), '-');
}
