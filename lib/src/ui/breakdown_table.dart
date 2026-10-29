import 'package:flutter/material.dart';

import '../core/result.dart';
import '../format/currency_format.dart';
import '../theme/calculator_theme.dart';
import 'controllers.dart';

/// A scrollable table of [BreakdownRow]s (years or months) with a period
/// column and one column per [BreakdownColumn]. Rows are built lazily, so
/// long monthly schedules stay fast.
class BreakdownTable extends StatelessWidget {
  /// Creates a table.
  const BreakdownTable({
    super.key,
    required this.rows,
    required this.columns,
    this.format = CurrencyFormat.inr,
    this.valueFormatter,
    this.periodLabel = 'Year',
    this.maxHeight = 320,
    this.rowHeight = 40,
    this.theme,
  });

  /// Rows to show.
  final List<BreakdownRow> rows;

  /// Value columns.
  final List<BreakdownColumn> columns;

  /// Money format used when [valueFormatter] is null.
  final CurrencyFormat format;

  /// Replaces the number formatting.
  final ValueFormatter? valueFormatter;

  /// Header of the first column.
  final String periodLabel;

  /// The table scrolls when taller than this.
  final double maxHeight;

  /// Height of one row.
  final double rowHeight;

  /// Theme override.
  final FinanceCalculatorTheme? theme;

  @override
  Widget build(BuildContext context) {
    final t = theme ?? FinanceCalculatorTheme.of(context);
    final fmt = valueFormatter ?? (double v) => format.format(v);
    final head = t.labelStyle
        .copyWith(color: t.mutedTextColor, fontWeight: FontWeight.w700);
    final cell = t.labelStyle.copyWith(color: t.textColor);
    Widget rowOf(List<String> cells, TextStyle style, {Color? bg}) => Container(
          height: rowHeight,
          color: bg,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: <Widget>[
              SizedBox(width: 44, child: Text(cells.first, style: style)),
              for (final c in cells.skip(1))
                Expanded(
                  child: Text(c,
                      textAlign: TextAlign.end,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: style),
                ),
            ],
          ),
        );
    final height = (rows.length * rowHeight).clamp(0.0, maxHeight).toDouble();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        rowOf(<String>[periodLabel, for (final c in columns) c.label], head),
        Divider(height: 1, color: t.borderColor),
        SizedBox(
          height: height,
          child: ListView.builder(
            itemCount: rows.length,
            itemExtent: rowHeight,
            itemBuilder: (context, i) {
              final r = rows[i];
              return rowOf(
                <String>[
                  '${r.period}',
                  for (final c in columns) fmt(c.valueOf(r)),
                ],
                cell,
                bg: i.isOdd ? t.borderColor.withValues(alpha: 0.25) : null,
              );
            },
          ),
        ),
      ],
    );
  }
}
