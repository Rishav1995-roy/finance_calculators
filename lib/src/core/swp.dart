import 'common.dart';
import 'result.dart';

/// Result of [SwpCalculator.calculate].
class SwpResult extends CalculatorResult {
  /// Creates a result; normally obtained from [SwpCalculator.calculate].
  SwpResult(super.monthly,
      {required this.initialCorpus, required this.depletionMonth});

  /// Corpus at the start.
  final double initialCorpus;

  /// 1-based month in which the corpus ran out (the last withdrawal may be
  /// partial), or `null` if money lasted the whole tenure. [monthly] stops at
  /// this month.
  final int? depletionMonth;

  /// Sum of all withdrawals.
  double get totalWithdrawn => monthly.last.cumulativeWithdrawn;

  /// Balance left at the end.
  double get finalBalance => monthly.last.closingBalance;

  @override
  double get investedAmount => initialCorpus;

  /// `withdrawn + remaining - corpus`: can be negative when withdrawals eat
  /// into the original corpus.
  @override
  double get estimatedReturns => monthly.last.cumulativeReturns;

  @override
  double get maturityValue => finalBalance;

  @override
  Map<String, Object?> toJson({bool includeMonthly = false}) =>
      <String, Object?>{
        ...super.toJson(includeMonthly: includeMonthly),
        'totalWithdrawn': totalWithdrawn,
        'finalBalance': finalBalance,
        'depletionMonth': depletionMonth,
      };
}

/// Systematic Withdrawal Plan.
///
/// Monthly recurrence with monthly rate `i`, withdrawal `W` at month end:
/// `B_k = B_{k-1} * (1+i) - W`, which has the closed form
/// `B_n = C * (1+i)^n - W * ((1+i)^n - 1) / i`. Withdrawals at the start of
/// the month ([PaymentTiming.start]) are taken before growth. When the
/// balance cannot cover a withdrawal, the remainder is paid out and the plan
/// ends ([SwpResult.depletionMonth]).
class SwpCalculator {
  /// Creates a SWP calculator.
  const SwpCalculator({
    required this.initialCorpus,
    required this.monthlyWithdrawal,
    required this.annualReturnPercent,
    required this.tenure,
    this.annualWithdrawalIncreasePercent = 0,
    this.timing = PaymentTiming.end,
    this.rateConvention = RateConvention.nominalMonthly,
  });

  /// Amount invested before withdrawals begin.
  final double initialCorpus;

  /// First-year monthly withdrawal.
  final double monthlyWithdrawal;

  /// Expected annual return in percent.
  final double annualReturnPercent;

  /// Maximum plan length.
  final Tenure tenure;

  /// Yearly increase of the withdrawal in percent (for inflation).
  final double annualWithdrawalIncreasePercent;

  /// Withdraw at the end (default) or start of the month.
  final PaymentTiming timing;

  /// How the annual rate becomes a monthly rate.
  final RateConvention rateConvention;

  /// Validates the inputs and computes the result.
  SwpResult calculate() {
    requirePositive('initialCorpus', initialCorpus);
    requirePositive('monthlyWithdrawal', monthlyWithdrawal);
    requireRate('annualReturnPercent', annualReturnPercent);
    requireRate(
        'annualWithdrawalIncreasePercent', annualWithdrawalIncreasePercent);
    requireTenure('tenure', tenure);
    final i = monthlyRateFor(annualReturnPercent, rateConvention);
    final b = RowBuilder();
    final rows = <BreakdownRow>[];
    var bal = initialCorpus;
    int? depleted;
    for (var m = 0; m < tenure.totalMonths; m++) {
      final want = monthlyWithdrawal *
          pw(1 + annualWithdrawalIncreasePercent / 100, (m ~/ 12).toDouble());
      final opening = bal;
      double w, interest;
      if (timing == PaymentTiming.end) {
        interest = opening * i;
        final avail = opening + interest;
        w = want < avail ? want : avail;
        bal = avail - w;
      } else {
        w = want < opening ? want : opening;
        interest = (opening - w) * i;
        bal = opening - w + interest;
      }
      final empty = bal <= initialCorpus * 1e-12 || w < want;
      if (empty) bal = 0;
      rows.add(b.add(
        period: m + 1,
        opening: opening,
        invested: m == 0 ? initialCorpus : 0,
        returns: interest,
        withdrawn: w,
        closing: bal,
      ));
      if (empty) {
        depleted = m + 1;
        break;
      }
    }
    return SwpResult(rows,
        initialCorpus: initialCorpus, depletionMonth: depleted);
  }
}
