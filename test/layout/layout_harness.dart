import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:tripnest_ph/core/theme/accent_colors.dart';
import 'package:tripnest_ph/core/theme/app_theme.dart';

/// Every surface the responsive audit covers: phones (incl. a very small
/// one), tablets, and desktop windows, each in portrait and landscape, plus
/// the short/wide extremes a resized browser window or split-screen produces.
const layoutSizes = <String, Size>{
  'phone-small 320x568': Size(320, 568),
  'phone 360x640': Size(360, 640),
  'phone 390x844': Size(390, 844),
  'phone-landscape 844x390': Size(844, 390),
  'phone-landscape-short 640x320': Size(640, 320),
  'tablet 768x1024': Size(768, 1024),
  'tablet-landscape 1024x768': Size(1024, 768),
  'desktop 1440x900': Size(1440, 900),
  'desktop-wide 1920x1080': Size(1920, 1080),
  'narrow-tall 280x900': Size(280, 900),
};

/// The in-app Text Size presets top out at 1.3 (Settings > Text Size).
const layoutTextScales = <double>[1.0, 1.3];

/// `flutter_test` renders every glyph in the Ahem font (a full em wide),
/// which makes horizontal text overflows wildly pessimistic, and the app's
/// real font (Poppins, fetched at runtime by google_fonts) isn't available
/// offline, so Roboto (bundled with the Flutter SDK's devtools assets) stands in.
/// The app's text theme sets explicit line heights, so vertical measurements
/// are exact at the default factor of 1.0.
///
/// Poppins' glyphs are roughly 12% wider than Roboto's: run with
/// LAYOUT_TEXT_FACTOR=1.12 to emulate that as a stress test. It scales text
/// past the app's real 1.3 maximum, so it also reports a few pixels of
/// vertical slack in the fixed-height card cells that don't exist in practice.
final double _poppinsWidthFactor = double.tryParse(Platform.environment['LAYOUT_TEXT_FACTOR'] ?? '') ?? 1.0;

bool _fontsLoaded = false;

/// The Flutter SDK root: FLUTTER_ROOT if the tool exported it, otherwise found
/// by walking up from the running test executable.
String? _flutterRoot() {
  final env = Platform.environment['FLUTTER_ROOT'];
  if (env != null && Directory(env).existsSync()) return env;
  var dir = File(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 8; i++) {
    if (Directory('${dir.path}/bin/cache/dart-sdk').existsSync()) return dir.path;
    dir = dir.parent;
  }
  return null;
}

/// Loads Roboto as the stand-in font. Returns false when the SDK's copy can't
/// be found — the caller skips rather than report false failures measured in
/// the (far wider) Ahem test font.
Future<bool> loadLayoutFonts() async {
  if (_fontsLoaded) return true;
  GoogleFonts.config.allowRuntimeFetching = false;
  final root = _flutterRoot();
  if (root == null) return false;
  final dir = '$root/bin/cache/dart-sdk/bin/resources/devtools/assets/fonts/Roboto';
  final loader = FontLoader('Roboto');
  var found = 0;
  for (final name in ['Regular', 'Medium', 'Bold']) {
    final file = File('$dir/Roboto-$name.ttf');
    if (file.existsSync()) {
      loader.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
      found++;
    }
  }
  if (found == 0) return false;
  await loader.load();
  _fontsLoaded = true;
  return true;
}

ThemeData layoutTheme() {
  final base = AppTheme.light(themePresets.first);
  return base.copyWith(
    textTheme: base.textTheme.apply(fontFamily: 'Roboto'),
    primaryTextTheme: base.primaryTextTheme.apply(fontFamily: 'Roboto'),
  );
}

/// Wraps [home] the way main.dart does (theme + a root text scaler), hosted
/// in a real [GoRouter] since screens read it for back buttons / navigation.
Widget layoutApp(double scale, Widget home) => MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: layoutTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale * _poppinsWidthFactor)),
        child: child!,
      ),
      routerConfig: GoRouter(routes: [GoRoute(path: '/', builder: (_, _) => home)]),
    );

final _layoutErrorPattern = RegExp(
  r'overflowed|BoxConstraints|unbounded|infinite|RenderBox|RenderFlex|Viewport|hit-test|size is not|Incorrect use of ParentData',
  caseSensitive: false,
);

/// Runs [body] while capturing every framework error (overflow, unbounded
/// constraints, ...) instead of aborting on the first, returning a one-line
/// summary per distinct error including the offending widget's source line.
Future<List<String>> captureLayoutErrors(Future<void> Function() body) async {
  final found = <String>{};
  final original = FlutterError.onError;
  FlutterError.onError = (details) {
    final text = details.toString().replaceAll(r'\', '/');
    // Screens built on a mocked firebase_core can't reach a backend; those
    // data errors aren't layout problems, so only layout-type errors count.
    if (Platform.environment['LAYOUT_VERBOSE'] != null) {
      // ignore: avoid_print
      print(details.toString());
    }
    if (!_layoutErrorPattern.hasMatch(details.exceptionAsString())) return;
    final head = details.exceptionAsString().split('\n').first;
    final loc = RegExp(r'(lib/[\w/]+\.dart):(\d+)').firstMatch(text);
    found.add('$head @ ${loc == null ? '?' : '${loc.group(1)}:${loc.group(2)}'}');
  };
  try {
    await body();
  } finally {
    FlutterError.onError = original;
  }
  return found.toList();
}

/// Set `LAYOUT_REPORT` to a file path to also append one line per failing case there.
void reportLayoutErrors(String name, List<String> errors) {
  final path = Platform.environment['LAYOUT_REPORT'];
  if (path == null || errors.isEmpty) return;
  File(path).writeAsStringSync(errors.map((e) => '$name | $e\n').join(), mode: FileMode.append);
}

final _shotKey = GlobalKey();

/// `LAYOUT_SHOTS` (a directory) saves a PNG per case whose label matches `LAYOUT_SHOT_FILTER`.
Future<void> _maybeScreenshot(WidgetTester tester, String label) async {
  final dir = Platform.environment['LAYOUT_SHOTS'];
  if (dir == null) return;
  final filter = Platform.environment['LAYOUT_SHOT_FILTER'];
  if (filter != null && !RegExp(filter).hasMatch(label)) return;
  await tester.runAsync(() async {
    final boundary = _shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(dir).createSync(recursive: true);
    final name = label.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
    File('$dir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

/// Registers one test per (size x text scale) that pumps [build] and asserts
/// no layout error is raised. [act] can drive the UI (open a dialog/sheet)
/// before the final settle.
void layoutMatrix(
  String name,
  Widget Function() build, {
  Future<void> Function(WidgetTester tester)? act,
  Widget Function(Widget app)? wrap,
  Future<void> Function()? setup,
  double keyboardHeight = 0,
  void Function(WidgetTester tester)? verify,
}) {
  for (final size in layoutSizes.entries) {
    for (final scale in layoutTextScales) {
      final label = '$name @ ${size.key} x$scale${keyboardHeight > 0 ? ' +keyboard' : ''}';
      testWidgets(label, (tester) async {
        if (!await loadLayoutFonts()) {
          markTestSkipped('Roboto (bundled with the Flutter SDK) not found; layout metrics would be meaningless in Ahem.');
          return;
        }
        tester.view.physicalSize = size.value;
        tester.view.devicePixelRatio = 1.0;
        // An open on-screen keyboard: viewInsets shrink the usable height (a
        // keyboard taller than the window can't exist, so cap it).
        if (keyboardHeight > 0) {
          tester.view.viewInsets = FakeViewPadding(bottom: keyboardHeight < size.value.height * 0.6 ? keyboardHeight : size.value.height * 0.6);
        }
        addTearDown(tester.view.reset);

        if (setup != null) await setup();
        final errors = await captureLayoutErrors(() async {
          final app = layoutApp(scale, build());
          await tester.pumpWidget(RepaintBoundary(key: _shotKey, child: wrap == null ? app : wrap(app)));
          if (act != null) await act(tester);
          // Bounded pumps (network image shimmers never settle).
          for (var i = 0; i < 5; i++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
        });
        await _maybeScreenshot(tester, label);
        verify?.call(tester);
        reportLayoutErrors(label, errors);
        expect(errors, isEmpty);
      });
    }
  }
}
