import 'common.dart';
import 'result.dart';

List<BreakdownRow> _compoundRows(
    double principal, double ratePercent, Compounding c, int months) {
  final b = RowBuilder();
  final rows = <BreakdownRow>[];
  var prev = 0.0;
  for (var m = 1; m <= months; m++) {
    final value = principal * compoundFactor(ratePercent, c, m.toDouble());
    final dep = m == 1 ? principal : 0.0;
    rows.add(b.add(
      period: m,
      opening: prev,
      invested: dep,
      returns: value - prev - dep,
      withdrawn: 0,
      closing: value,
    ));
    prev = value;
  }
  return rows;
}

/// Result of [LumpsumCalculator.calculate] and [FdCalculator.calculate].
class LumpsumResult extends CalculatorResult {
  /// Creates a result from monthly rows.
  LumpsumResult(super.monthly, {required this.effectiveAnnualYieldPercent});

  /// Yearly yield after compounding, in percent (a 6% rate compounded
  /// quarterly yields about 6.136%).
  final double effectiveAnnualYieldPercent;

  @override
  double get investedAmount => monthly.last.cumulativeInvested;

  @override
  double get estimatedReturns => monthly.last.cumulativeReturns;

  @override
  double get maturityValue => monthly.last.closingBalance;

  @override
  Map<String, Object?> toJson({bool includeMonthly = false}) =>
      <String, Object?>{
        ...super.toJson(includeMonthly: includeMonthly),
        'effectiveAnnualYieldPercent': effectiveAnnualYieldPercent,
      };
}

/// One-time investment.
///
/// `A = P * (1 + r/f)^(f * t)` for `f` compounding periods a year and `t`
/// years (`t` may be fractional, so 18 months is `t = 1.5`);
/// simple interest is `A = P * (1 + r * t)`. Excel: `=FV(r/f, f*t, 0, -P)`.
class LumpsumCalculator {
  /// Creates a lumpsum calculator.
  const LumpsumCalculator({
    required this.amount,
    required this.annualReturnPercent,
    required this.tenure,
    this.compounding = Compounding.yearly,
  });

  /// Amount invested at the start.
  final double amount;

  /// Expected annual return in percent.
  final double annualReturnPercent;

  /// Investment length.
  final Tenure tenure;

  /// Compounding frequency. Defaults to once a year.
  final Compounding compounding;

  /// Validates the inputs and computes the result.
  LumpsumResult calculate() {
    requirePositive('amount', amount);
    requireRate('annualReturnPercent', annualReturnPercent);
    requireTenure('tenure', tenure);
    return LumpsumResult(
      _compoundRows(
          amount, annualReturnPercent, compounding, tenure.totalMonths),
      effectiveAnnualYieldPercent:
          (compoundFactor(annualReturnPercent, compounding, 12) - 1) * 100,
    );
  }
}

/// Fixed deposit (cumulative): a lumpsum with a bank compounding convention.
///
/// Same maths as [LumpsumCalculator]; defaults to quarterly compounding.
class FdCalculator {
  /// Creates a fixed deposit calculator.
  const FdCalculator({
    required this.deposit,
    required this.annualRatePercent,
    required this.tenure,
    this.compounding = Compounding.quarterly,
  });

  /// Deposit amount.
  final double deposit;

  /// Annual interest rate in percent.
  final double annualRatePercent;

  /// Deposit length.
  final Tenure tenure;

  /// Compounding frequency.
  final Compounding compounding;

  /// Validates the inputs and computes the result.
  LumpsumResult calculate() {
    requirePositive('deposit', deposit);
    requireRate('annualRatePercent', annualRatePercent);
    requireTenure('tenure', tenure);
    return LumpsumResult(
      _compoundRows(
          deposit, annualRatePercent, compounding, tenure.totalMonths),
      effectiveAnnualYieldPercent:
          (compoundFactor(annualRatePercent, compounding, 12) - 1) * 100,
    );
  }
}
