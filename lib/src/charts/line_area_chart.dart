import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../format/currency_format.dart';
import '../theme/calculator_theme.dart';
import 'chart_data.dart';
import 'chart_utils.dart';
import 'legend.dart';

/// Animated line chart with optional area fill, for growth over time.
/// Hover, tap or drag to see a crosshair and tooltip.
class LineAreaChart extends StatefulWidget {
  /// Creates a line / area chart.
  const LineAreaChart({
    super.key,
    required this.series,
    required this.xLabels,
    this.height = 220,
    this.fill = true,
    this.showLegend = true,
    this.showGrid = true,
    this.showDots = false,
    this.strokeWidth,
    this.axisFormatter,
    this.valueFormatter,
    this.tooltipBuilder,
    this.onPointSelected,
    this.theme,
    this.animate = true,
    this.semanticLabel,
  });

  /// Lines. Series of different length are stretched to the longest.
  final List<LineSeries> series;

  /// Label of each x position (for example the year).
  final List<String> xLabels;

  /// Chart height (the width fills the parent).
  final double height;

  /// Fill the area under each line.
  final bool fill;

  /// Show the legend under the chart.
  final bool showLegend;

  /// Draw grid lines and y labels.
  final bool showGrid;

  /// Draw a dot on every data point.
  final bool showDots;

  /// Line width (defaults to the theme's stroke width).
  final double? strokeWidth;

  /// Formats y axis labels (default: compact).
  final ValueFormatter? axisFormatter;

  /// Formats tooltip values (default: same as [axisFormatter]).
  final ValueFormatter? valueFormatter;

  /// Replaces the tooltip lines for x position `index`.
  final List<String> Function(int index)? tooltipBuilder;

  /// Called when a point is selected (null when cleared).
  final ValueChanged<int?>? onPointSelected;

  /// Theme override.
  final FinanceCalculatorTheme? theme;

  /// Animate changes.
  final bool animate;

  /// Accessibility description.
  final String? semanticLabel;

  @override
  State<LineAreaChart> createState() => _LineAreaChartState();
}

class _LineAreaChartState extends State<LineAreaChart> {
  int? _selected;

  void _select(int? i) {
    if (i == _selected) return;
    setState(() => _selected = i);
    widget.onPointSelected?.call(i);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme ?? FinanceCalculatorTheme.of(context);
    final s = widget.series.length;
    var n = widget.xLabels.length;
    for (final se in widget.series) {
      n = math.max(n, se.values.length);
    }
    final axisFmt = widget.axisFormatter ?? defaultCompact;
    final valFmt = widget.valueFormatter ?? axisFmt;
    final colors = <Color>[
      for (var i = 0; i < s; i++) widget.series[i].color ?? t.seriesColor(i),
    ];
    final flat = <double>[
      for (final se in widget.series)
        ...resample(<double>[for (final v in se.values) safe(v)], n),
    ];
    var lo = 0.0, hi = 0.0;
    for (final v in flat) {
      lo = math.min(lo, v);
      hi = math.max(hi, v);
    }
    final ticks = niceTicks(lo, hi);
    if (_selected != null && _selected! >= n) _selected = null;
    final base = DefaultTextStyle.of(context).style;
    final labelStyle = base
        .merge(t.labelStyle)
        .copyWith(color: t.mutedTextColor, fontSize: 11);
    final labels = <String>[
      for (var i = 0; i < n; i++)
        i < widget.xLabels.length ? widget.xLabels[i] : '',
    ];
    return Semantics(
      label: widget.semanticLabel ?? 'Line chart',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          LayoutBuilder(builder: (context, c) {
            final w = c.maxWidth.isFinite ? c.maxWidth : 300.0;
            final size = Size(w, widget.height);
            final layout = PlotLayout.compute(size, ticks, axisFmt, labelStyle);
            int? hit(Offset p) {
              if (layout == null || n == 0) return null;
              if (n == 1) return 0;
              final f = (p.dx - layout.plot.left) / layout.plot.width;
              return (f * (n - 1)).round().clamp(0, n - 1);
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
                      painter: _LinePainter(
                        layout: layout,
                        values: v,
                        n: n,
                        s: s,
                        labels: labels,
                        colors: colors,
                        selected: _selected,
                        fill: widget.fill,
                        dots: widget.showDots,
                        stroke: widget.strokeWidth ?? t.chartStrokeWidth,
                        grid:
                            widget.showGrid ? t.gridColor : Colors.transparent,
                        showGrid: widget.showGrid,
                        labelStyle: labelStyle,
                        crosshair: t.mutedTextColor,
                        surface: t.surfaceColor,
                        tooltipStyle: base
                            .merge(t.tooltipStyle)
                            .copyWith(color: t.tooltipTextColor),
                        tooltipBg: t.tooltipBackground,
                        tooltipLines: _selected == null
                            ? const <String>[]
                            : (widget.tooltipBuilder?.call(_selected!) ??
                                <String>[
                                  labels[_selected!],
                                  for (var k = 0; k < s; k++)
                                    '${widget.series[k].label}: ${valFmt(flat[k * n + _selected!])}',
                                ]),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
          if (widget.showLegend && s > 0) ...<Widget>[
            const SizedBox(height: 4),
            ChartLegend(items: <LegendItem>[
              for (var i = 0; i < s; i++)
                LegendItem(label: widget.series[i].label, color: colors[i]),
            ], theme: t),
          ],
        ],
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter({
    required this.layout,
    required this.values,
    required this.n,
    required this.s,
    required this.labels,
    required this.colors,
    required this.selected,
    required this.fill,
    required this.dots,
    required this.stroke,
    required this.grid,
    required this.showGrid,
    required this.labelStyle,
    required this.crosshair,
    required this.surface,
    required this.tooltipStyle,
    required this.tooltipBg,
    required this.tooltipLines,
  });

  final PlotLayout? layout;
  final List<double> values;
  final int n, s;
  final List<String> labels;
  final List<Color> colors;
  final int? selected;
  final bool fill, dots, showGrid;
  final double stroke;
  final Color grid, crosshair, surface, tooltipBg;
  final TextStyle labelStyle, tooltipStyle;
  final List<String> tooltipLines;

  @override
  void paint(Canvas canvas, Size size) {
    final l = layout;
    if (l == null || n == 0 || s == 0) return;
    if (showGrid) l.paintGrid(canvas, grid, labelStyle.color ?? Colors.grey);
    double xOf(int i) =>
        n == 1 ? l.plot.center.dx : l.plot.left + i / (n - 1) * l.plot.width;
    final base = l.y(math.max(l.ticks.first, 0.0));
    for (var k = 0; k < s; k++) {
      final color = colors[k];
      final pts = <Offset>[
        for (var i = 0; i < n; i++) Offset(xOf(i), l.y(values[k * n + i])),
      ];
      if (n == 1) {
        canvas.drawCircle(pts.first, stroke * 1.6, Paint()..color = color);
        continue;
      }
      final line = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (var i = 1; i < n; i++) {
        line.lineTo(pts[i].dx, pts[i].dy);
      }
      if (fill) {
        final area = Path.from(line)
          ..lineTo(pts.last.dx, base)
          ..lineTo(pts.first.dx, base)
          ..close();
        canvas.drawPath(
            area,
            Paint()
              ..shader = LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  color.withValues(alpha: 0.28),
                  color.withValues(alpha: 0.0),
                ],
              ).createShader(l.plot));
      }
      canvas.drawPath(
          line,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke
            ..strokeJoin = StrokeJoin.round
            ..strokeCap = StrokeCap.round
            ..isAntiAlias = true);
      if (dots && n <= 60) {
        for (final p in pts) {
          canvas.drawCircle(p, stroke * 0.9, Paint()..color = color);
        }
      }
    }
    l.paintXLabels(canvas, labels, xOf, labelStyle);
    final sel = selected;
    if (sel != null) {
      final x = xOf(sel);
      canvas.drawLine(
          Offset(x, l.plot.top),
          Offset(x, l.plot.bottom),
          Paint()
            ..color = crosshair.withValues(alpha: 0.6)
            ..strokeWidth = 1);
      var top = l.plot.bottom;
      for (var k = 0; k < s; k++) {
        final p = Offset(x, l.y(values[k * n + sel]));
        top = math.min(top, p.dy);
        canvas
          ..drawCircle(p, stroke * 1.8, Paint()..color = surface)
          ..drawCircle(p, stroke * 1.2, Paint()..color = colors[k]);
      }
      if (tooltipLines.isNotEmpty) {
        paintTooltip(canvas, Offset.zero & size, Offset(x, top), tooltipLines,
            background: tooltipBg, style: tooltipStyle);
      }
    }
  }

  @override
  bool shouldRepaint(_LinePainter o) =>
      !listEquals(o.values, values) ||
      o.selected != selected ||
      !listEquals(o.colors, colors) ||
      !listEquals(o.labels, labels) ||
      !listEquals(o.tooltipLines, tooltipLines) ||
      o.fill != fill ||
      o.dots != dots ||
      o.stroke != stroke ||
      o.grid != grid ||
      o.layout?.plot != layout?.plot ||
      !listEquals(o.layout?.ticks, layout?.ticks) ||
      o.labelStyle != labelStyle;
}
