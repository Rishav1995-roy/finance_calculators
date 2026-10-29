import 'common.dart';
import 'result.dart';

List<BreakdownRow> _growthRows(double start, double annualFactor, int months) {
  final b = RowBuilder();
  final rows = <BreakdownRow>[];
  var prev = 0.0;
  for (var m = 1; m <= months; m++) {
    final v = start * pw(annualFactor, m / 12);
    final dep = m == 1 ? start : 0.0;
    rows.add(b.add(
      period: m,
      opening: prev,
      invested: dep,
      returns: v - prev - dep,
      withdrawn: 0,
      closing: v,
    ));
    prev = v;
  }
  return rows;
}

/// Result of [CagrCalculator.calculate].
class CagrResult extends CalculatorResult {
  /// Creates a result; normally obtained from [CagrCalculator.calculate].
  CagrResult(super.monthly,
      {required this.cagrPercent,
      required this.startValue,
      required this.endValue});

  /// Compound annual growth rate in percent.
  final double cagrPercent;

  /// Value at the start.
  final double startValue;

  /// Value at the end.
  final double endValue;

  /// Total gain as a percent of [startValue].
  double get absoluteReturnPercent => (endValue / startValue - 1) * 100;

  @override
  double get investedAmount => startValue;

  @override
  double get estimatedReturns => endValue - startValue;

  @override
  double get maturityValue => endValue;

  @override
  Map<String, Object?> toJson({bool includeMonthly = false}) =>
      <String, Object?>{
        ...super.toJson(includeMonthly: includeMonthly),
        'cagrPercent': cagrPercent,
        'absoluteReturnPercent': absoluteReturnPercent,
      };
}

/// Compound annual growth rate: `CAGR = (end / start)^(1/years) - 1`.
/// Excel equivalent: `=RRI(years, start, end)`.
class CagrCalculator {
  /// Creates a CAGR calculator.
  const CagrCalculator({
    required this.startValue,
    required this.endValue,
    required this.tenure,
  });

  /// Value at the start (must be positive).
  final double startValue;

  /// Value at the end (zero is allowed and gives -100%).
  final double endValue;

  /// Time between the two values.
  final Tenure tenure;

  /// The CAGR in percent, without building a breakdown.
  static double rate(double start, double end, double years) =>
      (pw(end / start, 1 / years) - 1) * 100;

  /// Validates the inputs and computes the result.
  CagrResult calculate() {
    requirePositive('startValue', startValue);
    requireNonNegative('endValue', endValue);
    requireTenure('tenure', tenure);
    final c = rate(startValue, endValue, tenure.inYears);
    return CagrResult(
      _growthRows(startValue, 1 + c / 100, tenure.totalMonths),
      cagrPercent: c,
      startValue: startValue,
      endValue: endValue,
    );
  }
}

/// Result of [InflationCalculator.calculate].
///
/// [investedAmount] is today's amount, [maturityValue] is what the same
/// purchasing power costs later and [estimatedReturns] the difference.
class InflationResult extends CalculatorResult {
  /// Creates a result; normally obtained from [InflationCalculator.calculate].
  InflationResult(super.monthly,
      {required this.amount,
      required this.futureCost,
      required this.realValue});

  /// The amount entered.
  final double amount;

  /// Cost in the future of what [amount] buys today.
  final double futureCost;

  /// What [amount] will be worth in today's money after the tenure.
  final double realValue;

  @override
  double get investedAmount => amount;

  @override
  double get estimatedReturns => futureCost - amount;

  @override
  double get maturityValue => futureCost;

  @override
  Map<String, Object?> toJson({bool includeMonthly = false}) =>
      <String, Object?>{
        ...super.toJson(includeMonthly: includeMonthly),
        'futureCost': futureCost,
        'realValue': realValue,
      };
}

/// Effect of inflation: `future = amount * (1 + inflation)^years` and the
/// inflation-adjusted (real) value `amount / (1 + inflation)^years`.
class InflationCalculator {
  /// Creates an inflation calculator.
  const InflationCalculator({
    required this.amount,
    required this.inflationPercent,
    required this.tenure,
  });

  /// Amount in today's money.
  final double amount;

  /// Yearly inflation in percent.
  final double inflationPercent;

  /// Time span.
  final Tenure tenure;

  /// Validates the inputs and computes the result.
  InflationResult calculate() {
    requirePositive('amount', amount);
    requireRate('inflationPercent', inflationPercent);
    requireTenure('tenure', tenure);
    final f = 1 + inflationPercent / 100;
    final y = tenure.inYears;
    return InflationResult(
      _growthRows(amount, f, tenure.totalMonths),
      amount: amount,
      futureCost: amount * pw(f, y),
      realValue: amount / pw(f, y),
    );
  }
}
