import 'package:flutter/material.dart';

import '../theme/calculator_theme.dart';
import 'chart_data.dart';

/// Color swatches with names (and optional values) for a chart.
class ChartLegend extends StatelessWidget {
  /// Creates a legend.
  const ChartLegend({
    super.key,
    required this.items,
    this.theme,
    this.direction = Axis.horizontal,
    this.onTap,
    this.selectedIndex,
  });

  /// Entries to show.
  final List<LegendItem> items;

  /// Theme override.
  final FinanceCalculatorTheme? theme;

  /// Lay entries in a row (wrapping) or a column.
  final Axis direction;

  /// Called with the index of a tapped entry.
  final ValueChanged<int>? onTap;

  /// Entry drawn bold, if any.
  final int? selectedIndex;

  @override
  Widget build(BuildContext context) {
    final t = theme ?? FinanceCalculatorTheme.of(context);
    final children = <Widget>[
      for (var i = 0; i < items.length; i++)
        InkWell(
          onTap: onTap == null ? null : () => onTap!(i),
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                      color: items[i].color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    items[i].valueText == null
                        ? items[i].label
                        : '${items[i].label}  ${items[i].valueText}',
                    overflow: TextOverflow.ellipsis,
                    style: t.labelStyle.copyWith(
                      color: t.textColor,
                      fontWeight: selectedIndex == i
                          ? FontWeight.w700
                          : t.labelStyle.fontWeight,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
    ];
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth.isFinite && c.maxWidth < 48) {
        return const SizedBox.shrink();
      }
      return _layout(children);
    });
  }

  Widget _layout(List<Widget> children) {
    return direction == Axis.horizontal
        ? Wrap(alignment: WrapAlignment.center, children: children)
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children);
  }
}
