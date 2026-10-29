import 'common.dart';
import 'result.dart';

/// A one-time extra payment towards the principal.
class Prepayment {
  /// A prepayment of [amount] made together with instalment number [month]
  /// (1-based).
  const Prepayment(this.month, this.amount);

  /// Instalment number the prepayment accompanies.
  final int month;

  /// Extra principal paid.
  final double amount;
}

/// One instalment of a loan schedule.
class AmortizationRow {
  /// Creates a row.
  const AmortizationRow({
    required this.month,
    required this.payment,
    required this.principal,
    required this.interest,
    required this.prepayment,
    required this.balance,
  });

  /// 1-based instalment number.
  final int month;

  /// Scheduled instalment paid (principal + interest, excluding prepayment).
  final double payment;

  /// Principal part of [payment].
  final double principal;

  /// Interest part of [payment].
  final double interest;

  /// Extra principal paid this month.
  final double prepayment;

  /// Outstanding principal after this month.
  final double balance;

  /// A JSON friendly map.
  Map<String, Object?> toJson() => <String, Object?>{
        'month': month,
        'payment': payment,
        'principal': principal,
        'interest': interest,
        'prepayment': prepayment,
        'balance': balance,
      };
}

/// Result of [EmiCalculator.calculate].
///
/// As a [CalculatorResult]: [investedAmount] = principal, [estimatedReturns] =
/// total interest, [maturityValue] = total payment. In [monthly] / [yearly]
/// rows, `invested` is principal repaid (including prepayments), `returns` is
/// interest, `withdrawn` is the cash paid and `closingBalance` the
/// outstanding principal.
class EmiResult extends CalculatorResult {
  /// Creates a result; normally obtained from [EmiCalculator.calculate].
  EmiResult(
    super.monthly, {
    required this.principal,
    required this.emi,
    required this.schedule,
    required this.scheduledMonths,
    required this.interestWithoutPrepayment,
  });

  /// Loan amount.
  final double principal;

  /// Scheduled monthly instalment.
  final double emi;

  /// Full amortization schedule, one row per paid month.
  final List<AmortizationRow> schedule;

  /// Months originally agreed.
  final int scheduledMonths;

  /// Total interest had no prepayment been made.
  final double interestWithoutPrepayment;

  /// Total interest paid.
  double get totalInterest => schedule.fold(0.0, (a, r) => a + r.interest);

  /// Everything paid: principal plus interest.
  double get totalPayment => principal + totalInterest;

  /// Months until the loan is closed (shorter than [scheduledMonths] with
  /// prepayments).
  int get months => schedule.length;

  /// Months saved by prepayments.
  int get monthsSaved => scheduledMonths - months;

  /// Interest saved by prepayments.
  double get interestSaved => interestWithoutPrepayment - totalInterest;

  @override
  double get investedAmount => principal;

  @override
  double get estimatedReturns => totalInterest;

  @override
  double get maturityValue => totalPayment;

  @override
  Map<String, Object?> toJson({bool includeMonthly = false}) =>
      <String, Object?>{
        ...super.toJson(includeMonthly: includeMonthly),
        'principal': principal,
        'emi': emi,
        'totalInterest': totalInterest,
        'totalPayment': totalPayment,
        'months': months,
        'monthsSaved': monthsSaved,
        'interestSaved': interestSaved,
        'schedule': schedule.map((r) => r.toJson()).toList(),
      };
}

/// Loan EMI and amortization schedule.
///
/// Standard reducing-balance formula with monthly rate `i = annual / 1200` and
/// `n` months: `EMI = P * i * (1+i)^n / ((1+i)^n - 1)`; with `i = 0`,
/// `EMI = P / n`. Excel equivalent: `=-PMT(i, n, P)`. Each month
/// `interest = balance * i`, `principal = EMI - interest`.
///
/// Prepayments ([prepayments], [extraMonthlyPayment]) reduce the balance; the
/// EMI stays the same, so the loan closes sooner. If [roundingDecimals] is set
/// the EMI and each month's interest are rounded like a bank statement, and
/// the last instalment absorbs the difference.
class EmiCalculator {
  /// Creates an EMI calculator.
  const EmiCalculator({
    required this.principal,
    required this.annualRatePercent,
    required this.tenure,
    this.prepayments = const <Prepayment>[],
    this.extraMonthlyPayment = 0,
    this.roundingDecimals,
  });

  /// Loan amount.
  final double principal;

  /// Annual interest rate in percent.
  final double annualRatePercent;

  /// Loan length.
  final Tenure tenure;

  /// One-time extra payments.
  final List<Prepayment> prepayments;

  /// Extra principal paid every month.
  final double extraMonthlyPayment;

  /// Round EMI and monthly interest to this many decimals (for example 2),
  /// or `null` for full precision.
  final int? roundingDecimals;

  /// The monthly instalment for the given loan, without a schedule.
  static double emiFor(double principal, double annualRatePercent, int months) {
    final i = annualRatePercent / 1200;
    if (i == 0) return principal / months;
    final g = pw(1 + i, months.toDouble());
    return principal * i * g / (g - 1);
  }

  List<AmortizationRow> _schedule(bool withPrepay) {
    final n = tenure.totalMonths;
    final i = annualRatePercent / 1200;
    final d = roundingDecimals;
    double r(double v) => d == null ? v : roundTo(v, d);
    final emi = r(emiFor(principal, annualRatePercent, n));
    final extra = <int, double>{};
    if (withPrepay) {
      for (final p in prepayments) {
        extra[p.month] = (extra[p.month] ?? 0) + p.amount;
      }
    }
    final rows = <AmortizationRow>[];
    var bal = principal;
    for (var m = 1; m <= n; m++) {
      final interest = r(bal * i);
      var principalPaid = emi - interest;
      if (principalPaid < 0) principalPaid = 0;
      if (m == n || principalPaid >= bal) principalPaid = bal;
      final pre = withPrepay
          ? (extraMonthlyPayment + (extra[m] ?? 0))
              .clamp(0, bal - principalPaid)
          : 0.0;
      bal = bal - principalPaid - pre;
      if (bal < 1e-9 * principal) bal = 0;
      rows.add(AmortizationRow(
        month: m,
        payment: principalPaid + interest,
        principal: principalPaid,
        interest: interest,
        prepayment: pre.toDouble(),
        balance: bal,
      ));
      if (bal == 0) break;
    }
    return rows;
  }

  /// Validates the inputs and computes the result.
  EmiResult calculate() {
    requirePositive('principal', principal);
    requireRate('annualRatePercent', annualRatePercent);
    requireTenure('tenure', tenure);
    requireNonNegative('extraMonthlyPayment', extraMonthlyPayment);
    final d = roundingDecimals;
    if (d != null && (d < 0 || d > 6)) {
      throw const InvalidInputException(
          'roundingDecimals', 'must be between 0 and 6');
    }
    for (final p in prepayments) {
      requirePositive('prepayment.amount', p.amount);
      if (p.month < 1 || p.month > tenure.totalMonths) {
        throw const InvalidInputException(
            'prepayment.month', 'must be within the loan tenure');
      }
    }
    final hasPrepay = prepayments.isNotEmpty || extraMonthlyPayment > 0;
    final sched = _schedule(hasPrepay);
    final base = hasPrepay ? _schedule(false) : sched;
    final b = RowBuilder();
    final rows = <BreakdownRow>[];
    var opening = principal;
    for (final s in sched) {
      rows.add(b.add(
        period: s.month,
        opening: opening,
        invested: s.principal + s.prepayment,
        returns: s.interest,
        withdrawn: s.payment + s.prepayment,
        closing: s.balance,
      ));
      opening = s.balance;
    }
    // For loans the cumulative figures are principal repaid and interest.
    final fixed = <BreakdownRow>[];
    var cumP = 0.0, cumI = 0.0, cumW = 0.0;
    for (final r in rows) {
      cumP += r.invested;
      cumI += r.returns;
      cumW += r.withdrawn;
      fixed.add(BreakdownRow(
        period: r.period,
        openingBalance: r.openingBalance,
        invested: r.invested,
        returns: r.returns,
        withdrawn: r.withdrawn,
        closingBalance: r.closingBalance,
        cumulativeInvested: cumP,
        cumulativeReturns: cumI,
        cumulativeWithdrawn: cumW,
      ));
    }
    return EmiResult(
      fixed,
      principal: principal,
      emi: sched.first.payment == 0
          ? 0
          : (d == null
              ? emiFor(principal, annualRatePercent, tenure.totalMonths)
              : roundTo(
                  emiFor(principal, annualRatePercent, tenure.totalMonths), d)),
      schedule: List<AmortizationRow>.unmodifiable(sched),
      scheduledMonths: tenure.totalMonths,
      interestWithoutPrepayment: base.fold(0.0, (a, r) => a + r.interest),
    );
  }
}
