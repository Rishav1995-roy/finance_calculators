import 'dart:convert';
import 'dart:math' as math;

import 'package:finance_calculators/finance_calculators.dart';
import 'package:flutter_test/flutter_test.dart';

// Independent reference formulas (Excel FV / PMT / RRI equivalents), written
// separately from the library code.
double excelFv(double rate, int nper, double pmt, {bool due = false}) {
  if (rate == 0) return pmt * nper;
  final f = (math.pow(1 + rate, nper) - 1) / rate * pmt;
  return due ? f * (1 + rate) : f;
}

double excelPmt(double rate, int nper, double pv) {
  if (rate == 0) return pv / nper;
  return pv * rate / (1 - math.pow(1 + rate, -nper));
}

void main() {
  group('SIP', () {
    test('matches closed form, annuity-due and ordinary', () {
      const sip = SipCalculator(
          monthlyInvestment: 5000,
          annualReturnPercent: 12,
          tenure: Tenure.years(10));
      final due = sip.calculate();
      expect(due.maturityValue,
          closeTo(excelFv(0.01, 120, 5000, due: true), 1e-6));
      expect(due.investedAmount, 600000);
      expect(due.estimatedReturns, closeTo(due.maturityValue - 600000, 1e-6));
      final ord = const SipCalculator(
              monthlyInvestment: 5000,
              annualReturnPercent: 12,
              tenure: Tenure.years(10),
              timing: PaymentTiming.end)
          .calculate();
      expect(ord.maturityValue, closeTo(excelFv(0.01, 120, 5000), 1e-6));
      // Hand check: the 120-month, 1% annuity factor is 230.0387, so
      // 5,000 x 230.0387 = 1,150,193.45.
      expect(ord.maturityValue, closeTo(1150193.45, 0.01));
    });

    test('effective annual convention', () {
      final r = const SipCalculator(
              monthlyInvestment: 1000,
              annualReturnPercent: 12,
              tenure: Tenure.years(5),
              rateConvention: RateConvention.effectiveAnnual,
              timing: PaymentTiming.end)
          .calculate();
      final i = (math.pow(1.12, 1 / 12) - 1).toDouble();
      expect(r.maturityValue, closeTo(excelFv(i, 60, 1000), 1e-6));
    });

    test('0% rate returns exactly the invested amount', () {
      final r = const SipCalculator(
              monthlyInvestment: 2500,
              annualReturnPercent: 0,
              tenure: Tenure.years(3))
          .calculate();
      expect(r.maturityValue, 90000);
      expect(r.estimatedReturns, 0);
    });

    test('1 month tenure', () {
      final r = const SipCalculator(
              monthlyInvestment: 1000,
              annualReturnPercent: 12,
              tenure: Tenure.months(1))
          .calculate();
      expect(r.monthly, hasLength(1));
      expect(r.maturityValue, closeTo(1010, 1e-9));
      expect(r.yearly, hasLength(1));
    });

    test('very long tenure stays finite and ordered', () {
      final r = const SipCalculator(
              monthlyInvestment: 10000,
              annualReturnPercent: 15,
              tenure: Tenure.years(100))
          .calculate();
      expect(r.maturityValue.isFinite, isTrue);
      expect(
          r.maturityValue,
          closeTo(
              excelFv(0.0125, 1200, 10000, due: true), r.maturityValue * 1e-9));
      expect(r.yearly, hasLength(100));
    });

    test('breakdown is consistent', () {
      final r = const SipCalculator(
              monthlyInvestment: 5000,
              annualReturnPercent: 10,
              tenure: Tenure.yearsAndMonths(2, 5))
          .calculate();
      expect(r.totalMonths, 29);
      expect(r.yearly, hasLength(3));
      var inv = 0.0, ret = 0.0;
      for (final y in r.yearly) {
        inv += y.invested;
        ret += y.returns;
      }
      expect(inv, closeTo(r.investedAmount, 1e-6));
      expect(ret, closeTo(r.estimatedReturns, 1e-6));
      for (final m in r.monthly) {
        expect(m.closingBalance,
            closeTo(m.openingBalance + m.invested + m.returns, 1e-6));
      }
      expect(r.yearly.last.closingBalance, r.maturityValue);
    });

    test('step-up percent equals sum of yearly blocks', () {
      final r = const SipCalculator(
              monthlyInvestment: 10000,
              annualReturnPercent: 12,
              tenure: Tenure.years(10),
              stepUp: StepUp.percent(10),
              timing: PaymentTiming.end)
          .calculate();
      var fv = 0.0;
      for (var k = 0; k < 10; k++) {
        final p = 10000 * math.pow(1.1, k);
        fv += excelFv(0.01, 12, p.toDouble()) * math.pow(1.01, 12 * (9 - k));
      }
      expect(r.maturityValue, closeTo(fv, 1e-4));
      expect(r.lastMonthlyInvestment, closeTo(10000 * math.pow(1.1, 9), 1e-6));
      var invested = 0.0;
      for (var k = 0; k < 10; k++) {
        invested += 12 * 10000 * math.pow(1.1, k);
      }
      expect(r.investedAmount, closeTo(invested, 1e-6));
    });

    test('step-up fixed amount', () {
      final r = const SipCalculator(
              monthlyInvestment: 1000,
              annualReturnPercent: 0,
              tenure: Tenure.years(3),
              stepUp: StepUp.fixed(500))
          .calculate();
      expect(r.investedAmount, 12 * (1000 + 1500 + 2000));
    });

    test('validation errors', () {
      void bad(SipCalculator c, String field) => expect(
          c.calculate,
          throwsA(isA<InvalidInputException>()
              .having((e) => e.field, 'field', field)));
      bad(
          const SipCalculator(
              monthlyInvestment: 0,
              annualReturnPercent: 10,
              tenure: Tenure.years(1)),
          'monthlyInvestment');
      bad(
          const SipCalculator(
              monthlyInvestment: 1,
              annualReturnPercent: -1,
              tenure: Tenure.years(1)),
          'annualReturnPercent');
      bad(
          const SipCalculator(
              monthlyInvestment: 1,
              annualReturnPercent: 10,
              tenure: Tenure.months(0)),
          'tenure');
      bad(
          const SipCalculator(
              monthlyInvestment: 1,
              annualReturnPercent: 10,
              tenure: Tenure.months(1201)),
          'tenure');
      bad(
          const SipCalculator(
              monthlyInvestment: double.nan,
              annualReturnPercent: 10,
              tenure: Tenure.years(1)),
          'monthlyInvestment');
    });

    test('toJson round trips through jsonEncode', () {
      final r = const SipCalculator(
              monthlyInvestment: 5000,
              annualReturnPercent: 12,
              tenure: Tenure.years(2))
          .calculate();
      final m = jsonDecode(jsonEncode(r.toJson(includeMonthly: true)))
          as Map<String, Object?>;
      expect(m['maturityValue'], closeTo(r.maturityValue, 1e-9));
      expect((m['yearly']! as List<Object?>), hasLength(2));
      expect((m['monthly']! as List<Object?>), hasLength(24));
    });
  });

  group('Lumpsum / FD / RD', () {
    test('lumpsum yearly compounding and fractional tenure', () {
      final r = const LumpsumCalculator(
              amount: 100000, annualReturnPercent: 8, tenure: Tenure.years(5))
          .calculate();
      expect(r.maturityValue, closeTo(100000 * math.pow(1.08, 5), 1e-6));
      final r2 = const LumpsumCalculator(
              amount: 100000, annualReturnPercent: 8, tenure: Tenure.months(18))
          .calculate();
      expect(r2.maturityValue, closeTo(100000 * math.pow(1.08, 1.5), 1e-6));
    });

    test('lumpsum 0% and simple interest', () {
      expect(
          const LumpsumCalculator(
                  amount: 500, annualReturnPercent: 0, tenure: Tenure.years(4))
              .calculate()
              .maturityValue,
          500);
      final s = const LumpsumCalculator(
              amount: 1000,
              annualReturnPercent: 10,
              tenure: Tenure.years(3),
              compounding: Compounding.simple)
          .calculate();
      expect(s.maturityValue, closeTo(1300, 1e-9));
    });

    test('FD quarterly: hand-checked 1,00,000 at 7% for 5 years', () {
      final r = const FdCalculator(
              deposit: 100000, annualRatePercent: 7, tenure: Tenure.years(5))
          .calculate();
      expect(r.maturityValue, closeTo(100000 * math.pow(1.0175, 20), 1e-6));
      expect(r.maturityValue, closeTo(141477.82, 0.01));
      expect(r.effectiveAnnualYieldPercent, closeTo(7.1859, 1e-3));
    });

    test('FD all compounding frequencies', () {
      for (final c
          in Compounding.values.where((c) => c != Compounding.simple)) {
        final r = FdCalculator(
                deposit: 1000,
                annualRatePercent: 6,
                tenure: const Tenure.years(2),
                compounding: c)
            .calculate();
        expect(
            r.maturityValue,
            closeTo(
                1000 * math.pow(1 + 0.06 / c.perYear, 2 * c.perYear), 1e-6));
      }
    });

    test('RD quarterly equals explicit sum', () {
      final r = const RdCalculator(
              monthlyDeposit: 2000,
              annualRatePercent: 6.5,
              tenure: Tenure.years(3))
          .calculate();
      var m = 0.0;
      for (var k = 1; k <= 36; k++) {
        m += 2000 * math.pow(1 + 0.065 / 4, 4 * (36 - k + 1) / 12);
      }
      expect(r.maturityValue, closeTo(m, 1e-6));
      expect(r.investedAmount, 72000);
    });

    test('RD 0% rate and simple compounding rejected', () {
      expect(
          const RdCalculator(
                  monthlyDeposit: 100,
                  annualRatePercent: 0,
                  tenure: Tenure.months(10))
              .calculate()
              .maturityValue,
          1000);
      expect(
          const RdCalculator(
                  monthlyDeposit: 100,
                  annualRatePercent: 5,
                  tenure: Tenure.months(10),
                  compounding: Compounding.simple)
              .calculate,
          throwsA(isA<InvalidInputException>()));
    });
  });

  group('SWP', () {
    test('closed form when money lasts', () {
      final r = const SwpCalculator(
              initialCorpus: 5000000,
              monthlyWithdrawal: 30000,
              annualReturnPercent: 9,
              tenure: Tenure.years(15))
          .calculate();
      final i = 0.09 / 12;
      final g = math.pow(1 + i, 180);
      final expected = 5000000 * g - 30000 * (g - 1) / i;
      expect(r.depletionMonth, isNull);
      expect(r.finalBalance, closeTo(expected, 1e-4));
      expect(r.totalWithdrawn, 30000 * 180);
      expect(r.estimatedReturns,
          closeTo(r.totalWithdrawn + r.finalBalance - 5000000, 1e-6));
    });

    test('depletion month is found and the last withdrawal is partial', () {
      final r = const SwpCalculator(
              initialCorpus: 100000,
              monthlyWithdrawal: 10000,
              annualReturnPercent: 0,
              tenure: Tenure.years(2))
          .calculate();
      expect(r.depletionMonth, 10);
      expect(r.monthly, hasLength(10));
      expect(r.finalBalance, 0);
      expect(r.totalWithdrawn, closeTo(100000, 1e-9));
      final r2 = const SwpCalculator(
              initialCorpus: 95000,
              monthlyWithdrawal: 10000,
              annualReturnPercent: 0,
              tenure: Tenure.years(2))
          .calculate();
      expect(r2.depletionMonth, 10);
      expect(r2.monthly.last.withdrawn, closeTo(5000, 1e-9));
    });

    test('withdrawal at start and yearly increase', () {
      final r = const SwpCalculator(
              initialCorpus: 1000000,
              monthlyWithdrawal: 1000,
              annualReturnPercent: 0,
              tenure: Tenure.years(2),
              annualWithdrawalIncreasePercent: 10,
              timing: PaymentTiming.start)
          .calculate();
      expect(r.totalWithdrawn, closeTo(12 * 1000 + 12 * 1100, 1e-6));
    });

    test('sustainable: withdrawal equal to interest never depletes', () {
      final r = const SwpCalculator(
              initialCorpus: 1200000,
              monthlyWithdrawal: 12000,
              annualReturnPercent: 12,
              tenure: Tenure.years(30))
          .calculate();
      expect(r.depletionMonth, isNull);
      expect(r.finalBalance, closeTo(1200000, 1e-3));
    });
  });

  group('EMI', () {
    test('matches Excel PMT', () {
      final r = const EmiCalculator(
              principal: 2500000,
              annualRatePercent: 8.5,
              tenure: Tenure.years(20))
          .calculate();
      final pmt = excelPmt(0.085 / 12, 240, 2500000);
      expect(r.emi, closeTo(pmt, 1e-6));
      expect(r.emi, closeTo(21696.0, 1.0)); // widely quoted EMI for this loan
      expect(r.totalPayment, closeTo(pmt * 240, 1e-3));
      expect(r.schedule.last.balance, 0);
      expect(r.schedule, hasLength(240));
      expect(r.totalInterest, closeTo(pmt * 240 - 2500000, 1e-3));
    });

    test('schedule is internally consistent', () {
      final r = const EmiCalculator(
              principal: 1000000, annualRatePercent: 9, tenure: Tenure.years(5))
          .calculate();
      var bal = 1000000.0;
      for (final s in r.schedule) {
        expect(s.interest, closeTo(bal * 0.0075, 1e-6));
        expect(s.principal + s.interest, closeTo(s.payment, 1e-6));
        bal -= s.principal + s.prepayment;
        expect(s.balance, closeTo(bal, 1e-6));
      }
      expect(r.yearly, hasLength(5));
      expect(r.yearly.last.closingBalance, 0);
      expect(r.yearly.fold<double>(0, (a, y) => a + y.invested),
          closeTo(1000000, 1e-6));
    });

    test('0% rate', () {
      final r = const EmiCalculator(
              principal: 120000, annualRatePercent: 0, tenure: Tenure.years(1))
          .calculate();
      expect(r.emi, 10000);
      expect(r.totalInterest, 0);
    });

    test('1 month loan', () {
      final r = const EmiCalculator(
              principal: 1000, annualRatePercent: 12, tenure: Tenure.months(1))
          .calculate();
      expect(r.emi, closeTo(1010, 1e-9));
      expect(r.schedule, hasLength(1));
    });

    test('rounding to 2 decimals: last instalment absorbs the difference', () {
      final r = const EmiCalculator(
              principal: 500000,
              annualRatePercent: 10.25,
              tenure: Tenure.years(3),
              roundingDecimals: 2)
          .calculate();
      expect(r.schedule.last.balance, 0);
      for (final s in r.schedule.take(35)) {
        expect(s.payment, closeTo(r.emi, 0.011));
        expect(s.interest, closeTo((s.interest * 100).round() / 100, 1e-9));
      }
      expect(r.emi, closeTo((r.emi * 100).round() / 100, 1e-9));
    });

    test('prepayments shorten the loan and save interest', () {
      const base = EmiCalculator(
          principal: 1000000, annualRatePercent: 9, tenure: Tenure.years(10));
      final plain = base.calculate();
      final pre = const EmiCalculator(
              principal: 1000000,
              annualRatePercent: 9,
              tenure: Tenure.years(10),
              prepayments: [Prepayment(12, 100000), Prepayment(24, 50000)])
          .calculate();
      expect(pre.emi, closeTo(plain.emi, 1e-9));
      expect(pre.months, lessThan(120));
      expect(pre.monthsSaved, 120 - pre.months);
      expect(pre.interestSaved, greaterThan(0));
      expect(pre.interestWithoutPrepayment, closeTo(plain.totalInterest, 1e-6));
      expect(pre.schedule.last.balance, 0);
      final repaid = pre.schedule
          .fold<double>(0, (a, s) => a + s.principal + s.prepayment);
      expect(repaid, closeTo(1000000, 1e-6));
      final extra = const EmiCalculator(
              principal: 1000000,
              annualRatePercent: 9,
              tenure: Tenure.years(10),
              extraMonthlyPayment: 5000)
          .calculate();
      expect(extra.months, lessThan(pre.months));
    });

    test('invalid prepayment month', () {
      expect(
          const EmiCalculator(
              principal: 1000,
              annualRatePercent: 5,
              tenure: Tenure.months(6),
              prepayments: [Prepayment(7, 10)]).calculate,
          throwsA(isA<InvalidInputException>()));
    });
  });

  group('Goal planner', () {
    test('required SIP reaches the target (ordinary annuity)', () {
      final r = const GoalPlanner(
              targetAmount: 10000000,
              tenure: Tenure.years(15),
              annualReturnPercent: 12,
              timing: PaymentTiming.end)
          .calculate();
      final expected = 10000000 / (excelFv(0.01, 180, 1));
      expect(r.requiredMonthlySip, closeTo(expected, 1e-6));
      expect(r.maturityValue, closeTo(10000000, 1e-4));
      expect(r.requiredLumpsum, closeTo(10000000 / math.pow(1.01, 180), 1e-4));
    });

    test('inflation inflates the target', () {
      final r = const GoalPlanner(
              targetAmount: 5000000,
              tenure: Tenure.years(10),
              annualReturnPercent: 10,
              inflationPercent: 6)
          .calculate();
      expect(r.inflatedTarget, closeTo(5000000 * math.pow(1.06, 10), 1e-4));
      expect(r.maturityValue, closeTo(r.inflatedTarget, 1e-3));
    });

    test('existing savings reduce or remove the SIP', () {
      final r = const GoalPlanner(
              targetAmount: 1000000,
              tenure: Tenure.years(10),
              annualReturnPercent: 12,
              existingSavings: 2000000)
          .calculate();
      expect(r.alreadyAchieved, isTrue);
      expect(r.requiredMonthlySip, 0);
      expect(r.requiredLumpsum, 0);
      final partial = const GoalPlanner(
              targetAmount: 5000000,
              tenure: Tenure.years(10),
              annualReturnPercent: 12,
              existingSavings: 500000)
          .calculate();
      expect(partial.maturityValue, closeTo(5000000, 1e-3));
      expect(partial.investedAmount,
          closeTo(500000 + partial.requiredMonthlySip * 120, 1e-3));
    });

    test('with step-up', () {
      final r = const GoalPlanner(
              targetAmount: 2000000,
              tenure: Tenure.years(10),
              annualReturnPercent: 10,
              stepUp: StepUp.percent(10))
          .calculate();
      expect(r.maturityValue, closeTo(2000000, 1e-3));
      final flat = const GoalPlanner(
              targetAmount: 2000000,
              tenure: Tenure.years(10),
              annualReturnPercent: 10)
          .calculate();
      expect(r.requiredMonthlySip, lessThan(flat.requiredMonthlySip));
    });

    test('0% return', () {
      final r = const GoalPlanner(
              targetAmount: 120000,
              tenure: Tenure.years(1),
              annualReturnPercent: 0)
          .calculate();
      expect(r.requiredMonthlySip, closeTo(10000, 1e-9));
    });
  });

  group('Retirement', () {
    test('corpus equals the independent present value of spending', () {
      final r = const RetirementCalculator(
              currentAge: 30,
              retirementAge: 60,
              lifeExpectancy: 85,
              monthlyExpenseToday: 50000,
              inflationPercent: 6,
              preRetirementReturnPercent: 12,
              postRetirementReturnPercent: 8)
          .calculate();
      final w0 = 50000 * math.pow(1.06, 30);
      expect(r.monthlyExpenseAtRetirement, closeTo(w0, 1e-6));
      var pv = 0.0;
      for (var m = 1; m <= 300; m++) {
        final w = w0 * math.pow(1.06, (m - 1) ~/ 12);
        pv += w / math.pow(1 + 0.08 / 12, m - 1);
      }
      expect(r.corpusNeeded, closeTo(pv, pv * 1e-9));
      expect(r.monthly, hasLength(55 * 12));
      expect(r.monthly[359].closingBalance, closeTo(r.corpusNeeded, pv * 1e-9));
      // spending phase ends at ~0 balance
      expect(r.monthly.last.closingBalance.abs(), lessThan(pv * 1e-9));
      expect(r.maturityValue, r.corpusNeeded);
      expect(r.requiredMonthlySip, greaterThan(0));
    });

    test('validation', () {
      expect(
          const RetirementCalculator(
                  currentAge: 60,
                  retirementAge: 50,
                  lifeExpectancy: 85,
                  monthlyExpenseToday: 1,
                  inflationPercent: 6,
                  preRetirementReturnPercent: 10,
                  postRetirementReturnPercent: 7)
              .calculate,
          throwsA(isA<InvalidInputException>()));
    });
  });

  group('CAGR and inflation', () {
    test('CAGR matches Excel RRI', () {
      final r = const CagrCalculator(
              startValue: 100000, endValue: 250000, tenure: Tenure.years(7))
          .calculate();
      expect(r.cagrPercent, closeTo((math.pow(2.5, 1 / 7) - 1) * 100, 1e-9));
      expect(r.cagrPercent, closeTo(14.0, 0.1));
      expect(r.absoluteReturnPercent, closeTo(150, 1e-9));
      expect(r.monthly.last.closingBalance, closeTo(250000, 1e-6));
    });

    test('CAGR negative and total loss', () {
      expect(
          const CagrCalculator(
                  startValue: 100, endValue: 50, tenure: Tenure.years(2))
              .calculate()
              .cagrPercent,
          closeTo(-29.2893, 1e-3));
      expect(
          const CagrCalculator(
                  startValue: 100, endValue: 0, tenure: Tenure.years(2))
              .calculate()
              .cagrPercent,
          -100);
    });

    test('inflation future cost and real value', () {
      final r = const InflationCalculator(
              amount: 100000, inflationPercent: 6, tenure: Tenure.years(20))
          .calculate();
      expect(r.futureCost, closeTo(100000 * math.pow(1.06, 20), 1e-6));
      expect(r.futureCost, closeTo(320713.55, 0.01));
      expect(r.realValue, closeTo(100000 / math.pow(1.06, 20), 1e-6));
      expect(r.monthly.last.closingBalance, closeTo(r.futureCost, 1e-6));
    });
  });

  test('performance: 40-year monthly schedules compute quickly', () {
    final sw = Stopwatch()..start();
    for (var k = 0; k < 50; k++) {
      const SipCalculator(
              monthlyInvestment: 5000,
              annualReturnPercent: 12,
              tenure: Tenure.years(40),
              stepUp: StepUp.percent(5))
          .calculate()
          .yearly;
      const EmiCalculator(
              principal: 5000000,
              annualRatePercent: 9,
              tenure: Tenure.years(40))
          .calculate();
    }
    sw.stop();
    // 100 full schedules of 480 months each.
    expect(sw.elapsedMilliseconds, lessThan(2000));
  });
}
