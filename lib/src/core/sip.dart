import 'common.dart';
import 'result.dart';

/// How a SIP instalment grows once a year.
///
/// The instalment of year `k` (0-based) is `P * (1 + pct/100)^k` for
/// [StepUp.percent] and `P + inc * k` for [StepUp.fixed].
class StepUp {
  /// Increase the monthly amount by [percent] percent each year.
  const StepUp.percent(this.percent) : amount = 0;

  /// Increase the monthly amount by a fixed [amount] each year.
  const StepUp.fixed(this.amount) : percent = 0;

  /// Yearly percentage increase (0 for a fixed step-up).
  final double percent;

  /// Yearly fixed increase (0 for a percentage step-up).
  final double amount;

  /// Instalment for 0-based [year].
  double instalment(double base, int year) => percent != 0
      ? base * pw(1 + percent / 100, year.toDouble())
      : base + amount * year;
}

/// Runs a month-by-month contribution schedule. Shared by SIP, RD, goal and
/// retirement planning.
List<BreakdownRow> simulateContributions({
  required double monthlyRate,
  required int months,
  required double Function(int month) contribution,
  required PaymentTiming timing,
  double initial = 0,
}) {
  final rows = <BreakdownRow>[];
  final b = RowBuilder();
  var bal = 0.0;
  for (var m = 0; m < months; m++) {
    final opening = bal;
    final base = m == 0 ? opening + initial : opening;
    final c = contribution(m);
    final interest = timing == PaymentTiming.start
        ? (base + c) * monthlyRate
        : base * monthlyRate;
    bal = base + c + interest;
    rows.add(b.add(
      period: m + 1,
      opening: opening,
      invested: c + (m == 0 ? initial : 0),
      returns: interest,
      withdrawn: 0,
      closing: bal,
    ));
  }
  return rows;
}

/// Result of [SipCalculator.calculate].
class SipResult extends CalculatorResult {
  /// Creates a result; normally obtained from [SipCalculator.calculate].
  SipResult(super.monthly, {required this.lastMonthlyInvestment});

  /// Instalment paid in the final month (differs from the first with a
  /// step-up).
  final double lastMonthlyInvestment;

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
        'lastMonthlyInvestment': lastMonthlyInvestment,
      };
}

/// Systematic Investment Plan, with an optional yearly step-up.
///
/// Formula (public, standard annuity maths) with monthly rate `i` and `n`
/// instalments of `P`:
///
/// * ordinary annuity ([PaymentTiming.end]): `FV = P * ((1+i)^n - 1) / i`
/// * annuity-due ([PaymentTiming.start], default): `FV = P * ((1+i)^n - 1) / i * (1+i)`
///
/// With `i = 0`, `FV = P * n`. `i` comes from the annual rate through the
/// [rateConvention] (`annual/12` by default, or the exact effective monthly
/// rate). Excel equivalent of the ordinary case: `=FV(i, n, -P)`; the due case
/// is `=FV(i, n, -P, 0, 1)`.
class SipCalculator {
  /// Creates a SIP calculator.
  const SipCalculator({
    required this.monthlyInvestment,
    required this.annualReturnPercent,
    required this.tenure,
    this.stepUp,
    this.timing = PaymentTiming.start,
    this.rateConvention = RateConvention.nominalMonthly,
  });

  /// First-year monthly instalment.
  final double monthlyInvestment;

  /// Expected annual return in percent (0 to 100).
  final double annualReturnPercent;

  /// Investment length.
  final Tenure tenure;

  /// Optional yearly increase of the instalment.
  final StepUp? stepUp;

  /// Instalment at the start (default) or end of each month.
  final PaymentTiming timing;

  /// How the annual rate becomes a monthly rate.
  final RateConvention rateConvention;

  /// Validates the inputs and computes the result.
  ///
  /// Throws [InvalidInputException] for invalid input.
  SipResult calculate() {
    requirePositive('monthlyInvestment', monthlyInvestment);
    requireRate('annualReturnPercent', annualReturnPercent);
    requireTenure('tenure', tenure);
    final s = stepUp;
    if (s != null) {
      requireNonNegative('stepUp', s.percent);
      requireNonNegative('stepUp', s.amount);
    }
    final n = tenure.totalMonths;
    double c(int m) => s == null
        ? monthlyInvestment
        : s.instalment(monthlyInvestment, m ~/ 12);
    final rows = simulateContributions(
      monthlyRate: monthlyRateFor(annualReturnPercent, rateConvention),
      months: n,
      contribution: c,
      timing: timing,
    );
    return SipResult(rows, lastMonthlyInvestment: c(n - 1));
  }
}

/// Result of [RdCalculator.calculate].
class RdResult extends SipResult {
  /// Creates a result; normally obtained from [RdCalculator.calculate].
  RdResult(super.monthly, {required super.lastMonthlyInvestment});
}

/// Recurring deposit.
///
/// Standard bank formula: deposit `D` at the start of each of `n` months,
/// interest compounded `f` times a year at annual rate `r`:
/// `M = sum_{k=1..n} D * (1 + r/f)^(f * (n-k+1)/12)`. With
/// `q = (1+r/f)^(f/12)` this equals `D * q * (q^n - 1) / (q - 1)`.
class RdCalculator {
  /// Creates a recurring deposit calculator.
  const RdCalculator({
    required this.monthlyDeposit,
    required this.annualRatePercent,
    required this.tenure,
    this.compounding = Compounding.quarterly,
  });

  /// Monthly deposit.
  final double monthlyDeposit;

  /// Annual interest rate in percent.
  final double annualRatePercent;

  /// Deposit length.
  final Tenure tenure;

  /// Compounding frequency (quarterly is the Indian bank convention).
  /// [Compounding.simple] is not supported for an RD.
  final Compounding compounding;

  /// Validates the inputs and computes the result.
  RdResult calculate() {
    requirePositive('monthlyDeposit', monthlyDeposit);
    requireRate('annualRatePercent', annualRatePercent);
    requireTenure('tenure', tenure);
    if (compounding == Compounding.simple) {
      throw const InvalidInputException(
          'compounding', 'simple interest is not supported for an RD');
    }
    final q = compoundFactor(annualRatePercent, compounding, 1);
    final rows = simulateContributions(
      monthlyRate: q - 1,
      months: tenure.totalMonths,
      contribution: (_) => monthlyDeposit,
      timing: PaymentTiming.start,
    );
    return RdResult(rows, lastMonthlyInvestment: monthlyDeposit);
  }
}
