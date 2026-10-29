/// One period (a month or a year) of a calculation.
///
/// The same shape is used by every calculator so charts and tables can work
/// with any result. For loans ([invested] is principal repaid and [returns]
/// is interest paid).
class BreakdownRow {
  /// Creates a row. All amounts are plain doubles in the caller's currency.
  const BreakdownRow({
    required this.period,
    required this.openingBalance,
    required this.invested,
    required this.returns,
    required this.withdrawn,
    required this.closingBalance,
    required this.cumulativeInvested,
    required this.cumulativeReturns,
    required this.cumulativeWithdrawn,
  });

  /// 1-based month or year number.
  final int period;

  /// Balance at the start of the period.
  final double openingBalance;

  /// Money put in during the period (loans: principal repaid).
  final double invested;

  /// Growth earned during the period (loans: interest paid).
  final double returns;

  /// Money taken out during the period (SWP withdrawals, retirement spending).
  final double withdrawn;

  /// Balance at the end of the period (loans: outstanding principal).
  final double closingBalance;

  /// Total put in up to and including this period.
  final double cumulativeInvested;

  /// Total growth up to and including this period.
  final double cumulativeReturns;

  /// Total taken out up to and including this period.
  final double cumulativeWithdrawn;

  /// A JSON friendly map.
  Map<String, Object?> toJson() => <String, Object?>{
        'period': period,
        'openingBalance': openingBalance,
        'invested': invested,
        'returns': returns,
        'withdrawn': withdrawn,
        'closingBalance': closingBalance,
        'cumulativeInvested': cumulativeInvested,
        'cumulativeReturns': cumulativeReturns,
        'cumulativeWithdrawn': cumulativeWithdrawn,
      };
}

/// Groups monthly rows into years (the last year may be partial).
List<BreakdownRow> aggregateYearly(List<BreakdownRow> monthly) {
  final out = <BreakdownRow>[];
  for (var i = 0; i < monthly.length; i += 12) {
    final end = i + 12 < monthly.length ? i + 12 : monthly.length;
    var inv = 0.0, ret = 0.0, wd = 0.0;
    for (var j = i; j < end; j++) {
      inv += monthly[j].invested;
      ret += monthly[j].returns;
      wd += monthly[j].withdrawn;
    }
    final last = monthly[end - 1];
    out.add(BreakdownRow(
      period: i ~/ 12 + 1,
      openingBalance: monthly[i].openingBalance,
      invested: inv,
      returns: ret,
      withdrawn: wd,
      closingBalance: last.closingBalance,
      cumulativeInvested: last.cumulativeInvested,
      cumulativeReturns: last.cumulativeReturns,
      cumulativeWithdrawn: last.cumulativeWithdrawn,
    ));
  }
  return List<BreakdownRow>.unmodifiable(out);
}

/// Common shape of every calculator result: three headline totals and a
/// month-by-month plus year-by-year breakdown, all immutable.
abstract class CalculatorResult {
  /// Creates a result from its [monthly] rows.
  CalculatorResult(List<BreakdownRow> monthly)
      : monthly = List<BreakdownRow>.unmodifiable(monthly);

  /// Month-by-month rows.
  final List<BreakdownRow> monthly;

  /// Year-by-year rows (computed once from [monthly]).
  late final List<BreakdownRow> yearly = aggregateYearly(monthly);

  /// Total money put in (loans: principal).
  double get investedAmount;

  /// Total growth (loans: total interest).
  double get estimatedReturns;

  /// Final value (loans: total payment, SWP: remaining balance).
  double get maturityValue;

  /// Number of months covered by [monthly].
  int get totalMonths => monthly.length;

  /// JSON friendly map. Monthly rows are included only when
  /// [includeMonthly] is true.
  Map<String, Object?> toJson({bool includeMonthly = false}) =>
      <String, Object?>{
        'investedAmount': investedAmount,
        'estimatedReturns': estimatedReturns,
        'maturityValue': maturityValue,
        'totalMonths': totalMonths,
        'yearly': yearly.map((r) => r.toJson()).toList(),
        if (includeMonthly) 'monthly': monthly.map((r) => r.toJson()).toList(),
      };
}

/// Builds a [BreakdownRow] list from simple per-month numbers.
class RowBuilder {
  double _cumInv = 0, _cumWd = 0;

  /// Appends a month and returns the row. Cumulative returns follow from
  /// `closing + cumulativeWithdrawn - cumulativeInvested`.
  BreakdownRow add({
    required int period,
    required double opening,
    required double invested,
    required double returns,
    required double withdrawn,
    required double closing,
  }) {
    _cumInv += invested;
    _cumWd += withdrawn;
    return BreakdownRow(
      period: period,
      openingBalance: opening,
      invested: invested,
      returns: returns,
      withdrawn: withdrawn,
      closingBalance: closing,
      cumulativeInvested: _cumInv,
      cumulativeReturns: closing + _cumWd - _cumInv,
      cumulativeWithdrawn: _cumWd,
    );
  }
}
