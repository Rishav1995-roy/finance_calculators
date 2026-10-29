import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../charts/chart_data.dart';
import '../core/common.dart';
import '../core/emi.dart';
import '../core/lumpsum.dart';
import '../core/planning.dart';
import '../core/result.dart';
import '../core/sip.dart';
import '../core/swp.dart';
import '../theme/calculator_theme.dart';

/// What an input measures, which decides how it is shown.
enum InputKind {
  /// Money: shown with the currency symbol.
  currency,

  /// A percentage: suffix `%`.
  percent,

  /// Whole years: suffix `Yr`.
  years,

  /// Plain number.
  number,
}

/// Definition of one slider + text field input.
@immutable
class CalculatorInput {
  /// Creates an input definition.
  const CalculatorInput({
    required this.id,
    required this.label,
    required this.min,
    required this.max,
    required this.step,
    required this.initial,
    this.kind = InputKind.number,
    this.decimals = 0,
    this.visible = true,
    this.helper,
  });

  /// Stable identifier (used by `inputOverrides` and the controller).
  final String id;

  /// Text above the slider (replace it to localize).
  final String label;

  /// Slider minimum.
  final double min;

  /// Slider maximum. The text field accepts larger values.
  final double max;

  /// Slider step.
  final double step;

  /// Starting value.
  final double initial;

  /// How the value is displayed.
  final InputKind kind;

  /// Decimal places shown in the text field.
  final int decimals;

  /// Hide the input (its value is still used).
  final bool visible;

  /// Optional helper text under the slider.
  final String? helper;

  /// A copy with some fields replaced.
  CalculatorInput copyWith({
    String? label,
    double? min,
    double? max,
    double? step,
    double? initial,
    InputKind? kind,
    int? decimals,
    bool? visible,
    String? helper,
  }) =>
      CalculatorInput(
        id: id,
        label: label ?? this.label,
        min: min ?? this.min,
        max: max ?? this.max,
        step: step ?? this.step,
        initial: initial ?? this.initial,
        kind: kind ?? this.kind,
        decimals: decimals ?? this.decimals,
        visible: visible ?? this.visible,
        helper: helper ?? this.helper,
      );
}

/// How a summary value is displayed.
enum SummaryKind {
  /// Money.
  currency,

  /// Percentage.
  percent,

  /// A number of months, shown as "3 yr 2 mo".
  months,

  /// Plain number.
  number,
}

/// One figure in the summary card.
@immutable
class SummaryEntry {
  /// Creates an entry.
  const SummaryEntry(this.id, this.label, this.value,
      {this.kind = SummaryKind.currency, this.color});

  /// Stable identifier.
  final String id;

  /// Caption.
  final String label;

  /// The number.
  final double value;

  /// How to format [value].
  final SummaryKind kind;

  /// Optional dot color shown next to the caption.
  final Color? color;
}

/// Which theme color a [SeriesSpec] uses by default.
enum SeriesRole {
  /// Invested money / principal.
  invested,

  /// Returns / interest.
  returns,

  /// Third color.
  accent,
}

/// One series of the bar and line charts, taken from a breakdown row.
@immutable
class SeriesSpec {
  /// Creates a series.
  const SeriesSpec(this.id, this.label, this.role, this.valueOf);

  /// Stable identifier.
  final String id;

  /// Legend text.
  final String label;

  /// Theme color slot.
  final SeriesRole role;

  /// Reads the plotted number from a row.
  final double Function(BreakdownRow row) valueOf;

  /// The theme color for [role].
  Color color(FinanceCalculatorTheme t) {
    switch (role) {
      case SeriesRole.invested:
        return t.investedColor;
      case SeriesRole.returns:
        return t.returnsColor;
      case SeriesRole.accent:
        return t.accentColor;
    }
  }
}

/// A column of the breakdown table.
@immutable
class BreakdownColumn {
  /// Creates a column.
  const BreakdownColumn(this.label, this.valueOf);

  /// Header text.
  final String label;

  /// Reads the shown number from a row.
  final double Function(BreakdownRow row) valueOf;
}

/// Holds the inputs of a calculator, recomputes on every change and exposes
/// everything a view needs. Extend it (or use the ready ones) to build any
/// calculator UI; listen to it like any [ChangeNotifier].
abstract class CalculatorController<R extends CalculatorResult>
    extends ChangeNotifier {
  /// Creates a controller from input definitions, applying [inputOverrides]
  /// (by input id) and [labels] (by label key, for localization).
  CalculatorController(
    List<CalculatorInput> defaults, {
    Map<String, CalculatorInput>? inputOverrides,
    Map<String, String>? labels,
  })  : inputs = List<CalculatorInput>.unmodifiable(<CalculatorInput>[
          for (final d in defaults) inputOverrides?[d.id] ?? d,
        ]),
        _labels = labels ?? const <String, String>{} {
    for (final i in inputs) {
      _values[i.id] = i.initial;
    }
    _recompute();
  }

  /// Input definitions in display order.
  final List<CalculatorInput> inputs;
  final Map<String, String> _labels;
  final Map<String, double> _values = <String, double>{};
  R? _result;
  String? _error;

  /// Caption for [key], or [fallback] unless overridden through `labels`.
  String label(String key, String fallback) => _labels[key] ?? fallback;

  /// Current value of input [id].
  double value(String id) => _values[id]!;

  /// Sets input [id] and recomputes.
  void setValue(String id, double v) {
    assert(_values.containsKey(id), 'unknown input $id');
    if (_values[id] == v) return;
    _values[id] = v;
    _recompute();
    notifyListeners();
  }

  /// Restores every input to its initial value.
  void reset() {
    for (final i in inputs) {
      _values[i.id] = i.initial;
    }
    _recompute();
    notifyListeners();
  }

  /// The latest valid result (null while the inputs are invalid).
  R? get result => _result;

  /// Message of the latest [InvalidInputException], or null.
  String? get error => _error;

  void _recompute() {
    try {
      _result = compute();
      _error = null;
    } on InvalidInputException catch (e) {
      _result = null;
      _error = '${e.field}: ${e.message}';
    }
  }

  /// Builds the result from [value]. May throw [InvalidInputException].
  @protected
  R compute();

  /// Title of the calculator.
  String get title;

  /// Headline figures for [r].
  List<SummaryEntry> summary(R r);

  /// Slices for the donut and pie charts.
  List<ChartSlice> slices(R r) => <ChartSlice>[
        ChartSlice(
            label: label('invested', 'Invested amount'),
            value: r.investedAmount),
        ChartSlice(
            label: label('returns', 'Est. returns'), value: r.estimatedReturns),
      ];

  /// Series of the stacked bar chart (one bar per year).
  List<SeriesSpec> get barSeries => <SeriesSpec>[
        SeriesSpec('invested', label('invested', 'Invested amount'),
            SeriesRole.invested, (r) => r.cumulativeInvested),
        SeriesSpec('returns', label('returns', 'Est. returns'),
            SeriesRole.returns, (r) => r.cumulativeReturns),
      ];

  /// Series of the line / area chart (one point per year).
  List<SeriesSpec> get lineSeries => <SeriesSpec>[
        SeriesSpec('value', label('value', 'Total value'), SeriesRole.returns,
            (r) => r.closingBalance),
        SeriesSpec('invested', label('invested', 'Invested amount'),
            SeriesRole.invested, (r) => r.cumulativeInvested),
      ];

  /// Columns of the breakdown table.
  List<BreakdownColumn> get breakdownColumns => <BreakdownColumn>[
        BreakdownColumn(label('invested', 'Invested'), (r) => r.invested),
        BreakdownColumn(label('returns', 'Returns'), (r) => r.returns),
        BreakdownColumn(label('balance', 'Balance'), (r) => r.closingBalance),
      ];

  /// Caption under the gauge value.
  String get gaugeLabel => label('gaugeLabel', 'Share of returns');

  /// Gauge value (0 to 1): the share of the final amount that is returns.
  double gaugeFraction(R r) => r.maturityValue > 0
      ? (r.estimatedReturns / r.maturityValue).clamp(0, 1)
      : 0;
}

List<SummaryEntry> _threeTotals(CalculatorController<CalculatorResult> c,
    CalculatorResult r, FinanceCalculatorTheme? _) {
  return <SummaryEntry>[
    SummaryEntry('total', c.label('total', 'Total value'), r.maturityValue),
    SummaryEntry(
        'invested', c.label('invested', 'Invested amount'), r.investedAmount),
    SummaryEntry(
        'returns', c.label('returns', 'Est. returns'), r.estimatedReturns),
  ];
}

/// Controller for [SipCalculator] (with optional yearly step-up).
class SipCalculatorController extends CalculatorController<SipResult> {
  /// Creates a SIP controller.
  SipCalculatorController({
    double monthlyInvestment = 10000,
    double annualReturnPercent = 12,
    int years = 10,
    double stepUpPercent = 0,
    this.timing = PaymentTiming.start,
    this.rateConvention = RateConvention.nominalMonthly,
    this.showStepUp = true,
    super.inputOverrides,
    super.labels,
  }) : super(<CalculatorInput>[
          CalculatorInput(
              id: 'monthly',
              label: 'Monthly investment',
              min: 500,
              max: 200000,
              step: 500,
              initial: monthlyInvestment,
              kind: InputKind.currency),
          CalculatorInput(
              id: 'rate',
              label: 'Expected return (p.a.)',
              min: 1,
              max: 30,
              step: 0.5,
              initial: annualReturnPercent,
              kind: InputKind.percent,
              decimals: 1),
          CalculatorInput(
              id: 'years',
              label: 'Time period',
              min: 1,
              max: 40,
              step: 1,
              initial: years.toDouble(),
              kind: InputKind.years),
          CalculatorInput(
              id: 'stepUp',
              label: 'Annual step-up',
              min: 0,
              max: 25,
              step: 1,
              initial: stepUpPercent,
              kind: InputKind.percent,
              visible: showStepUp),
        ]);

  /// Instalment timing.
  final PaymentTiming timing;

  /// Monthly rate convention.
  final RateConvention rateConvention;

  /// Show the step-up slider.
  final bool showStepUp;

  @override
  String get title => label('title', 'SIP calculator');

  @override
  SipResult compute() => SipCalculator(
        monthlyInvestment: value('monthly'),
        annualReturnPercent: value('rate'),
        tenure: Tenure.months((value('years') * 12).round()),
        stepUp: value('stepUp') > 0 ? StepUp.percent(value('stepUp')) : null,
        timing: timing,
        rateConvention: rateConvention,
      ).calculate();

  @override
  List<SummaryEntry> summary(SipResult r) => _threeTotals(this, r, null);
}

/// Controller for [LumpsumCalculator].
class LumpsumCalculatorController extends CalculatorController<LumpsumResult> {
  /// Creates a lumpsum controller.
  LumpsumCalculatorController({
    double amount = 500000,
    double annualReturnPercent = 12,
    int years = 10,
    this.compounding = Compounding.yearly,
    super.inputOverrides,
    super.labels,
  }) : super(<CalculatorInput>[
          CalculatorInput(
              id: 'amount',
              label: 'Total investment',
              min: 5000,
              max: 10000000,
              step: 5000,
              initial: amount,
              kind: InputKind.currency),
          CalculatorInput(
              id: 'rate',
              label: 'Expected return (p.a.)',
              min: 1,
              max: 30,
              step: 0.5,
              initial: annualReturnPercent,
              kind: InputKind.percent,
              decimals: 1),
          CalculatorInput(
              id: 'years',
              label: 'Time period',
              min: 1,
              max: 40,
              step: 1,
              initial: years.toDouble(),
              kind: InputKind.years),
        ]);

  /// Compounding frequency.
  final Compounding compounding;

  @override
  String get title => label('title', 'Lumpsum calculator');

  @override
  LumpsumResult compute() => LumpsumCalculator(
        amount: value('amount'),
        annualReturnPercent: value('rate'),
        tenure: Tenure.months((value('years') * 12).round()),
        compounding: compounding,
      ).calculate();

  @override
  List<SummaryEntry> summary(LumpsumResult r) => _threeTotals(this, r, null);
}

/// Controller for [FdCalculator].
class FdCalculatorController extends CalculatorController<LumpsumResult> {
  /// Creates a fixed deposit controller.
  FdCalculatorController({
    double deposit = 500000,
    double annualRatePercent = 7,
    int years = 5,
    this.compounding = Compounding.quarterly,
    super.inputOverrides,
    super.labels,
  }) : super(<CalculatorInput>[
          CalculatorInput(
              id: 'deposit',
              label: 'Deposit amount',
              min: 10000,
              max: 10000000,
              step: 10000,
              initial: deposit,
              kind: InputKind.currency),
          CalculatorInput(
              id: 'rate',
              label: 'Interest rate (p.a.)',
              min: 1,
              max: 15,
              step: 0.1,
              initial: annualRatePercent,
              kind: InputKind.percent,
              decimals: 1),
          CalculatorInput(
              id: 'years',
              label: 'Time period',
              min: 1,
              max: 20,
              step: 1,
              initial: years.toDouble(),
              kind: InputKind.years),
        ]);

  /// Compounding frequency.
  final Compounding compounding;

  @override
  String get title => label('title', 'FD calculator');

  @override
  LumpsumResult compute() => FdCalculator(
        deposit: value('deposit'),
        annualRatePercent: value('rate'),
        tenure: Tenure.months((value('years') * 12).round()),
        compounding: compounding,
      ).calculate();

  @override
  List<SummaryEntry> summary(LumpsumResult r) => <SummaryEntry>[
        SummaryEntry(
            'total', label('maturity', 'Maturity value'), r.maturityValue),
        SummaryEntry('invested', label('deposit', 'Deposit'), r.investedAmount),
        SummaryEntry('returns', label('interest', 'Interest earned'),
            r.estimatedReturns),
      ];

  @override
  List<ChartSlice> slices(LumpsumResult r) => <ChartSlice>[
        ChartSlice(label: label('deposit', 'Deposit'), value: r.investedAmount),
        ChartSlice(
            label: label('interest', 'Interest earned'),
            value: r.estimatedReturns),
      ];
}

/// Controller for [RdCalculator].
class RdCalculatorController extends CalculatorController<RdResult> {
  /// Creates a recurring deposit controller.
  RdCalculatorController({
    double monthlyDeposit = 5000,
    double annualRatePercent = 6.5,
    int years = 5,
    this.compounding = Compounding.quarterly,
    super.inputOverrides,
    super.labels,
  }) : super(<CalculatorInput>[
          CalculatorInput(
              id: 'monthly',
              label: 'Monthly deposit',
              min: 500,
              max: 100000,
              step: 500,
              initial: monthlyDeposit,
              kind: InputKind.currency),
          CalculatorInput(
              id: 'rate',
              label: 'Interest rate (p.a.)',
              min: 1,
              max: 15,
              step: 0.1,
              initial: annualRatePercent,
              kind: InputKind.percent,
              decimals: 1),
          CalculatorInput(
              id: 'years',
              label: 'Time period',
              min: 1,
              max: 10,
              step: 1,
              initial: years.toDouble(),
              kind: InputKind.years),
        ]);

  /// Compounding frequency.
  final Compounding compounding;

  @override
  String get title => label('title', 'RD calculator');

  @override
  RdResult compute() => RdCalculator(
        monthlyDeposit: value('monthly'),
        annualRatePercent: value('rate'),
        tenure: Tenure.months((value('years') * 12).round()),
        compounding: compounding,
      ).calculate();

  @override
  List<SummaryEntry> summary(RdResult r) => <SummaryEntry>[
        SummaryEntry(
            'total', label('maturity', 'Maturity value'), r.maturityValue),
        SummaryEntry('invested', label('deposited', 'Total deposited'),
            r.investedAmount),
        SummaryEntry('returns', label('interest', 'Interest earned'),
            r.estimatedReturns),
      ];
}

/// Controller for [EmiCalculator].
class EmiCalculatorController extends CalculatorController<EmiResult> {
  /// Creates a loan EMI controller.
  EmiCalculatorController({
    double loanAmount = 2500000,
    double annualRatePercent = 8.5,
    int years = 20,
    double extraMonthlyPayment = 0,
    this.roundingDecimals,
    this.showPrepayment = true,
    super.inputOverrides,
    super.labels,
  }) : super(<CalculatorInput>[
          CalculatorInput(
              id: 'principal',
              label: 'Loan amount',
              min: 100000,
              max: 20000000,
              step: 100000,
              initial: loanAmount,
              kind: InputKind.currency),
          CalculatorInput(
              id: 'rate',
              label: 'Interest rate (p.a.)',
              min: 1,
              max: 20,
              step: 0.05,
              initial: annualRatePercent,
              kind: InputKind.percent,
              decimals: 2),
          CalculatorInput(
              id: 'years',
              label: 'Loan tenure',
              min: 1,
              max: 30,
              step: 1,
              initial: years.toDouble(),
              kind: InputKind.years),
          CalculatorInput(
              id: 'extra',
              label: 'Extra payment each month',
              min: 0,
              max: 100000,
              step: 1000,
              initial: extraMonthlyPayment,
              kind: InputKind.currency,
              visible: showPrepayment),
        ]);

  /// Round EMI and interest like a bank statement (decimals), or null.
  final int? roundingDecimals;

  /// Show the extra monthly payment (prepayment) slider.
  final bool showPrepayment;

  @override
  String get title => label('title', 'EMI calculator');

  @override
  EmiResult compute() => EmiCalculator(
        principal: value('principal'),
        annualRatePercent: value('rate'),
        tenure: Tenure.months((value('years') * 12).round()),
        extraMonthlyPayment: value('extra'),
        roundingDecimals: roundingDecimals,
      ).calculate();

  @override
  List<SummaryEntry> summary(EmiResult r) => <SummaryEntry>[
        SummaryEntry('emi', label('emi', 'Monthly EMI'), r.emi),
        SummaryEntry(
            'principal', label('principal', 'Principal amount'), r.principal),
        SummaryEntry(
            'interest', label('interest', 'Total interest'), r.totalInterest),
        SummaryEntry(
            'total', label('payment', 'Total payment'), r.totalPayment),
        if (r.monthsSaved > 0) ...<SummaryEntry>[
          SummaryEntry('saved', label('timeSaved', 'Time saved'),
              r.monthsSaved.toDouble(),
              kind: SummaryKind.months),
          SummaryEntry('interestSaved',
              label('interestSaved', 'Interest saved'), r.interestSaved),
        ],
      ];

  @override
  List<ChartSlice> slices(EmiResult r) => <ChartSlice>[
        ChartSlice(
            label: label('principal', 'Principal amount'), value: r.principal),
        ChartSlice(
            label: label('interest', 'Total interest'), value: r.totalInterest),
      ];

  @override
  List<SeriesSpec> get barSeries => <SeriesSpec>[
        SeriesSpec('principal', label('principal', 'Principal paid'),
            SeriesRole.invested, (r) => r.invested),
        SeriesSpec('interest', label('interest', 'Interest paid'),
            SeriesRole.returns, (r) => r.returns),
      ];

  @override
  List<SeriesSpec> get lineSeries => <SeriesSpec>[
        SeriesSpec('balance', label('balance', 'Outstanding balance'),
            SeriesRole.returns, (r) => r.closingBalance),
        SeriesSpec('interest', label('interestPaid', 'Interest paid so far'),
            SeriesRole.accent, (r) => r.cumulativeReturns),
      ];

  @override
  List<BreakdownColumn> get breakdownColumns => <BreakdownColumn>[
        BreakdownColumn(label('principal', 'Principal'), (r) => r.invested),
        BreakdownColumn(label('interest', 'Interest'), (r) => r.returns),
        BreakdownColumn(label('balance', 'Balance'), (r) => r.closingBalance),
      ];

  @override
  String get gaugeLabel => label('gaugeLabel', 'Interest share');

  @override
  double gaugeFraction(EmiResult r) =>
      r.totalPayment > 0 ? (r.totalInterest / r.totalPayment).clamp(0, 1) : 0;
}

/// Controller for [SwpCalculator].
class SwpCalculatorController extends CalculatorController<SwpResult> {
  /// Creates a SWP controller.
  SwpCalculatorController({
    double corpus = 5000000,
    double monthlyWithdrawal = 30000,
    double annualReturnPercent = 9,
    int years = 15,
    double withdrawalIncreasePercent = 0,
    super.inputOverrides,
    super.labels,
  }) : super(<CalculatorInput>[
          CalculatorInput(
              id: 'corpus',
              label: 'Total investment',
              min: 100000,
              max: 50000000,
              step: 100000,
              initial: corpus,
              kind: InputKind.currency),
          CalculatorInput(
              id: 'withdrawal',
              label: 'Monthly withdrawal',
              min: 1000,
              max: 500000,
              step: 1000,
              initial: monthlyWithdrawal,
              kind: InputKind.currency),
          CalculatorInput(
              id: 'rate',
              label: 'Expected return (p.a.)',
              min: 1,
              max: 20,
              step: 0.5,
              initial: annualReturnPercent,
              kind: InputKind.percent,
              decimals: 1),
          CalculatorInput(
              id: 'years',
              label: 'Time period',
              min: 1,
              max: 40,
              step: 1,
              initial: years.toDouble(),
              kind: InputKind.years),
          CalculatorInput(
              id: 'increase',
              label: 'Yearly withdrawal increase',
              min: 0,
              max: 15,
              step: 1,
              initial: withdrawalIncreasePercent,
              kind: InputKind.percent),
        ]);

  @override
  String get title => label('title', 'SWP calculator');

  @override
  SwpResult compute() => SwpCalculator(
        initialCorpus: value('corpus'),
        monthlyWithdrawal: value('withdrawal'),
        annualReturnPercent: value('rate'),
        tenure: Tenure.months((value('years') * 12).round()),
        annualWithdrawalIncreasePercent: value('increase'),
      ).calculate();

  @override
  List<SummaryEntry> summary(SwpResult r) => <SummaryEntry>[
        SummaryEntry('invested', label('invested', 'Total investment'),
            r.investedAmount),
        SummaryEntry('withdrawn', label('withdrawn', 'Total withdrawal'),
            r.totalWithdrawn),
        SummaryEntry('final', label('final', 'Final value'), r.finalBalance),
        if (r.depletionMonth != null)
          SummaryEntry('depleted', label('depleted', 'Money lasts'),
              r.depletionMonth!.toDouble(),
              kind: SummaryKind.months),
      ];

  @override
  List<ChartSlice> slices(SwpResult r) => <ChartSlice>[
        ChartSlice(
            label: label('withdrawn', 'Total withdrawal'),
            value: r.totalWithdrawn),
        ChartSlice(label: label('final', 'Final value'), value: r.finalBalance),
      ];

  @override
  List<SeriesSpec> get barSeries => <SeriesSpec>[
        SeriesSpec('withdrawn', label('withdrawn', 'Withdrawn so far'),
            SeriesRole.invested, (r) => r.cumulativeWithdrawn),
        SeriesSpec('balance', label('balance', 'Remaining balance'),
            SeriesRole.returns, (r) => r.closingBalance),
      ];

  @override
  List<SeriesSpec> get lineSeries => <SeriesSpec>[
        SeriesSpec('balance', label('balance', 'Remaining balance'),
            SeriesRole.returns, (r) => r.closingBalance),
        SeriesSpec('withdrawn', label('withdrawn', 'Withdrawn so far'),
            SeriesRole.accent, (r) => r.cumulativeWithdrawn),
      ];

  @override
  List<BreakdownColumn> get breakdownColumns => <BreakdownColumn>[
        BreakdownColumn(label('withdrawn', 'Withdrawn'), (r) => r.withdrawn),
        BreakdownColumn(label('returns', 'Returns'), (r) => r.returns),
        BreakdownColumn(label('balance', 'Balance'), (r) => r.closingBalance),
      ];

  @override
  String get gaugeLabel => label('gaugeLabel', 'Corpus left');

  @override
  double gaugeFraction(SwpResult r) => r.investedAmount > 0
      ? (r.finalBalance / r.investedAmount).clamp(0, 1)
      : 0;
}

/// Controller for [GoalPlanner].
class GoalPlannerController extends CalculatorController<GoalPlanResult> {
  /// Creates a goal planner controller.
  GoalPlannerController({
    double targetAmount = 10000000,
    double annualReturnPercent = 12,
    int years = 15,
    double inflationPercent = 6,
    double existingSavings = 0,
    this.targetInTodaysMoney = true,
    super.inputOverrides,
    super.labels,
  }) : super(<CalculatorInput>[
          CalculatorInput(
              id: 'target',
              label: 'Goal amount',
              min: 100000,
              max: 100000000,
              step: 100000,
              initial: targetAmount,
              kind: InputKind.currency),
          CalculatorInput(
              id: 'years',
              label: 'Years to goal',
              min: 1,
              max: 40,
              step: 1,
              initial: years.toDouble(),
              kind: InputKind.years),
          CalculatorInput(
              id: 'rate',
              label: 'Expected return (p.a.)',
              min: 1,
              max: 30,
              step: 0.5,
              initial: annualReturnPercent,
              kind: InputKind.percent,
              decimals: 1),
          CalculatorInput(
              id: 'inflation',
              label: 'Inflation (p.a.)',
              min: 0,
              max: 15,
              step: 0.5,
              initial: inflationPercent,
              kind: InputKind.percent,
              decimals: 1),
          CalculatorInput(
              id: 'existing',
              label: 'Already saved',
              min: 0,
              max: 10000000,
              step: 50000,
              initial: existingSavings,
              kind: InputKind.currency),
        ]);

  /// Treat the goal as today's money and inflate it.
  final bool targetInTodaysMoney;

  @override
  String get title => label('title', 'Goal planner');

  @override
  GoalPlanResult compute() => GoalPlanner(
        targetAmount: value('target'),
        tenure: Tenure.months((value('years') * 12).round()),
        annualReturnPercent: value('rate'),
        inflationPercent: value('inflation'),
        existingSavings: value('existing'),
        targetInTodaysMoney: targetInTodaysMoney,
      ).calculate();

  @override
  List<SummaryEntry> summary(GoalPlanResult r) => <SummaryEntry>[
        SummaryEntry(
            'sip', label('sip', 'Monthly SIP needed'), r.requiredMonthlySip),
        SummaryEntry(
            'lump', label('lump', 'Or one-time investment'), r.requiredLumpsum),
        SummaryEntry('target', label('inflatedTarget', 'Goal in future money'),
            r.inflatedTarget),
        SummaryEntry('invested', label('invested', 'Total you invest'),
            r.investedAmount),
        SummaryEntry(
            'returns', label('returns', 'Est. returns'), r.estimatedReturns),
      ];
}
