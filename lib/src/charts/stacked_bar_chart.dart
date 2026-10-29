import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../format/currency_format.dart';
import '../theme/calculator_theme.dart';
import 'chart_data.dart';
import 'chart_utils.dart';
import 'legend.dart';

/// Animated stacked bar chart, for example invested vs returns for every
/// year. Hover, tap or drag to see a tooltip.
class StackedBarChart extends StatefulWidget {
  /// Creates a stacked bar chart.
  const StackedBarChart({
    super.key,
    required this.data,
    this.height = 220,
    this.showLegend = true,
    this.showGrid = true,
    this.barRadius = 4,
    this.axisFormatter,
    this.valueFormatter,
    this.tooltipBuilder,
    this.onBarSelected,
    this.theme,
    this.animate = true,
    this.semanticLabel,
  });

  /// Bars and series. Negative or non-finite values count as zero.
  final StackedBarData data;

  /// Chart height (the width fills the parent).
  final double height;

  /// Show the legend under the chart.
  final bool showLegend;

  /// Draw horizontal grid lines and y labels.
  final bool showGrid;

  /// Corner radius of the top of each bar.
  final double barRadius;

  /// Formats y axis labels (default: compact, `1.2K`).
  final ValueFormatter? axisFormatter;

  /// Formats tooltip values (default: same as [axisFormatter]).
  final ValueFormatter? valueFormatter;

  /// Replaces the tooltip lines for bar `index`.
  final List<String> Function(int index)? tooltipBuilder;

  /// Called when a bar is selected (null when cleared).
  final ValueChanged<int?>? onBarSelected;

  /// Theme override.
  final FinanceCalculatorTheme? theme;

  /// Animate changes.
  final bool animate;

  /// Accessibility description.
  final String? semanticLabel;

  @override
  State<StackedBarChart> createState() => _StackedBarChartState();
}

class _StackedBarChartState extends State<StackedBarChart> {
  int? _selected;

  void _select(int? i) {
    if (i == _selected) return;
    setState(() => _selected = i);
    widget.onBarSelected?.call(i);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme ?? FinanceCalculatorTheme.of(context);
    final data = widget.data;
    final n = data.labels.length;
    final s = data.series.length;
    final axisFmt = widget.axisFormatter ?? defaultCompact;
    final valFmt = widget.valueFormatter ?? axisFmt;
    final colors = <Color>[
      for (var i = 0; i < s; i++) data.series[i].color ?? t.seriesColor(i),
    ];
    final flat = <double>[
      for (final se in data.series)
        for (var i = 0; i < n; i++)
          i < se.values.length ? safePositive(se.values[i]) : 0.0,
    ];
    var maxTotal = 0.0;
    for (var i = 0; i < n; i++) {
      var tot = 0.0;
      for (var k = 0; k < s; k++) {
        tot += flat[k * n + i];
      }
      maxTotal = math.max(maxTotal, tot);
    }
    final ticks = niceTicks(0, maxTotal);
    if (_selected != null && _selected! >= n) _selected = null;
    final base = DefaultTextStyle.of(context).style;
    final labelStyle = base
        .merge(t.labelStyle)
        .copyWith(color: t.mutedTextColor, fontSize: 11);
    final legend = <LegendItem>[
      for (var i = 0; i < s; i++)
        LegendItem(label: data.series[i].label, color: colors[i]),
    ];
    return Semantics(
      label: widget.semanticLabel ?? 'Stacked bar chart',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          LayoutBuilder(builder: (context, c) {
            final w = c.maxWidth.isFinite ? c.maxWidth : 300.0;
            final size = Size(w, widget.height);
            final layout = PlotLayout.compute(size, ticks, axisFmt, labelStyle);
            int? hit(Offset p) {
              if (layout == null || n == 0) return null;
              final slot = layout.plot.width / n;
              final i = ((p.dx - layout.plot.left) / slot).floor();
              return i >= 0 && i < n ? i : null;
            }

            return SizedBox(
              width: w,
              height: widget.height,
              child: MouseRegion(
                onHover: (e) => _select(hit(e.localPosition)),
                onExit: (_) => _select(null),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (d) {
                    final i = hit(d.localPosition);
                    _select(i == _selected ? null : i);
                  },
                  onHorizontalDragUpdate: (d) => _select(hit(d.localPosition)),
                  child: MorphBuilder(
                    values: flat,
                    duration:
                        widget.animate ? t.animationDuration : Duration.zero,
                    curve: t.animationCurve,
                    builder: (context, v) => CustomPaint(
                      size: size,
                      painter: _BarPainter(
                        layout: layout,
                        values: v,
                        n: n,
                        s: s,
                        labels: data.labels,
                        colors: colors,
                        selected: _selected,
                        radius: widget.barRadius,
                        grid:
                            widget.showGrid ? t.gridColor : Colors.transparent,
                        labelStyle: labelStyle,
                        tooltipStyle: base
                            .merge(t.tooltipStyle)
                            .copyWith(color: t.tooltipTextColor),
                        tooltipBg: t.tooltipBackground,
                        showGrid: widget.showGrid,
                        tooltipLines: _selected == null
                            ? const <String>[]
                            : (widget.tooltipBuilder?.call(_selected!) ??
                                <String>[
                                  data.labels[_selected!],
                                  for (var k = 0; k < s; k++)
                                    '${data.series[k].label}: ${valFmt(flat[k * n + _selected!])}',
                                ]),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
          if (widget.showLegend && legend.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            ChartLegend(items: legend, theme: t),
          ],
        ],
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  _BarPainter({
    required this.layout,
    required this.values,
    required this.n,
    required this.s,
    required this.labels,
    required this.colors,
    required this.selected,
    required this.radius,
    required this.grid,
    required this.labelStyle,
    required this.tooltipStyle,
    required this.tooltipBg,
    required this.tooltipLines,
    required this.showGrid,
  });

  final PlotLayout? layout;
  final List<double> values;
  final int n, s;
  final List<String> labels;
  final List<Color> colors;
  final int? selected;
  final double radius;
  final Color grid, tooltipBg;
  final TextStyle labelStyle, tooltipStyle;
  final List<String> tooltipLines;
  final bool showGrid;

  @override
  void paint(Canvas canvas, Size size) {
    final l = layout;
    if (l == null || n == 0) return;
    if (showGrid) l.paintGrid(canvas, grid, labelStyle.color ?? Colors.grey);
    final slot = l.plot.width / n;
    final barW = math.max(1.0, math.min(slot * 0.72, 40.0));
    double xc(int i) => l.plot.left + slot * (i + 0.5);
    for (var i = 0; i < n; i++) {
      var cum = 0.0;
      final x = xc(i) - barW / 2;
      final total = <double>[for (var k = 0; k < s; k++) values[k * n + i]]
          .fold<double>(0, (a, b) => a + b);
      if (total <= 0) continue;
      final top = l.y(total);
      final r = math.min(radius, barW / 2);
      canvas
        ..save()
        ..clipRRect(RRect.fromRectAndCorners(
            Rect.fromLTRB(x, top, x + barW, l.plot.bottom),
            topLeft: Radius.circular(r),
            topRight: Radius.circular(r)));
      final dim = selected != null && selected != i;
      for (var k = 0; k < s; k++) {
        final v = values[k * n + i];
        if (v <= 0) continue;
        final y0 = l.y(cum), y1 = l.y(cum + v);
        cum += v;
        canvas.drawRect(
            Rect.fromLTRB(x, y1, x + barW, y0),
            Paint()
              ..color = colors[k].withValues(alpha: dim ? 0.45 : 1)
              ..isAntiAlias = false);
      }
      canvas.restore();
    }
    l.paintXLabels(canvas, labels, xc, labelStyle);
    final sel = selected;
    if (sel != null && tooltipLines.isNotEmpty) {
      var total = 0.0;
      for (var k = 0; k < s; k++) {
        total += values[k * n + sel];
      }
      paintTooltip(
          canvas, Offset.zero & size, Offset(xc(sel), l.y(total)), tooltipLines,
          background: tooltipBg, style: tooltipStyle);
    }
  }

  @override
  bool shouldRepaint(_BarPainter o) =>
      !listEquals(o.values, values) ||
      o.selected != selected ||
      !listEquals(o.colors, colors) ||
      !listEquals(o.labels, labels) ||
      !listEquals(o.tooltipLines, tooltipLines) ||
      o.grid != grid ||
      o.radius != radius ||
      o.layout?.plot != layout?.plot ||
      !listEquals(o.layout?.ticks, layout?.ticks) ||
      o.labelStyle != labelStyle;
}
