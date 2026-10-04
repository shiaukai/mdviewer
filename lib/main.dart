import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'services/external_open.dart';
import 'state/app_state.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  // List this app's own license alongside the dependencies' in 開源授權.
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(['MD Viewer'], await rootBundle.loadString('LICENSE'));
  });

  final state = await AppState.load();
  runApp(MdViewerApp(state: state));

  // Store builds only: check the supporter purchase; only non-supporters on
  // phones/tablets load the ads SDK (and see the consent form if required).
  if (state.monetized) {
    unawaited(state.supporter.init());
    if (!state.supporter.isSupporter) unawaited(state.ads.start());
  }

  // Files passed by the OS: command-line arguments (Windows "Open with"),
  // or the platform channel (macOS Finder, iOS Files, Android intents).
  final fromChannel = await ExternalOpen.listen(state.openExternal);
  await state.restore([
    ...args.where((a) => !a.startsWith('-')),
    ...fromChannel,
  ]);
}
