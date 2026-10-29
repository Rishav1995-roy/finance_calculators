import '../core/emi.dart';
import '../core/lumpsum.dart';
import '../core/planning.dart';
import '../core/sip.dart';
import '../core/swp.dart';
import 'calculator_view.dart';
import 'controllers.dart';

// Ready calculators. Each one is a CalculatorView with a default controller;
// pass your own controller to read or drive the inputs, and use the same
// builders / theme arguments to customize every part.

/// Ready SIP (with optional step-up) calculator. See [CalculatorView] for every option.
class SipCalculatorView extends CalculatorView<SipResult> {
  /// Creates the view; pass [controller] to own the state yourself.
  const SipCalculatorView({
    super.key,
    super.controller,
    super.theme,
    super.format,
    super.valueFormatter,
    super.title,
    super.chartTypes,
    super.initialChartType,
    super.showChartSwitcher,
    super.showBreakdown,
    super.allowMonthlyBreakdown,
    super.inputBuilder,
    super.summaryBuilder,
    super.chartBuilder,
    super.breakdownBuilder,
    super.errorBuilder,
    super.chartTypeLabels,
    super.padding,
    super.scrollable,
    super.onResultChanged,
  }) : super(createController: _create);

  static SipCalculatorController _create() => SipCalculatorController();
}

/// Ready lumpsum investment calculator. See [CalculatorView] for every option.
class LumpsumCalculatorView extends CalculatorView<LumpsumResult> {
  /// Creates the view; pass [controller] to own the state yourself.
  const LumpsumCalculatorView({
    super.key,
    super.controller,
    super.theme,
    super.format,
    super.valueFormatter,
    super.title,
    super.chartTypes,
    super.initialChartType,
    super.showChartSwitcher,
    super.showBreakdown,
    super.allowMonthlyBreakdown,
    super.inputBuilder,
    super.summaryBuilder,
    super.chartBuilder,
    super.breakdownBuilder,
    super.errorBuilder,
    super.chartTypeLabels,
    super.padding,
    super.scrollable,
    super.onResultChanged,
  }) : super(createController: _create);

  static LumpsumCalculatorController _create() => LumpsumCalculatorController();
}

/// Ready loan EMI with amortization and prepayment calculator. See [CalculatorView] for every option.
class EmiCalculatorView extends CalculatorView<EmiResult> {
  /// Creates the view; pass [controller] to own the state yourself.
  const EmiCalculatorView({
    super.key,
    super.controller,
    super.theme,
    super.format,
    super.valueFormatter,
    super.title,
    super.chartTypes,
    super.initialChartType,
    super.showChartSwitcher,
    super.showBreakdown,
    super.allowMonthlyBreakdown,
    super.inputBuilder,
    super.summaryBuilder,
    super.chartBuilder,
    super.breakdownBuilder,
    super.errorBuilder,
    super.chartTypeLabels,
    super.padding,
    super.scrollable,
    super.onResultChanged,
  }) : super(createController: _create);

  static EmiCalculatorController _create() => EmiCalculatorController();
}

/// Ready systematic withdrawal plan calculator. See [CalculatorView] for every option.
class SwpCalculatorView extends CalculatorView<SwpResult> {
  /// Creates the view; pass [controller] to own the state yourself.
  const SwpCalculatorView({
    super.key,
    super.controller,
    super.theme,
    super.format,
    super.valueFormatter,
    super.title,
    super.chartTypes,
    super.initialChartType,
    super.showChartSwitcher,
    super.showBreakdown,
    super.allowMonthlyBreakdown,
    super.inputBuilder,
    super.summaryBuilder,
    super.chartBuilder,
    super.breakdownBuilder,
    super.errorBuilder,
    super.chartTypeLabels,
    super.padding,
    super.scrollable,
    super.onResultChanged,
  }) : super(createController: _create);

  static SwpCalculatorController _create() => SwpCalculatorController();
}

/// Ready fixed deposit calculator. See [CalculatorView] for every option.
class FdCalculatorView extends CalculatorView<LumpsumResult> {
  /// Creates the view; pass [controller] to own the state yourself.
  const FdCalculatorView({
    super.key,
    super.controller,
    super.theme,
    super.format,
    super.valueFormatter,
    super.title,
    super.chartTypes,
    super.initialChartType,
    super.showChartSwitcher,
    super.showBreakdown,
    super.allowMonthlyBreakdown,
    super.inputBuilder,
    super.summaryBuilder,
    super.chartBuilder,
    super.breakdownBuilder,
    super.errorBuilder,
    super.chartTypeLabels,
    super.padding,
    super.scrollable,
    super.onResultChanged,
  }) : super(createController: _create);

  static FdCalculatorController _create() => FdCalculatorController();
}

/// Ready recurring deposit calculator. See [CalculatorView] for every option.
class RdCalculatorView extends CalculatorView<RdResult> {
  /// Creates the view; pass [controller] to own the state yourself.
  const RdCalculatorView({
    super.key,
    super.controller,
    super.theme,
    super.format,
    super.valueFormatter,
    super.title,
    super.chartTypes,
    super.initialChartType,
    super.showChartSwitcher,
    super.showBreakdown,
    super.allowMonthlyBreakdown,
    super.inputBuilder,
    super.summaryBuilder,
    super.chartBuilder,
    super.breakdownBuilder,
    super.errorBuilder,
    super.chartTypeLabels,
    super.padding,
    super.scrollable,
    super.onResultChanged,
  }) : super(createController: _create);

  static RdCalculatorController _create() => RdCalculatorController();
}

/// Ready goal planner (SIP or lumpsum needed for a target) calculator. See [CalculatorView] for every option.
class GoalPlannerView extends CalculatorView<GoalPlanResult> {
  /// Creates the view; pass [controller] to own the state yourself.
  const GoalPlannerView({
    super.key,
    super.controller,
    super.theme,
    super.format,
    super.valueFormatter,
    super.title,
    super.chartTypes,
    super.initialChartType,
    super.showChartSwitcher,
    super.showBreakdown,
    super.allowMonthlyBreakdown,
    super.inputBuilder,
    super.summaryBuilder,
    super.chartBuilder,
    super.breakdownBuilder,
    super.errorBuilder,
    super.chartTypeLabels,
    super.padding,
    super.scrollable,
    super.onResultChanged,
  }) : super(createController: _create);

  static GoalPlannerController _create() => GoalPlannerController();
}
