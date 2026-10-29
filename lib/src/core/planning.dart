import 'common.dart';
import 'result.dart';
import 'sip.dart';

/// Result of [GoalPlanner.calculate].
///
/// [investedAmount], [estimatedReturns] and [maturityValue] describe the plan
/// that reaches the goal: existing savings plus the required SIP.
class GoalPlanResult extends CalculatorResult {
  /// Creates a result; normally obtained from [GoalPlanner.calculate].
  GoalPlanResult(
    super.monthly, {
    required this.targetAmount,
    required this.inflatedTarget,
    required this.requiredMonthlySip,
    required this.requiredLumpsum,
    required this.existingSavingsFutureValue,
  });

  /// Target as entered.
  final double targetAmount;

  /// Target in future money (equals [targetAmount] when the goal is already
  /// in future money or inflation is 0).
  final double inflatedTarget;

  /// First-year monthly SIP needed (0 if existing savings already suffice).
  final double requiredMonthlySip;

  /// One-time investment today needed to reach the goal (after deducting
  /// existing savings, never negative).
  final double requiredLumpsum;

  /// What existing savings grow to by the end of the tenure.
  final double existingSavingsFutureValue;

  /// Whether existing savings alone reach the target.
  bool get alreadyAchieved => requiredMonthlySip == 0;

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
        'targetAmount': targetAmount,
        'inflatedTarget': inflatedTarget,
        'requiredMonthlySip': requiredMonthlySip,
        'requiredLumpsum': requiredLumpsum,
        'existingSavingsFutureValue': existingSavingsFutureValue,
      };
}

/// Works out the SIP or lumpsum needed to reach a target.
///
/// Future value is linear in the instalment, so the required SIP is
/// `(T - S*(1+i)^n) / FV(1)` where `T` is the (inflated) target, `S` existing
/// savings, `i` the monthly rate and `FV(1)` the SIP future value for a unit
/// instalment (annuity formula, including any step-up). The lumpsum is
/// `T / (1+i)^n - S`. Inflation: `T = target * (1 + inflation)^years` when
/// [targetInTodaysMoney] is true.
class GoalPlanner {
  /// Creates a goal planner.
  const GoalPlanner({
    required this.targetAmount,
    required this.tenure,
    required this.annualReturnPercent,
    this.inflationPercent = 0,
    this.targetInTodaysMoney = true,
    this.existingSavings = 0,
    this.stepUp,
    this.timing = PaymentTiming.start,
    this.rateConvention = RateConvention.nominalMonthly,
  });

  /// The amount wanted.
  final double targetAmount;

  /// Time available.
  final Tenure tenure;

  /// Expected annual return in percent.
  final double annualReturnPercent;

  /// Expected yearly inflation in percent.
  final double inflationPercent;

  /// Treat [targetAmount] as today's money and inflate it to the goal date.
  final bool targetInTodaysMoney;

  /// Amount already saved towards the goal.
  final double existingSavings;

  /// Optional yearly SIP step-up.
  final StepUp? stepUp;

  /// SIP instalment timing.
  final PaymentTiming timing;

  /// How the annual rate becomes a monthly rate.
  final RateConvention rateConvention;

  /// Validates the inputs and computes the plan.
  GoalPlanResult calculate() {
    requirePositive('targetAmount', targetAmount);
    requireRate('annualReturnPercent', annualReturnPercent);
    requireRate('inflationPercent', inflationPercent);
    requireNonNegative('existingSavings', existingSavings);
    requireTenure('tenure', tenure);
    final n = tenure.totalMonths;
    final i = monthlyRateFor(annualReturnPercent, rateConvention);
    final t = targetInTodaysMoney
        ? targetAmount * pw(1 + inflationPercent / 100, n / 12)
        : targetAmount;
    final growth = pw(1 + i, n.toDouble());
    final fvExisting = existingSavings * growth;
    final unit = SipCalculator(
      monthlyInvestment: 1,
      annualReturnPercent: annualReturnPercent,
      tenure: tenure,
      stepUp: stepUp,
      timing: timing,
      rateConvention: rateConvention,
    ).calculate().maturityValue;
    final sip = t > fvExisting ? (t - fvExisting) / unit : 0.0;
    final lump = t / growth - existingSavings;
    final s = stepUp;
    final rows = simulateContributions(
      monthlyRate: i,
      months: n,
      contribution: (m) => s == null ? sip : s.instalment(sip, m ~/ 12),
      timing: timing,
      initial: existingSavings,
    );
    return GoalPlanResult(
      rows,
      targetAmount: targetAmount,
      inflatedTarget: t,
      requiredMonthlySip: sip,
      requiredLumpsum: lump > 0 ? lump : 0,
      existingSavingsFutureValue: fvExisting,
    );
  }
}

/// Result of [RetirementCalculator.calculate].
///
/// [monthly] runs from today to the end of life expectancy: first the saving
/// phase, then the spending phase (rows with `withdrawn > 0`).
class RetirementResult extends CalculatorResult {
  /// Creates a result; normally obtained from [RetirementCalculator.calculate].
  RetirementResult(
    super.monthly, {
    required this.corpusNeeded,
    required this.monthlyExpenseAtRetirement,
    required this.requiredMonthlySip,
    required this.existingSavingsFutureValue,
    required this.monthsToRetirement,
  });

  /// Corpus needed on the retirement date.
  final double corpusNeeded;

  /// First monthly expense after retiring, in future money.
  final double monthlyExpenseAtRetirement;

  /// First-year monthly SIP needed (0 if existing savings suffice).
  final double requiredMonthlySip;

  /// Existing savings grown to the retirement date.
  final double existingSavingsFutureValue;

  /// Length of the saving phase in months.
  final int monthsToRetirement;

  @override
  double get investedAmount =>
      monthly[monthsToRetirement - 1].cumulativeInvested;

  @override
  double get estimatedReturns =>
      monthly[monthsToRetirement - 1].cumulativeReturns;

  @override
  double get maturityValue => corpusNeeded;

  @override
  Map<String, Object?> toJson({bool includeMonthly = false}) =>
      <String, Object?>{
        ...super.toJson(includeMonthly: includeMonthly),
        'corpusNeeded': corpusNeeded,
        'monthlyExpenseAtRetirement': monthlyExpenseAtRetirement,
        'requiredMonthlySip': requiredMonthlySip,
        'existingSavingsFutureValue': existingSavingsFutureValue,
        'monthsToRetirement': monthsToRetirement,
      };
}

/// Retirement corpus and the SIP that builds it.
///
/// 1. Expense at retirement: `E0 * (1 + inflation)^(years to retire)`.
/// 2. Spending phase: monthly spending rises by inflation once a year and is
///    taken at the start of each month; with monthly post-retirement rate `j`
///    the corpus needed is `sum_m W_m / (1+j)^(m-1)` (present value of the
///    spending stream).
/// 3. Saving phase: required SIP as in [GoalPlanner] with the
///    pre-retirement return.
///
/// Monthly rates are `annual / 12` ([RateConvention.nominalMonthly]).
class RetirementCalculator {
  /// Creates a retirement calculator.
  const RetirementCalculator({
    required this.currentAge,
    required this.retirementAge,
    required this.lifeExpectancy,
    required this.monthlyExpenseToday,
    required this.inflationPercent,
    required this.preRetirementReturnPercent,
    required this.postRetirementReturnPercent,
    this.existingSavings = 0,
    this.sipStepUpPercent = 0,
  });

  /// Age today.
  final int currentAge;

  /// Age at which work stops.
  final int retirementAge;

  /// Age until which money must last.
  final int lifeExpectancy;

  /// Monthly spending today, in today's money.
  final double monthlyExpenseToday;

  /// Expected yearly inflation in percent.
  final double inflationPercent;

  /// Expected yearly return while saving, in percent.
  final double preRetirementReturnPercent;

  /// Expected yearly return after retiring, in percent.
  final double postRetirementReturnPercent;

  /// Savings already available.
  final double existingSavings;

  /// Yearly SIP increase in percent.
  final double sipStepUpPercent;

  /// Validates the inputs and computes the plan.
  RetirementResult calculate() {
    requirePositive('monthlyExpenseToday', monthlyExpenseToday);
    requireRate('inflationPercent', inflationPercent);
    requireRate('preRetirementReturnPercent', preRetirementReturnPercent);
    requireRate('postRetirementReturnPercent', postRetirementReturnPercent);
    requireNonNegative('existingSavings', existingSavings);
    requireRate('sipStepUpPercent', sipStepUpPercent);
    if (currentAge < 0 || currentAge >= retirementAge) {
      throw const InvalidInputException(
          'retirementAge', 'must be greater than currentAge');
    }
    if (lifeExpectancy <= retirementAge || lifeExpectancy > 130) {
      throw const InvalidInputException(
          'lifeExpectancy', 'must be greater than retirementAge (max 130)');
    }
    final years = retirementAge - currentAge;
    final nSave = years * 12;
    final nSpend = (lifeExpectancy - retirementAge) * 12;
    final infl = 1 + inflationPercent / 100;
    final w0 = monthlyExpenseToday * pw(infl, years.toDouble());
    final j = postRetirementReturnPercent / 1200;
    // Present value by backward recursion: V_m = W_m + V_{m+1} / (1+j).
    var v = 0.0;
    for (var m = nSpend - 1; m >= 0; m--) {
      v = w0 * pw(infl, (m ~/ 12).toDouble()) + v / (1 + j);
    }
    final corpus = v;
    final i = preRetirementReturnPercent / 1200;
    final fvExisting = existingSavings * pw(1 + i, nSave.toDouble());
    final step = StepUp.percent(sipStepUpPercent);
    final unit = SipCalculator(
      monthlyInvestment: 1,
      annualReturnPercent: preRetirementReturnPercent,
      tenure: Tenure.months(nSave),
      stepUp: sipStepUpPercent > 0 ? step : null,
    ).calculate().maturityValue;
    final sip = corpus > fvExisting ? (corpus - fvExisting) / unit : 0.0;
    final saving = simulateContributions(
      monthlyRate: i,
      months: nSave,
      contribution: (m) =>
          sipStepUpPercent > 0 ? step.instalment(sip, m ~/ 12) : sip,
      timing: PaymentTiming.start,
      initial: existingSavings,
    );
    final rows = <BreakdownRow>[...saving];
    final last = saving.last;
    var bal = last.closingBalance;
    var cumWd = 0.0;
    for (var m = 0; m < nSpend; m++) {
      final w = w0 * pw(infl, (m ~/ 12).toDouble());
      final opening = bal;
      final avail = opening - w;
      final interest = avail > 0 ? avail * j : 0.0;
      bal = avail > 0 ? avail + interest : 0.0;
      cumWd += w;
      rows.add(BreakdownRow(
        period: nSave + m + 1,
        openingBalance: opening,
        invested: 0,
        returns: interest,
        withdrawn: w,
        closingBalance: bal,
        cumulativeInvested: last.cumulativeInvested,
        cumulativeReturns: bal + cumWd - last.cumulativeInvested,
        cumulativeWithdrawn: cumWd,
      ));
    }
    return RetirementResult(
      rows,
      corpusNeeded: corpus,
      monthlyExpenseAtRetirement: w0,
      requiredMonthlySip: sip,
      existingSavingsFutureValue: fvExisting,
      monthsToRetirement: nSave,
    );
  }
}
