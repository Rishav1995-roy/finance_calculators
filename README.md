# finance_calculators

[![pub version](https://img.shields.io/pub/v/finance_calculators.svg)](https://pub.dev/packages/finance_calculators)
[![pub points](https://img.shields.io/pub/points/finance_calculators)](https://pub.dev/packages/finance_calculators/score)
[![likes](https://img.shields.io/pub/likes/finance_calculators)](https://pub.dev/packages/finance_calculators)
[![popularity](https://img.shields.io/pub/popularity/finance_calculators)](https://pub.dev/packages/finance_calculators/score)
[![CI](https://github.com/Rishav1995-roy/finance_calculators/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/Rishav1995-roy/finance_calculators/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
![Platforms](https://img.shields.io/badge/platforms-android%20%7C%20ios%20%7C%20web%20%7C%20macos%20%7C%20windows%20%7C%20linux-informational)

SIP, step-up SIP, lumpsum, EMI (with amortization and prepayments), SWP, FD, RD, goal planner, CAGR, inflation and retirement calculators: an **accurate, tested calculation core** plus **ready, fully customizable Flutter views** with sliders, summary cards, breakdown tables and animated charts (donut, pie, gauge, stacked bar, line / area) drawn in the package with `CustomPainter`. No chart library, no other dependency.

![Demo](https://raw.githubusercontent.com/Rishav1995-roy/finance_calculators/main/doc/demo.gif)

<p>
  <img src="https://raw.githubusercontent.com/Rishav1995-roy/finance_calculators/main/doc/screenshot_light.png" width="260" alt="EMI calculator, light">
  <img src="https://raw.githubusercontent.com/Rishav1995-roy/finance_calculators/main/doc/screenshot_dark.png" width="260" alt="SIP calculator with bars, dark">
</p>

> The GIF and screenshots are rendered by a Flutter test from the real example UI (see `tool/demo`), not recorded on a device.

> **Disclaimer.** Results are estimates for information only. They are not financial, investment, tax or legal advice, and real products differ (fees, taxes, rate changes, day counts, rounding). Check with your provider or a qualified adviser before deciding.

## Why this package

Existing calculator packages on pub.dev (checked 2026-10-30), for example [`calcfy_calculators`](https://pub.dev/packages/calcfy_calculators), [`smart_math`](https://pub.dev/packages/smart_math), [`emi_calculator`](https://pub.dev/packages/emi_calculator) and [`compound_interest_calculator`](https://pub.dev/packages/compound_interest_calculator), provide formulas only: you still build sliders, inputs, summary, charts and tables yourself.

| | Formula-only packages | `finance_calculators` |
|---|---|---|
| Calculations | Yes (varying coverage) | SIP, step-up SIP, lumpsum, SWP, EMI + schedule + prepayment, FD, RD, goal, CAGR, inflation, retirement |
| Ready UI | No | 7 calculator views, controllers, breakdown tables |
| Charts | No | Donut, pie, gauge, stacked bar, line / area, animated, tappable |
| Customization | n/a | Theme extension (light / dark), every part replaceable with a builder, plug in `fl_chart` with the same data |
| Conventions documented | Rarely | Annuity-due vs ordinary, monthly rate convention, compounding: all configurable and documented |
| Verified numbers | n/a | Tests compare with independent closed-form / Excel `FV`, `PMT`, `RRI` equivalents |
| Currency formats | Plain numbers | INR lakh / crore, USD, EUR, custom hook, no `intl` |

## Features

- Pure calculation classes with immutable results: `investedAmount`, `estimatedReturns`, `maturityValue`, `monthly` and `yearly` breakdown, `toJson()`.
- Clear `InvalidInputException(field, message)` for bad input.
- Views: `SipCalculatorView`, `EmiCalculatorView`, `LumpsumCalculatorView`, `GoalPlannerView`, `SwpCalculatorView`, `FdCalculatorView`, `RdCalculatorView`, and the generic `CalculatorView` for your own controller.
- Slider and text input for each field; the text field accepts values beyond the slider range.
- Chart switcher (donut, pie, gauge, bar, line) and a yearly / monthly breakdown table (lazy rows, fast for 40-year schedules).
- `FinanceCalculatorTheme`: colors, text styles, radius, stroke, donut hole, animation duration and curve. Scope it, register it in `ThemeData.extensions` or pass it to one view; otherwise it derives from your `ColorScheme`.
- Responsive: two columns on wide screens, one column on phones.
- Accessibility: charts have semantic labels.

## Install

```yaml
dependencies:
  finance_calculators: ^0.0.1
```

## Quick start

```dart
import 'package:finance_calculators/finance_calculators.dart';

// A ready screen.
const SipCalculatorView();

// Rupees are the default; use dollars:
const EmiCalculatorView(format: CurrencyFormat.usd);

// Numbers only, no widgets:
final r = const SipCalculator(
  monthlyInvestment: 10000,
  annualReturnPercent: 12,
  tenure: Tenure.years(10),
).calculate();
print(r.maturityValue);   // 2323391.0 (annuity-due)
print(r.yearly.first.toJson());
```

## Calculators and formulas

All formulas are standard public finance maths. `i` = monthly rate, `n` = months.

| Calculator | Class | Formula |
|---|---|---|
| SIP | `SipCalculator` | Ordinary annuity `FV = P * ((1+i)^n - 1) / i`; annuity-due (default, `PaymentTiming.start`) multiplies by `(1+i)`. `i = annual / 12` (`RateConvention.nominalMonthly`, default) or `(1+annual)^(1/12) - 1` (`effectiveAnnual`). Excel `=FV(i, n, -P, 0, type)` |
| Step-up SIP | `SipCalculator(stepUp: ...)` | Instalment of year `k`: `P * (1+g)^k` (`StepUp.percent`) or `P + k*s` (`StepUp.fixed`) |
| Lumpsum | `LumpsumCalculator` | `A = P * (1 + r/f)^(f*t)`, `t` may be fractional; simple interest `P * (1 + r*t)` |
| SWP | `SwpCalculator` | `B_k = B_{k-1}*(1+i) - W`; closed form `B_n = C*(1+i)^n - W*((1+i)^n - 1)/i`; depletion month reported; optional yearly withdrawal increase |
| EMI | `EmiCalculator` | `EMI = P*i*(1+i)^n / ((1+i)^n - 1)` (Excel `-PMT`); schedule `interest = balance * i`; one-time and monthly prepayments; optional bank-style rounding |
| FD | `FdCalculator` | Lumpsum with quarterly compounding by default |
| RD | `RdCalculator` | `M = sum_k D*(1+r/f)^(f*(n-k+1)/12)`, deposits at the start of each month |
| Goal | `GoalPlanner` | `SIP = (T - S*(1+i)^n) / FV(1)`, lumpsum `T/(1+i)^n - S`, `T = target*(1+inflation)^years` |
| CAGR | `CagrCalculator` | `(end/start)^(1/years) - 1` (Excel `RRI`) |
| Inflation | `InflationCalculator` | `amount*(1+inf)^years`, real value `amount/(1+inf)^years` |
| Retirement | `RetirementCalculator` | Expense inflated to retirement; corpus = present value of inflating monthly spending at the post-retirement rate; SIP as in the goal planner |

Rates are percent per year (0 to 100), tenure is 1 to 1200 months (`Tenure.years`, `.months`, `.yearsAndMonths`).

## Customization

```dart
// 1. Theme (also works through ThemeData(extensions: [...]) or
//    FinanceCalculatorThemeScope).
SipCalculatorView(
  theme: const FinanceCalculatorTheme.light().copyWith(
    returnsColor: Colors.deepOrange,
    cardRadius: 28,
    animationDuration: const Duration(milliseconds: 900),
  ),
)

// 2. Replace any part.
SipCalculatorView(
  summaryBuilder: (context, d) => Text(d.formatEntry(d.entries.first)),
  inputBuilder: (context, d) => MySlider(d.input, d.value, d.onChanged),
  breakdownBuilder: (context, d) => d.defaultTable,
  errorBuilder: (context, message) => Text(message),
)

// 3. Plug in any chart library: you get the data, we keep the layout.
SipCalculatorView(
  chartBuilder: (context, d) => MyFlChart(bars: d.bars, lines: d.lines, slices: d.slices),
)

// 4. Own the state.
final controller = SipCalculatorController(monthlyInvestment: 25000, showStepUp: false);
controller.addListener(() => print(controller.result?.maturityValue));
SipCalculatorView(controller: controller)

// 5. Localize / retune inputs.
SipCalculatorController(
  labels: {'title': 'Mi SIP', 'invested': 'Invertido'},
  inputOverrides: {
    'monthly': const CalculatorInput(id: 'monthly', label: 'Cuota mensual',
        min: 100, max: 5000, step: 100, initial: 500, kind: InputKind.currency),
  },
)

// 6. Formatting.
SipCalculatorView(format: CurrencyFormat.eurEuropean)            // 1.234.567 EUR
SipCalculatorView(valueFormatter: (v) => 'USD ${v.toStringAsFixed(0)}')
```

### Charts on their own

```dart
DonutChart(slices: [ChartSlice(label: 'Invested', value: 6e5), ChartSlice(label: 'Returns', value: 4e5)],
    centerLabel: 'Total', centerValue: '10 L');
StackedBarChart(data: StackedBarData(labels: ['Y1', 'Y2'], series: [
  BarSeries(label: 'Invested', values: [1, 2]), BarSeries(label: 'Returns', values: [0.1, 0.4])]));
LineAreaChart(series: [LineSeries(label: 'Value', values: [1, 2, 4])], xLabels: ['1', '2', '3']);
GaugeChart(value: 42, label: 'Share of returns');
```

All charts sanitize their data (zeros, NaN, infinity, single points, 1e18 values) and animate between updates; `animate: false` or a zero theme duration turns animation off.

## Public API summary

| Area | Names |
|---|---|
| Core | `SipCalculator`, `StepUp`, `LumpsumCalculator`, `FdCalculator`, `RdCalculator`, `SwpCalculator`, `EmiCalculator`, `Prepayment`, `GoalPlanner`, `RetirementCalculator`, `CagrCalculator`, `InflationCalculator`, `Tenure`, `Compounding`, `PaymentTiming`, `RateConvention`, `BreakdownRow`, `CalculatorResult`, `InvalidInputException` |
| Views | `CalculatorView`, `SipCalculatorView` ... `GoalPlannerView`, `CalculatorController` + ready controllers, `CalculatorInputTile`, `BreakdownTable` |
| Charts | `DonutChart`, `PieChart`, `GaugeChart`, `StackedBarChart`, `LineAreaChart`, `ChartLegend`, `ChartSlice`, `StackedBarData`, `LineSeries` |
| Theme / format | `FinanceCalculatorTheme`, `FinanceCalculatorThemeScope`, `CurrencyFormat` |

`import 'package:finance_calculators/finance_calculators_core.dart';` exposes only the calculation classes (no widgets).

## Platform support

| Android | iOS | Web | macOS | Windows | Linux |
|---|---|---|---|---|---|
| Yes | Yes | Yes | Yes | Yes | Yes |

Pure Dart and Flutter, no native code. Note: the package depends on the Flutter SDK, so it cannot be used from a Dart-only server project today (see "Proposed changes" idea of a separate core package).

## FAQ

**Why is my SIP result different from another site?** Sites differ on annuity-due vs ordinary, `annual/12` vs effective monthly rate, and rounding. Set `timing` and `rateConvention` to match.

**Can I use my own sliders or charts?** Yes: `inputBuilder`, `chartBuilder`, `summaryBuilder`, `breakdownBuilder`.

**Taxes, fees, exit load?** Not modelled. Subtract them yourself or open a feature request.

## Contributing

Issues and pull requests are welcome. Run `flutter analyze --fatal-infos` and `flutter test` before opening a PR. Regenerate the demo with `flutter test --tags demo tool/demo/generate_demo_test.dart` then `tool/make_gif.sh` (needs `ffmpeg`).

## License

MIT, see [LICENSE](LICENSE).
