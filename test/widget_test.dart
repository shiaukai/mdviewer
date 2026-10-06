import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mdviewer/app.dart';
import 'package:mdviewer/layout/breakpoints.dart';
import 'package:mdviewer/models/md_document.dart';
import 'package:mdviewer/state/viewer_controller.dart';
import 'package:mdviewer/ui/desktop_shell.dart';
import 'package:mdviewer/ui/markdown_view.dart';
import 'package:mdviewer/ui/mobile_shell.dart';
import 'package:mdviewer/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Breakpoints', () {
    test('phone portrait is mobile', () {
      expect(Breakpoints.of(const Size(390, 844)), LayoutMode.mobile); // iPhone 15
      expect(Breakpoints.of(const Size(375, 667)), LayoutMode.mobile); // iPhone SE
      expect(Breakpoints.of(const Size(412, 915)), LayoutMode.mobile); // Pixel
    });

    test('phone landscape switches to desktop', () {
      expect(Breakpoints.of(const Size(844, 390)).isDesktop, isTrue);
      expect(Breakpoints.of(const Size(667, 375)).isDesktop, isTrue); // iPhone SE
      expect(Breakpoints.of(const Size(932, 430)), LayoutMode.medium);
    });

    test('tablets are desktop in both orientations', () {
      expect(Breakpoints.of(const Size(744, 1133)), LayoutMode.medium); // iPad mini
      expect(Breakpoints.of(const Size(820, 1180)), LayoutMode.medium); // iPad Air
      expect(Breakpoints.of(const Size(1180, 820)), LayoutMode.wide);
      expect(Breakpoints.of(const Size(1366, 1024)), LayoutMode.wide);
    });

    test('narrow desktop window falls back to mobile', () {
      expect(Breakpoints.of(const Size(500, 800)), LayoutMode.mobile);
      expect(Breakpoints.of(const Size(1440, 900)), LayoutMode.wide);
    });
  });

  group('MdDocument', () {
    test('extracts headings with block indices and GitHub slugs', () {
      final doc = MdDocument(title: 't', content: '''
# Title

Intro paragraph.

## Getting Started!

```md
# not a heading
```

## Getting Started!

### 中文 標題
''');
      expect(doc.headings.map((h) => h.text), ['Title', 'Getting Started!', 'Getting Started!', '中文 標題']);
      expect(doc.headings.map((h) => h.level), [1, 2, 2, 3]);
      expect(doc.headings.map((h) => h.slug), ['title', 'getting-started', 'getting-started-1', '中文-標題']);
      expect(doc.headings.map((h) => h.blockIndex), [0, 2, 4, 5]);
      expect(doc.headingForSlug('Getting-Started-1'), same(doc.headings[2]));
    });

    test('turns front matter into a code block', () {
      final doc = MdDocument(title: 't', content: '---\ntitle: x\n---\n# Real\n');
      expect(doc.source, startsWith('```yaml\ntitle: x\n```'));
      expect(doc.headings.single.text, 'Real');
    });
  });

  testWidgets('MarkdownView renders blocks and jumps to a heading', (tester) async {
    final controller = ViewerController();
    final content = StringBuffer();
    for (var i = 1; i <= 30; i++) {
      content.writeln('## Section $i\n\nSome text for section $i.\n');
    }
    final doc = MdDocument(title: 't', content: content.toString());
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MarkdownView(document: doc, controller: controller, onLinkTap: (_) {}),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('Section 1', findRichText: true), findsWidgets);

    controller.jumpToHeading(doc.headings[20]);
    await tester.pumpAndSettle();
    expect(find.textContaining('Section 21', findRichText: true), findsWidgets);
    expect(controller.currentHeading.value, 20);
  });

  testWidgets('jumping to a heading near the end keeps it highlighted', (tester) async {
    final controller = ViewerController();
    final doc = MdDocument(title: 't', content: '''
# Title

${List.filled(40, 'Long paragraph text.').join('\n\n')}

## Near the end

Short.

## Last

Short.
''');
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: MarkdownView(document: doc, controller: controller, onLinkTap: (_) {})),
    ));
    await tester.pumpAndSettle();
    // "Near the end" can't reach the top: the list stops at its bottom edge.
    controller.jumpToHeading(doc.headings[1]);
    await tester.pumpAndSettle();
    expect(controller.currentHeading.value, 1);
  });

  testWidgets('raw HTML: comments hidden, common tags rendered as text', (tester) async {
    final doc = MdDocument(title: 't', content: '''
<!-- secret comment -->
<p align="center"><b>Centered</b><br>Line two</p>

See [docs](a.md).
''');
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MarkdownView(document: doc, controller: ViewerController(), onLinkTap: (_) {}),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('secret comment', findRichText: true), findsNothing);
    expect(find.textContaining('<p', findRichText: true), findsNothing);
    expect(find.textContaining('Centered', findRichText: true), findsWidgets);
    // No stray space between a link and the following punctuation.
    expect(find.textContaining('See docs.', findRichText: true), findsOneWidget);
  });

  testWidgets('builds from source show no ads, support bar or purchase UI', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = await AppState.load(); // STORE_BUILD not defined
    expect(state.monetized, isFalse);
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MdViewerApp(state: state));
    await tester.pump();
    expect(find.textContaining('成為支持者'), findsNothing);
  });

  testWidgets('store build: desktop support bar, dismissible, gone for supporters', (tester) async {
    // Tests run on a desktop host, so the slot shows the house bar, not ads.
    SharedPreferences.setMockInitialValues({});
    final state = await AppState.load(monetized: true);
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MdViewerApp(state: state));
    await tester.pump();
    expect(find.textContaining('成為支持者即可移除這條提示'), findsOneWidget);

    await tester.tap(find.byTooltip('暫時關閉'));
    await tester.pump();
    expect(find.textContaining('成為支持者即可移除這條提示'), findsNothing);

    SharedPreferences.setMockInitialValues({'isSupporter': true});
    final supporterState = await AppState.load(monetized: true);
    await tester.pumpWidget(MdViewerApp(state: supporterState));
    await tester.pump();
    expect(find.textContaining('成為支持者即可移除這條提示'), findsNothing);
  });

  testWidgets('layout follows window size and orientation', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = await AppState.load();

    Future<void> pumpAt(Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(MdViewerApp(state: state));
      await tester.pump();
    }

    addTearDown(tester.view.reset);

    await pumpAt(const Size(390, 844)); // phone portrait
    expect(find.byType(MobileShell), findsOneWidget);

    await pumpAt(const Size(844, 390)); // phone landscape
    expect(find.byType(DesktopShell), findsOneWidget);

    await pumpAt(const Size(820, 1180)); // tablet portrait
    expect(find.byType(DesktopShell), findsOneWidget);
  });
}
