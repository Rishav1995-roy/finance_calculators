import 'dart:math' as math;

import 'package:finance_calculators/finance_calculators.dart';
import 'package:finance_calculators/src/charts/chart_utils.dart';
import 'package:finance_calculators/src/charts/donut_chart.dart' as impl;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(Widget child, {double w = 360, double h = 400, ThemeData? theme}) =>
    MaterialApp(
      theme: theme,
      home: Scaffold(
        body: Center(child: SizedBox(width: w, height: h, child: child)),
      ),
    );

void main() {
  group('niceTicks', () {
    void ok(List<double> t) {
      expect(t.length, greaterThanOrEqualTo(2));
      for (var i = 0; i < t.length; i++) {
        expect(t[i].isFinite, isTrue);
        if (i > 0) expect(t[i], greaterThan(t[i - 1]));
      }
    }

    test('edge inputs always give finite ascending ticks', () {
      ok(niceTicks(0, 0));
      ok(niceTicks(5, 5));
      ok(niceTicks(0, double.nan));
      ok(niceTicks(double.infinity, double.negativeInfinity));
      ok(niceTicks(-100, 250));
      ok(niceTicks(0, 1e18));
      ok(niceTicks(0, 1e-9));
      ok(niceTicks(0, 12345678901234));
    });

    test('covers the range with round steps', () {
      final t = niceTicks(0, 87);
      expect(t.first, 0);
      expect(t.last, greaterThanOrEqualTo(87));
      expect(t, <double>[0, 50, 100]);
    });
  });

  test('resample', () {
    expect(resample(<double>[], 3), <double>[0, 0, 0]);
    expect(resample(<double>[1, 3], 3), <double>[1, 2, 3]);
    expect(resample(<double>[7], 2), <double>[7, 7]);
  });

  test('sliceIndexAt maps angles and respects the hole', () {
    const side = 200.0;
    final v = <double>[50, 50];
    // Start at 12 o'clock, clockwise: first slice is the right half.
    expect(impl.sliceIndexAt(const Offset(180, 100), side, v), 0);
    expect(impl.sliceIndexAt(const Offset(20, 100), side, v), 1);
    expect(impl.sliceIndexAt(const Offset(100, 100), side, v), isNull);
    expect(impl.sliceIndexAt(const Offset(0, 0), side, v), isNull);
    expect(impl.sliceIndexAt(const Offset(180, 100), side, <double>[0, 0]),
        isNull);
  });

  group('DonutChart', () {
    testWidgets('renders slices, legend and center; tap selects',
        (tester) async {
      int? tapped = -1;
      await tester.pumpWidget(host(DonutChart(
        slices: const <ChartSlice>[
          ChartSlice(label: 'Invested', value: 600000),
          ChartSlice(label: 'Returns', value: 400000),
        ],
        centerLabel: 'Total',
        centerValue: '10L',
        onSliceTap: (i) => tapped = i,
      )));
      await tester.pumpAndSettle();
      expect(find.text('Invested  600K'), findsOneWidget);
      expect(find.text('10L'), findsOneWidget);
      final box = tester.getRect(find.byType(CustomPaint).last);
      await tester.tapAt(Offset(box.right - 12, box.center.dy));
      await tester.pumpAndSettle();
      expect(tapped, 0);
      expect(find.text('600K'), findsWidgets);
      await tester.tapAt(Offset(box.right - 12, box.center.dy));
      await tester.pumpAndSettle();
      expect(tapped, isNull);
    });

    testWidgets('edge data: zeros, NaN, negative, single, huge, tiny box',
        (tester) async {
      final cases = <List<ChartSlice>>[
        const <ChartSlice>[],
        const <ChartSlice>[
          ChartSlice(label: 'a', value: 0),
          ChartSlice(label: 'b', value: 0)
        ],
        const <ChartSlice>[
          ChartSlice(label: 'a', value: double.nan),
          ChartSlice(label: 'b', value: -5)
        ],
        const <ChartSlice>[ChartSlice(label: 'a', value: 1)],
        const <ChartSlice>[
          ChartSlice(label: 'a', value: 1e18),
          ChartSlice(label: 'b', value: 1)
        ],
        const <ChartSlice>[ChartSlice(label: 'a', value: double.infinity)],
      ];
      for (final c in cases) {
        await tester.pumpWidget(host(DonutChart(slices: c)));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(host(PieChart(slices: c), w: 20, h: 20));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(host(DonutChart(slices: c), w: 0, h: 0));
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('centerBuilder and legendBuilder replace defaults',
        (tester) async {
      await tester.pumpWidget(host(DonutChart(
        slices: const <ChartSlice>[ChartSlice(label: 'A', value: 1)],
        centerBuilder: (c, i) => const Text('custom-center'),
        legendBuilder: (c, items) => Text('legend:${items.length}'),
      )));
      await tester.pumpAndSettle();
      expect(find.text('custom-center'), findsOneWidget);
      expect(find.text('legend:1'), findsOneWidget);
    });
  });

  group('GaugeChart', () {
    testWidgets('shows percent and handles bad values', (tester) async {
      await tester
          .pumpWidget(host(const GaugeChart(value: 42, label: 'Share')));
      await tester.pumpAndSettle();
      expect(find.text('42%'), findsOneWidget);
      for (final v in <double>[double.nan, -10, 1e30, double.infinity]) {
        await tester.pumpWidget(host(GaugeChart(value: v)));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      await tester
          .pumpWidget(host(const GaugeChart(value: 5, min: 10, max: 10)));
      await tester.pumpAndSettle();
      expect(find.text('0%'), findsOneWidget);
    });
  });

  group('StackedBarChart', () {
    StackedBarData data(List<double> a, List<double> b) => StackedBarData(
          labels: <String>[for (var i = 0; i < a.length; i++) 'Y${i + 1}'],
          series: <BarSeries>[
            BarSeries(label: 'Invested', values: a),
            BarSeries(label: 'Returns', values: b),
          ],
        );

    testWidgets('tap reports the bar and shows a tooltip', (tester) async {
      int? selected;
      await tester.pumpWidget(host(StackedBarChart(
        data: data(<double>[100, 200, 300, 400], <double>[10, 40, 90, 160]),
        onBarSelected: (i) => selected = i,
      )));
      await tester.pumpAndSettle();
      final r = tester.getRect(find.byType(CustomPaint).last);
      await tester.tapAt(Offset(r.right - 20, r.center.dy));
      await tester.pumpAndSettle();
      expect(selected, 3);
      expect(tester.takeException(), isNull);
    });

    testWidgets('edge data: empty, single, zero returns, huge, NaN, narrow',
        (tester) async {
      final cases = <StackedBarData>[
        data(<double>[], <double>[]),
        data(<double>[100], <double>[0]),
        data(<double>[0, 0, 0], <double>[0, 0, 0]),
        data(<double>[1e18, 2e18], <double>[5e17, 1e18]),
        data(<double>[double.nan, 5], <double>[double.infinity, -4]),
        data(List<double>.filled(120, 5000), List<double>.filled(120, 1)),
      ];
      for (final d in cases) {
        for (final w in <double>[360, 60, 10]) {
          await tester.pumpWidget(host(StackedBarChart(data: d), w: w, h: 300));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: 'width $w');
        }
      }
    });

    testWidgets('tooltipBuilder text is used', (tester) async {
      await tester.pumpWidget(host(StackedBarChart(
        data: data(<double>[1, 2], <double>[1, 2]),
        tooltipBuilder: (i) => <String>['hello $i'],
      )));
      await tester.pumpAndSettle();
      final r = tester.getRect(find.byType(CustomPaint).last);
      await tester.tapAt(Offset(r.right - 10, r.center.dy));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('LineAreaChart', () {
    testWidgets('edge data renders', (tester) async {
      final cases = <List<LineSeries>>[
        const <LineSeries>[],
        const <LineSeries>[LineSeries(label: 'a', values: <double>[])],
        const <LineSeries>[
          LineSeries(label: 'a', values: <double>[5])
        ],
        const <LineSeries>[
          LineSeries(label: 'a', values: <double>[0, 0, 0])
        ],
        const <LineSeries>[
          LineSeries(label: 'a', values: <double>[1e18, 5e18, 1e19])
        ],
        const <LineSeries>[
          LineSeries(
              label: 'a', values: <double>[double.nan, 1, double.infinity, -3])
        ],
        <LineSeries>[
          LineSeries(
              label: 'a',
              values: List<double>.generate(480, (i) => i * 1000.0)),
          const LineSeries(label: 'b', values: <double>[1, 2, 3]),
        ],
      ];
      for (final c in cases) {
        for (final w in <double>[360, 50]) {
          await tester.pumpWidget(host(
              LineAreaChart(series: c, xLabels: <String>['a', 'b', 'c']),
              w: w));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      }
    });

    testWidgets('drag selects points', (tester) async {
      final seen = <int?>[];
      await tester.pumpWidget(host(LineAreaChart(
        series: const <LineSeries>[
          LineSeries(label: 'v', values: <double>[1, 2, 3, 4, 5])
        ],
        xLabels: const <String>['1', '2', '3', '4', '5'],
        onPointSelected: seen.add,
      )));
      await tester.pumpAndSettle();
      final r = tester.getRect(find.byType(CustomPaint).last);
      final g = await tester.startGesture(Offset(r.left + 60, r.center.dy));
      await g.moveBy(const Offset(30, 0));
      await g.moveBy(Offset(r.right - r.left - 120, 0));
      await tester.pump();
      await g.up();
      expect(seen.whereType<int>(), isNotEmpty);
      expect(seen.last, 4);
    });
  });

  testWidgets('charts animate to new data then settle', (tester) async {
    Widget chart(double v) => host(StackedBarChart(
          data: StackedBarData(labels: const <String>[
            'a'
          ], series: <BarSeries>[
            BarSeries(label: 's', values: <double>[v]),
          ]),
        ));
    await tester.pumpWidget(chart(100));
    await tester.pumpAndSettle();
    await tester.pumpWidget(chart(300));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('animate: false and zero duration paint immediately',
      (tester) async {
    await tester.pumpWidget(host(const GaugeChart(value: 50, animate: false)));
    expect(tester.hasRunningAnimations, isFalse);
    expect(find.text('50%'), findsOneWidget);
  });

  testWidgets('MorphBuilder glides between values', (tester) async {
    List<double>? last;
    Widget w(List<double> v) => MorphBuilder(
          values: v,
          duration: const Duration(milliseconds: 1000),
          curve: Curves.linear,
          builder: (c, vals) {
            last = vals;
            return const SizedBox();
          },
        );
    await tester.pumpWidget(w(<double>[0]));
    await tester.pumpAndSettle();
    expect(last, <double>[0]);
    await tester.pumpWidget(w(<double>[100]));
    await tester.pump(const Duration(milliseconds: 500));
    expect(last!.first, closeTo(50, 5));
    await tester.pumpAndSettle();
    expect(last, <double>[100]);
  });

  testWidgets('theme: colors come from FinanceCalculatorTheme', (tester) async {
    final t = const FinanceCalculatorTheme.dark().copyWith(
      seriesColors: const <Color>[Color(0xFFFF0000)],
    );
    expect(t.seriesColor(7), const Color(0xFFFF0000));
    await tester.pumpWidget(host(
      DonutChart(
        slices: const <ChartSlice>[ChartSlice(label: 'L-one', value: 1)],
        theme: t,
      ),
    ));
    await tester.pumpAndSettle();
    final swatch = tester
        .widgetList<Container>(find.byType(Container))
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .where((d) => d.color == const Color(0xFFFF0000));
    expect(swatch, isNotEmpty);
    // lerp keeps the extension contract
    expect(
        const FinanceCalculatorTheme.light().lerp(t, 1).textColor, t.textColor);
    expect(math.pi, greaterThan(3));
  });
}
