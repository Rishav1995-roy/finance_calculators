// Renders the example UI frame by frame (no device, no emulator) and writes
// PNG frames to build/demo_frames plus the screenshots to doc/.
//
//   flutter test tool/demo/generate_demo_test.dart
//   tool/make_gif.sh
//
// Note: this is a Flutter test render of the real widgets with real fonts,
// not a screen recording of a physical device.
// ignore_for_file: avoid_relative_lib_imports
@Tags(<String>['demo'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../example/lib/main.dart';

const double _capture = 2;

Future<void> _loadFonts() async {
  Future<ByteData> bytes(String f) async =>
      ByteData.sublistView(File('tool/fonts/$f').readAsBytesSync());
  final FontLoader roboto = FontLoader('Roboto')
    ..addFont(bytes('Roboto-Regular.ttf'))
    ..addFont(bytes('Roboto-Medium.ttf'))
    ..addFont(bytes('Roboto-Bold.ttf'));
  await roboto.load();
  final FontLoader icons = FontLoader('MaterialIcons')
    ..addFont(bytes('MaterialIcons-Regular.otf'));
  await icons.load();
}

void main() {
  final GlobalKey shot = GlobalKey();
  int frame = 0;

  Future<void> capture(WidgetTester tester, {String? path}) async {
    await tester.runAsync(() async {
      final RenderRepaintBoundary b =
          shot.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final ui.Image img = await b.toImage(pixelRatio: _capture);
      final ByteData? data =
          await img.toByteData(format: ui.ImageByteFormat.png);
      final String out = path ??
          'build/demo_frames/f${(frame++).toString().padLeft(4, '0')}.png';
      File(out)
        ..createSync(recursive: true)
        ..writeAsBytesSync(data!.buffer.asUint8List());
    });
  }

  Future<void> setup(WidgetTester tester, Widget app, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _loadFonts();
    await tester.pumpWidget(RepaintBoundary(key: shot, child: app));
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('demo gif frames', (WidgetTester tester) async {
    final Directory dir = Directory('build/demo_frames');
    if (dir.existsSync()) {
      for (final FileSystemEntity f in dir.listSync()) {
        f.deleteSync();
      }
    }
    await setup(tester, const ExampleApp(), const Size(390, 780));
    Future<void> tick([int ms = 83]) async {
      await tester.pump(Duration(milliseconds: ms));
      await capture(tester);
    }

    Future<void> hold(int n) async {
      for (int i = 0; i < n; i++) {
        await tick();
      }
    }

    Future<void> dragSlider(
        String id, double dx1, double dx2, int steps) async {
      final Finder s = find.descendant(
          of: find.byKey(ValueKey<String>('input-$id')),
          matching: find.byType(Slider));
      final Rect r = tester.getRect(s);
      final TestGesture g = await tester
          .startGesture(Offset(r.left + r.width * 0.2, r.center.dy));
      await tick();
      for (int i = 1; i <= steps; i++) {
        await g.moveBy(Offset(i <= steps ~/ 2 ? dx1 : dx2, 0));
        await tick();
      }
      await g.up();
    }

    Future<void> scroll(double dy, int steps) async {
      final Finder sc = find.byType(SingleChildScrollView).first;
      final TestGesture g = await tester.startGesture(const Offset(195, 600));
      for (int i = 0; i < steps; i++) {
        await g.moveBy(Offset(0, dy / steps));
        await tick();
      }
      await g.up();
      await tester.pump(const Duration(milliseconds: 400));
      sc.evaluate();
    }

    Future<void> chip(String key, {int frames = 11}) async {
      await tester.tap(find.byKey(ValueKey<String>(key)));
      await hold(frames);
    }

    // 1. SIP: drag the monthly amount and the years.
    await hold(3);
    await dragSlider('monthly', 7, -9, 12);
    await hold(2);
    await dragSlider('years', 5, 5, 6);
    await hold(2);
    // 2. Down to the chart, then donut -> bar -> line.
    await scroll(-470, 8);
    await hold(5);
    await chip('chart-bar');
    await chip('chart-line');
    await chip('chart-donut', frames: 8);
    // 3. Dark mode, EMI calculator.
    await tester.tap(find.byKey(const ValueKey<String>('theme-toggle')));
    await tester.pump(const Duration(milliseconds: 400));
    await hold(2);
    await tester.tap(find.byKey(const ValueKey<String>('tab-EMI')));
    await tester.pump(const Duration(milliseconds: 100));
    await hold(2);
    await scroll(-470, 6);
    await hold(4);
    await chip('chart-bar', frames: 10);
    await chip('chart-line', frames: 10);
    await hold(3);
    // ignore: avoid_print
    print('frames: $frame');
  }, tags: 'demo');

  testWidgets('screenshots', (WidgetTester tester) async {
    // Light: EMI with the donut.
    await setup(tester, const ExampleApp(), const Size(390, 1500));
    await tester.tap(find.byKey(const ValueKey<String>('tab-EMI')));
    await tester.pumpAndSettle();
    await capture(tester, path: 'doc/screenshot_light.png');
    // Dark: SIP with the stacked bars.
    await tester.pumpWidget(const SizedBox());
    await setup(
        tester, const ExampleApp(initialDark: true), const Size(390, 1500));
    await tester.tap(find.byKey(const ValueKey<String>('chart-bar')));
    await tester.pumpAndSettle();
    await capture(tester, path: 'doc/screenshot_dark.png');
  }, tags: 'demo');
}
