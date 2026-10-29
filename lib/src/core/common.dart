import 'dart:math' as math;

/// Thrown when a calculator receives an input it cannot work with.
///
/// [field] names the offending parameter and [message] says what is wrong,
/// for example `InvalidInputException(monthlyInvestment: must be greater
/// than 0)`.
class InvalidInputException implements Exception {
  /// Creates an exception for the input called [field].
  const InvalidInputException(this.field, this.message);

  /// Name of the invalid parameter.
  final String field;

  /// Human readable explanation.
  final String message;

  @override
  String toString() => 'InvalidInputException($field: $message)';
}

/// How often interest is added to the balance.
enum Compounding {
  /// No compounding: simple interest, `P * (1 + r * t)`.
  simple(0),

  /// Once a year.
  yearly(1),

  /// Twice a year.
  halfYearly(2),

  /// Every three months (the usual Indian bank FD / RD convention).
  quarterly(4),

  /// Every month.
  monthly(12),

  /// Every week (52 periods a year).
  weekly(52),

  /// Every day (365 periods a year).
  daily(365);

  const Compounding(this.perYear);

  /// Number of compounding periods per year (`0` for [simple]).
  final int perYear;
}

/// How an annual rate becomes a monthly growth rate.
enum RateConvention {
  /// `annual / 12`. What almost every online SIP calculator does: 12% a year
  /// becomes 1% a month (effective yearly yield is then about 12.68%).
  nominalMonthly,

  /// `(1 + annual)^(1/12) - 1`. Twelve months of growth compound to exactly
  /// the stated annual rate (12% a year -> 0.9489% a month).
  effectiveAnnual,
}

/// Whether a periodic payment happens at the start or the end of the period.
enum PaymentTiming {
  /// Annuity-due: the instalment is invested first, then the month's growth
  /// is earned on it. Gives a slightly higher SIP maturity.
  start,

  /// Ordinary annuity: the instalment lands at month end and earns nothing
  /// that month. Matches Excel `FV(rate, nper, -pmt, 0, 0)`.
  end,
}

/// Length of an investment or loan, stored as whole months.
class Tenure {
  /// A tenure of [years] whole years.
  const Tenure.years(int years) : totalMonths = years * 12;

  /// A tenure of [months] months.
  const Tenure.months(int months) : totalMonths = months;

  /// A tenure of [years] years and [months] months.
  const Tenure.yearsAndMonths(int years, int months)
      : totalMonths = years * 12 + months;

  /// Total number of months.
  final int totalMonths;

  /// Tenure in years (may be fractional).
  double get inYears => totalMonths / 12;

  @override
  bool operator ==(Object other) =>
      other is Tenure && other.totalMonths == totalMonths;

  @override
  int get hashCode => totalMonths.hashCode;

  @override
  String toString() => 'Tenure($totalMonths months)';
}

/// Longest tenure accepted by the calculators (100 years).
const int maxTenureMonths = 1200;

/// Largest annual rate accepted, in percent.
const double maxRatePercent = 100;

// ---------------------------------------------------------------------------
// Validation and small numeric helpers (internal).
// ---------------------------------------------------------------------------

/// Throws unless [v] is finite and greater than zero.
void requirePositive(String field, double v) {
  if (!v.isFinite) {
    throw InvalidInputException(field, 'must be a finite number');
  }
  if (v <= 0) throw InvalidInputException(field, 'must be greater than 0');
}

/// Throws unless [v] is finite and not negative.
void requireNonNegative(String field, double v) {
  if (!v.isFinite) {
    throw InvalidInputException(field, 'must be a finite number');
  }
  if (v < 0) throw InvalidInputException(field, 'must not be negative');
}

/// Throws unless [v] is a finite rate in `[0, maxRatePercent]`.
void requireRate(String field, double v) {
  if (!v.isFinite) {
    throw InvalidInputException(field, 'must be a finite number');
  }
  if (v < 0 || v > maxRatePercent) {
    throw InvalidInputException(
        field, 'must be between 0 and ${maxRatePercent.toInt()} percent');
  }
}

/// Throws unless [t] is between 1 month and [maxTenureMonths].
void requireTenure(String field, Tenure t) {
  if (t.totalMonths < 1 || t.totalMonths > maxTenureMonths) {
    throw InvalidInputException(
        field, 'must be between 1 month and $maxTenureMonths months');
  }
}

/// `base` raised to `exp` as a double.
double pw(double base, double exp) => math.pow(base, exp).toDouble();

/// Monthly growth rate (fraction) for an annual rate in percent.
double monthlyRateFor(double annualPercent, RateConvention c) {
  switch (c) {
    case RateConvention.nominalMonthly:
      return annualPercent / 1200;
    case RateConvention.effectiveAnnual:
      return pw(1 + annualPercent / 100, 1 / 12) - 1;
  }
}

/// Growth factor over [months] months for an annual rate with [c]ompounding.
double compoundFactor(double annualPercent, Compounding c, double months) {
  final r = annualPercent / 100;
  if (c == Compounding.simple) return 1 + r * months / 12;
  final f = c.perYear;
  return pw(1 + r / f, f * months / 12);
}

/// Rounds [v] to [decimals] decimal places (half away from zero).
double roundTo(double v, int decimals) {
  final m = pw(10, decimals.toDouble());
  return (v * m).roundToDouble() / m;
}
