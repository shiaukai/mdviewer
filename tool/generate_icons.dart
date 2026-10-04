// Draws the MD Viewer logo and writes the launcher icon sources.
//
//   flutter test tool/generate_icons.dart
//   dart run flutter_launcher_icons
//
// The logo is defined here as SVG so it can be tweaked in one place; it is
// rasterised with flutter_svg (no external tools needed).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

const _defs = '''
<defs>
  <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="#5C8DFF"/>
    <stop offset="1" stop-color="#2A52CC"/>
  </linearGradient>
</defs>''';

/// The document with the Markdown mark, drawn on a 1024 canvas.
const _document = '''
<path fill="#1C3A9E" fill-opacity="0.35"
  d="M316 216H612L744 348V804Q744 840 708 840H316Q280 840 280 804V252Q280 216 316 216Z"/>
<path fill="#FFFFFF"
  d="M316 200H612L744 332V788Q744 824 708 824H316Q280 824 280 788V236Q280 200 316 200Z"/>
<path fill="#C8D7FF" d="M612 200V300Q612 332 644 332H744Z"/>
<rect x="318" y="296" width="214" height="32" rx="16" fill="#D3DEF8"/>
<rect x="318" y="364" width="340" height="32" rx="16" fill="#D3DEF8"/>
<g fill="none" stroke="#2F5BD8" stroke-width="46" stroke-linecap="round" stroke-linejoin="round">
  <path d="M341 714V500L421 596L501 500V714"/>
  <path d="M634 500V714M582 662L634 714L686 662"/>
</g>''';

enum _Background { none, rounded, square }

String _logoSvg({_Background background = _Background.rounded, double scale = 1}) {
  final bg = switch (background) {
    _Background.none => '',
    _Background.rounded => '<rect width="1024" height="1024" rx="228" fill="url(#bg)"/>',
    _Background.square => '<rect width="1024" height="1024" fill="url(#bg)"/>',
  };
  final doc = scale == 1
      ? _document
      : '<g transform="translate(512 512) scale($scale) translate(-512 -512)">$_document</g>';
  return '<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">'
      '$_defs$bg$doc</svg>';
}

Future<void> _writePng(
  String path,
  String svg, {
  int size = 1024,
  double inset = 0,
  bool shadow = false,
}) async {
  final info = await vg.loadPicture(SvgStringLoader(svg), null);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final box = size - inset * 2;
  if (shadow) {
    // macOS-style soft shadow under the rounded square.
    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(inset, inset + box * 0.012, box, box),
      Radius.circular(box * 228 / 1024),
    );
    canvas.drawRRect(
      r,
      Paint()
        ..color = const Color(0x55000000)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, box * 0.018),
    );
  }
  canvas
    ..translate(inset, inset)
    ..scale(box / info.size.width)
    ..drawPicture(info.picture);
  final image = await recorder.endRecording().toImage(size, size);
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(png!.buffer.asUint8List());
  info.picture.dispose();
}

void main() {
  testWidgets('generate logo and icons', (tester) async {
    await tester.runAsync(() async {
      // In-app logo (welcome screen, drawer, README).
      File('assets/images/logo.svg').writeAsStringSync(_logoSvg());

      const dir = 'assets/icon';
      // Windows / Android legacy / general purpose.
      await _writePng('$dir/icon.png', _logoSvg());
      // iOS masks the corners itself and rejects transparency.
      await _writePng('$dir/icon_ios.png', _logoSvg(background: _Background.square));
      // macOS Big Sur grid: 824pt shape centred on 1024 with a shadow.
      await _writePng('$dir/icon_macos.png', _logoSvg(), inset: 100, shadow: true);
      // Android adaptive icon: the launcher crops to a circle/squircle inside
      // the middle 66%, so shrink the document into that safe zone.
      await _writePng('$dir/android_foreground.png',
          _logoSvg(background: _Background.none, scale: 0.72));
      await _writePng('$dir/android_background.png',
          '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">$_defs'
          '<rect width="1024" height="1024" fill="url(#bg)"/></svg>');
    });
  });
}
