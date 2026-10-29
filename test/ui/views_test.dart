import 'package:finance_calculators/finance_calculators.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget app(Widget child, {ThemeData? theme}) => MaterialApp(
      theme: theme,
      home: Scaffold(body: child),
    );

Future<void> size(WidgetTester t, double w, double h) async {
  t.view.physicalSize = Size(w, h);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

void main() {
  const sipExpected = 2323391.0; // 10,000 x 120 months, 12% p.a., annuity-due

  group('numbers shown by the views', () {
    testWidgets('SIP headline equals the core result', (tester) async {
      await size(tester, 420, 1400);
      final c = SipCalculatorController();
      addTearDown(c.dispose);
      await tester.pumpWidget(app(SipCalculatorView(controller: c)));
      await tester.pumpAndSettle();
      final r = const SipCalculator(
              monthlyInvestment: 10000,
              annualReturnPercent: 12,
              tenure: Tenure.years(10))
          .calculate();
      expect(r.maturityValue, closeTo(sipExpected, 1));
      expect(c.result!.maturityValue, r.maturityValue);
      // first summary row is invested; the total row shows the maturity
      expect(
          find.text(CurrencyFormat.inr.format(r.maturityValue)), findsWidgets);
      expect(find.text(CurrencyFormat.inr.format(1200000)), findsWidgets);
    });

    testWidgets('typing into a field and moving a slider update the result',
        (tester) async {
      await size(tester, 420, 1600);
      final c = SipCalculatorController();
      addTearDown(c.dispose);
      await tester.pumpWidget(app(SipCalculatorView(controller: c)));
      await tester.pumpAndSettle();
      final field = find.descendant(
          of: find.byKey(const ValueKey<String>('input-monthly')),
          matching: find.byType(TextField));
      await tester.enterText(field, '25000');
      await tester.pumpAndSettle();
      expect(c.value('monthly'), 25000);
      final slider = find.descendant(
          of: find.byKey(const ValueKey<String>('input-years')),
          matching: find.byType(Slider));
      final before = c.result!.maturityValue;
      await tester.drag(slider, const Offset(100, 0));
      await tester.pumpAndSettle();
      expect(c.value('years'), greaterThan(10));
      expect(c.result!.maturityValue, greaterThan(before));
    });

    testWidgets('invalid input shows the error, errorBuilder replaces it',
        (tester) async {
      await size(tester, 420, 1400);
      final c = SipCalculatorController();
      addTearDown(c.dispose);
      await tester.pumpWidget(app(SipCalculatorView(controller: c)));
      c.setValue('monthly', 0);
      await tester.pumpAndSettle();
      expect(c.result, isNull);
      expect(find.textContaining('monthlyInvestment'), findsOneWidget);
      await tester.pumpWidget(app(SipCalculatorView(
        controller: c,
        errorBuilder: (ctx, m) => Text('custom-error: $m'),
      )));
      await tester.pumpAndSettle();
      expect(find.textContaining('custom-error: monthlyInvestment'),
          findsOneWidget);
    });

    testWidgets('EMI view shows EMI and prepayment savings', (tester) async {
      await size(tester, 420, 1600);
      final c = EmiCalculatorController();
      addTearDown(c.dispose);
      await tester.pumpWidget(app(EmiCalculatorView(controller: c)));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey<String>('summary-headline')),
          findsOneWidget);
      final emi = EmiCalculator.emiFor(2500000, 8.5, 240);
      expect(find.text(CurrencyFormat.inr.format(emi)), findsOneWidget);
      c.setValue('extra', 10000);
      await tester.pumpAndSettle();
      expect(c.result!.monthsSaved, greaterThan(0));
      expect(find.text('Time saved'), findsOneWidget);
    });

    testWidgets('every ready view builds in light/dark, narrow/wide',
        (tester) async {
      final builders = <Widget Function()>[
        () => const SipCalculatorView(),
        () => const LumpsumCalculatorView(),
        () => const EmiCalculatorView(),
        () => const SwpCalculatorView(),
        () => const FdCalculatorView(),
        () => const RdCalculatorView(),
        () => const GoalPlannerView(),
      ];
      for (final dark in <bool>[false, true]) {
        for (final w in <double>[360, 900]) {
          await size(tester, w, 1800);
          for (final b in builders) {
            await tester.pumpWidget(app(b(),
                theme: ThemeData(
                    brightness: dark ? Brightness.dark : Brightness.light)));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            for (final type in <String>['bar', 'line']) {
              await tester.tap(find.byKey(ValueKey<String>('chart-$type')));
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
            }
          }
        }
      }
    });

    testWidgets('chart switcher changes the chart', (tester) async {
      await size(tester, 420, 1600);
      await tester.pumpWidget(app(const SipCalculatorView(
        chartTypes: <CalculatorChartType>[
          CalculatorChartType.donut,
          CalculatorChartType.pie,
          CalculatorChartType.gauge,
          CalculatorChartType.bar,
          CalculatorChartType.line,
        ],
      )));
      await tester.pumpAndSettle();
      expect(find.byType(DonutChart), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey<String>('chart-gauge')));
      await tester.pumpAndSettle();
      expect(find.byType(GaugeChart), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey<String>('chart-bar')));
      await tester.pumpAndSettle();
      expect(find.byType(StackedBarChart), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey<String>('chart-line')));
      await tester.pumpAndSettle();
      expect(find.byType(LineAreaChart), findsOneWidget);
    });
  });

  group('customization without forking', () {
    testWidgets('theme: scope, ThemeData extension and view argument',
        (tester) async {
      await size(tester, 420, 1400);
      const mine = Color(0xFFD81B60);
      final t =
          const FinanceCalculatorTheme.light().copyWith(returnsColor: mine);
      Color headline(WidgetTester tester) => tester
          .widget<Text>(find.byKey(const ValueKey<String>('summary-headline')))
          .style!
          .color!;
      await tester.pumpWidget(app(SipCalculatorView(theme: t)));
      await tester.pumpAndSettle();
      expect(headline(tester), mine);
      await tester.pumpWidget(app(FinanceCalculatorThemeScope(
          theme: t, child: const SipCalculatorView())));
      await tester.pumpAndSettle();
      expect(headline(tester), mine);
      await tester.pumpWidget(app(const SipCalculatorView(),
          theme: ThemeData(extensions: <ThemeExtension<dynamic>>[t])));
      await tester.pumpAndSettle();
      expect(headline(tester), mine);
      // default derives from the ColorScheme
      await tester.pumpWidget(app(const SipCalculatorView(),
          theme: ThemeData(colorSchemeSeed: Colors.green)));
      await tester.pumpAndSettle();
      expect(headline(tester), isNot(mine));
    });

    testWidgets('builders replace input, summary, chart, breakdown',
        (tester) async {
      await size(tester, 420, 1600);
      CalculatorChartData? seen;
      CalculatorBreakdownData? seenTable;
      await tester.pumpWidget(app(SipCalculatorView(
        inputBuilder: (ctx, d) => Text('IN:${d.input.id}=${d.value}'),
        summaryBuilder: (ctx, d) => Text('SUM:${d.entries.length}'),
        chartBuilder: (ctx, d) {
          seen = d;
          return const Text('MY-CHART');
        },
        breakdownBuilder: (ctx, d) {
          seenTable = d;
          return Text('MY-TABLE:${d.rows.length}');
        },
      )));
      await tester.pumpAndSettle();
      expect(find.text('IN:monthly=10000.0'), findsOneWidget);
      expect(find.text('SUM:3'), findsOneWidget);
      expect(find.text('MY-CHART'), findsOneWidget);
      expect(find.text('MY-TABLE:10'), findsOneWidget);
      expect(seen!.bars.series, hasLength(2));
      expect(seen!.bars.labels, hasLength(10));
      expect(seen!.lines.first.values.last,
          closeTo(seen!.result.maturityValue, 1e-6));
      expect(seen!.slices.map((s) => s.label),
          <String>['Invested amount', 'Est. returns']);
      expect(seenTable!.monthly, isFalse);
      await tester.tap(find.byKey(const ValueKey<String>('monthly-switch')));
      await tester.pumpAndSettle();
      expect(find.text('MY-TABLE:120'), findsOneWidget);
    });

    testWidgets('format presets and valueFormatter hook', (tester) async {
      await size(tester, 420, 1400);
      await tester
          .pumpWidget(app(const SipCalculatorView(format: CurrencyFormat.usd)));
      await tester.pumpAndSettle();
      expect(find.textContaining(r'$1,200,000'), findsWidgets);
      await tester.pumpWidget(
          app(SipCalculatorView(valueFormatter: (v) => '<${v.round()}>')));
      await tester.pumpAndSettle();
      expect(find.text('<1200000>'), findsWidgets);
    });

    testWidgets('labels, input overrides and hidden inputs', (tester) async {
      await size(tester, 420, 1400);
      final c = SipCalculatorController(
        labels: const <String, String>{
          'title': 'Mi SIP',
          'invested': 'Invertido'
        },
        inputOverrides: <String, CalculatorInput>{
          'monthly': const CalculatorInput(
              id: 'monthly',
              label: 'Cuota mensual',
              min: 100,
              max: 1000,
              step: 100,
              initial: 500,
              kind: InputKind.currency),
        },
        showStepUp: false,
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(app(SipCalculatorView(controller: c)));
      await tester.pumpAndSettle();
      expect(find.text('Mi SIP'), findsOneWidget);
      expect(find.text('Cuota mensual'), findsOneWidget);
      expect(find.text('Invertido'), findsWidgets);
      expect(find.text('Annual step-up'), findsNothing);
      expect(c.value('monthly'), 500);
    });

    testWidgets('a view without a controller owns and disposes its own',
        (tester) async {
      await size(tester, 420, 1400);
      await tester.pumpWidget(app(const FdCalculatorView()));
      await tester.pumpAndSettle();
      await tester.pumpWidget(app(const SizedBox()));
      expect(tester.takeException(), isNull);
    });
  });

  group('performance', () {
    testWidgets('40-year monthly schedule computes and renders fast',
        (tester) async {
      await size(tester, 420, 2000);
      final c = SipCalculatorController(years: 40);
      addTearDown(c.dispose);
      final sw = Stopwatch()..start();
      await tester.pumpWidget(app(SipCalculatorView(controller: c)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('monthly-switch')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('chart-line')));
      await tester.pumpAndSettle();
      sw.stop();
      expect(c.result!.monthly, hasLength(480));
      expect(tester.takeException(), isNull);
      expect(sw.elapsedMilliseconds, lessThan(5000));
      // recomputation on a slider move stays far below a frame budget x 10
      final s2 = Stopwatch()..start();
      for (var i = 0; i < 20; i++) {
        c.setValue('monthly', 10000.0 + i * 500);
      }
      s2.stop();
      expect(s2.elapsedMilliseconds, lessThan(500));
    });
  });
}
