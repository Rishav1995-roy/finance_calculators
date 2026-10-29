import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../format/currency_format.dart';
import '../theme/calculator_theme.dart';
import 'chart_data.dart';
import 'chart_utils.dart';
import 'legend.dart';

/// Index of the slice under [p] in a circle of [side] pixels, or null.
///
/// Slices start at [startAngle] (radians, 0 = 3 o'clock) and run clockwise.
/// [holeRatio] is the empty inner fraction of the radius.
@visibleForTesting
int? sliceIndexAt(Offset p, double side, List<double> values,
    {double holeRatio = 0.62, double startAngle = -math.pi / 2}) {
  final c = Offset(side / 2, side / 2);
  final d = p - c;
  final r = side / 2;
  if (d.distance > r || d.distance < r * holeRatio) return null;
  final total = values.fold<double>(0, (a, v) => a + safePositive(v));
  if (total <= 0) return null;
  var a = math.atan2(d.dy, d.dx) - startAngle;
  a = a % (2 * math.pi);
  if (a < 0) a += 2 * math.pi;
  var acc = 0.0;
  for (var i = 0; i < values.length; i++) {
    acc += safePositive(values[i]) / total * 2 * math.pi;
    if (a <= acc) return safePositive(values[i]) > 0 ? i : null;
  }
  return null;
}

/// An animated donut chart drawn with a `CustomPainter`.
///
/// Tap a slice to highlight it: the slice grows and the center shows its
/// name and value. Pass [centerBuilder] to replace the center completely.
class DonutChart extends StatefulWidget {
  /// Creates a donut chart.
  const DonutChart({
    super.key,
    required this.slices,
    this.holeRatio,
    this.centerLabel,
    this.centerValue,
    this.centerBuilder,
    this.showLegend = true,
    this.legendBuilder,
    this.onSliceTap,
    this.valueFormatter,
    this.theme,
    this.animate = true,
    this.gapDegrees = 2,
    this.startAngle = -math.pi / 2,
    this.size = 180,
    this.semanticLabel,
  });

  /// The slices. Negative or non-finite values count as zero; all zero draws
  /// an empty ring.
  final List<ChartSlice> slices;

  /// Hole size as a fraction of the radius (0 = pie). Defaults to the theme.
  final double? holeRatio;

  /// Small text in the center when nothing is selected.
  final String? centerLabel;

  /// Large text in the center when nothing is selected.
  final String? centerValue;

  /// Replaces the center content. Receives the selected slice index.
  final Widget Function(BuildContext context, int? selectedIndex)?
      centerBuilder;

  /// Show a legend under the chart.
  final bool showLegend;

  /// Replaces the legend.
  final Widget Function(BuildContext context, List<LegendItem> items)?
      legendBuilder;

  /// Called when a slice is tapped (null when the tap hits no slice).
  final ValueChanged<int?>? onSliceTap;

  /// Formats slice values in the legend and center.
  final ValueFormatter? valueFormatter;

  /// Theme override.
  final FinanceCalculatorTheme? theme;

  /// Animate changes.
  final bool animate;

  /// Gap between slices in degrees.
  final double gapDegrees;

  /// Angle of the first slice in radians (default: 12 o'clock).
  final double startAngle;

  /// Preferred diameter (shrinks to the available width).
  final double size;

  /// Accessibility description.
  final String? semanticLabel;

  @override
  State<DonutChart> createState() => _DonutChartState();
}

class _DonutChartState extends State<DonutChart> {
  int? _selected;

  @override
  void didUpdateWidget(DonutChart old) {
    super.didUpdateWidget(old);
    if (_selected != null && _selected! >= widget.slices.length) {
      _selected = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme ?? FinanceCalculatorTheme.of(context);
    final fmt = widget.valueFormatter ?? defaultCompact;
    final hole = (widget.holeRatio ?? t.donutHoleRatio).clamp(0.0, 0.95);
    final colors = <Color>[
      for (var i = 0; i < widget.slices.length; i++)
        widget.slices[i].color ?? t.seriesColor(i),
    ];
    final values = <double>[
      for (final s in widget.slices) safePositive(s.value),
    ];
    final total = values.fold<double>(0, (a, v) => a + v);
    final items = <LegendItem>[
      for (var i = 0; i < widget.slices.length; i++)
        LegendItem(
          label: widget.slices[i].label,
          color: colors[i],
          valueText:
              fmt(widget.slices[i].value.isFinite ? widget.slices[i].value : 0),
        ),
    ];
    return Semantics(
      label: widget.semanticLabel ?? 'Donut chart',
      child: LayoutBuilder(builder: (context, c) {
        final availW = c.maxWidth.isFinite ? c.maxWidth : widget.size;
        const legendReserve = 56.0;
        final showLegend = widget.showLegend &&
            items.isNotEmpty &&
            (!c.maxHeight.isFinite || c.maxHeight >= 80 + legendReserve);
        final availH = c.maxHeight.isFinite
            ? c.maxHeight - (showLegend ? legendReserve : 0)
            : widget.size;
        final side =
            math.max(0.0, math.min(widget.size, math.min(availW, availH)));
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              width: side,
              height: side,
              child: MorphBuilder(
                values: values,
                duration: widget.animate ? t.animationDuration : Duration.zero,
                curve: t.animationCurve,
                builder: (context, v) => GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (d) {
                    final i = sliceIndexAt(d.localPosition, side, values,
                        holeRatio: hole, startAngle: widget.startAngle);
                    setState(() => _selected = i == _selected ? null : i);
                    widget.onSliceTap?.call(_selected);
                  },
                  child: Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      CustomPaint(
                        size: Size(side, side),
                        painter: _SlicePainter(
                          values: v,
                          colors: colors,
                          holeRatio: hole,
                          gap: widget.gapDegrees * math.pi / 180,
                          start: widget.startAngle,
                          selected: _selected,
                          empty: total <= 0,
                          emptyColor: t.gridColor,
                        ),
                      ),
                      if (hole > 0.3 && side > 60)
                        SizedBox(
                          width: side * hole * 0.85,
                          child:
                              widget.centerBuilder?.call(context, _selected) ??
                                  _center(t, fmt),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (showLegend) ...<Widget>[
              const SizedBox(height: 8),
              Flexible(
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: widget.legendBuilder?.call(context, items) ??
                      ChartLegend(
                          items: items,
                          theme: t,
                          selectedIndex: _selected,
                          onTap: (i) => setState(
                              () => _selected = i == _selected ? null : i)),
                ),
              ),
            ],
          ],
        );
      }),
    );
  }

  Widget _center(FinanceCalculatorTheme t, ValueFormatter fmt) {
    final sel = _selected;
    String? small, big;
    if (sel != null && sel < widget.slices.length) {
      small = widget.slices[sel].label;
      big =
          fmt(widget.slices[sel].value.isFinite ? widget.slices[sel].value : 0);
    } else {
      small = widget.centerLabel;
      big = widget.centerValue;
    }
    if (small == null && big == null) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (small != null)
          Text(small,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: t.labelStyle.copyWith(color: t.mutedTextColor)),
        if (big != null)
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(big,
                maxLines: 1,
                style: t.valueStyle.copyWith(color: t.textColor, fontSize: 18)),
          ),
      ],
    );
  }
}

/// An animated pie chart: a [DonutChart] without a hole.
class PieChart extends StatelessWidget {
  /// Creates a pie chart. See [DonutChart] for the parameters.
  const PieChart({
    super.key,
    required this.slices,
    this.showLegend = true,
    this.legendBuilder,
    this.onSliceTap,
    this.valueFormatter,
    this.theme,
    this.animate = true,
    this.gapDegrees = 0,
    this.startAngle = -math.pi / 2,
    this.size = 180,
    this.semanticLabel,
  });

  /// The slices.
  final List<ChartSlice> slices;

  /// Show a legend under the chart.
  final bool showLegend;

  /// Replaces the legend.
  final Widget Function(BuildContext context, List<LegendItem> items)?
      legendBuilder;

  /// Called when a slice is tapped.
  final ValueChanged<int?>? onSliceTap;

  /// Formats slice values in the legend.
  final ValueFormatter? valueFormatter;

  /// Theme override.
  final FinanceCalculatorTheme? theme;

  /// Animate changes.
  final bool animate;

  /// Gap between slices in degrees.
  final double gapDegrees;

  /// Angle of the first slice in radians.
  final double startAngle;

  /// Preferred diameter.
  final double size;

  /// Accessibility description.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => DonutChart(
        slices: slices,
        holeRatio: 0,
        showLegend: showLegend,
        legendBuilder: legendBuilder,
        onSliceTap: onSliceTap,
        valueFormatter: valueFormatter,
        theme: theme,
        animate: animate,
        gapDegrees: gapDegrees,
        startAngle: startAngle,
        size: size,
        semanticLabel: semanticLabel ?? 'Pie chart',
      );
}

class _SlicePainter extends CustomPainter {
  _SlicePainter({
    required this.values,
    required this.colors,
    required this.holeRatio,
    required this.gap,
    required this.start,
    required this.selected,
    required this.empty,
    required this.emptyColor,
  });

  final List<double> values;
  final List<Color> colors;
  final double holeRatio, gap, start;
  final int? selected;
  final bool empty;
  final Color emptyColor;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = math.min(size.width, size.height) / 2 - 4;
    if (r <= 1) return;
    final thickness = r * (1 - holeRatio);
    void arc(double radius, double from, double sweep, Color color) {
      if (holeRatio == 0) {
        canvas.drawArc(
            Rect.fromCircle(center: c, radius: radius),
            from,
            sweep,
            true,
            Paint()
              ..color = color
              ..isAntiAlias = true);
      } else {
        canvas.drawArc(
            Rect.fromCircle(center: c, radius: radius - thickness / 2),
            from,
            sweep,
            false,
            Paint()
              ..color = color
              ..style = PaintingStyle.stroke
              ..strokeWidth = thickness
              ..isAntiAlias = true);
      }
    }

    final total = values.fold<double>(0, (a, v) => a + safePositive(v));
    if (empty || total <= 0) {
      arc(r, 0, 2 * math.pi - 0.0001, emptyColor);
      return;
    }
    final positive = values.where((v) => v > 0).length;
    var a = start;
    for (var i = 0; i < values.length; i++) {
      final v = safePositive(values[i]);
      if (v <= 0) continue;
      final sweep = v / total * 2 * math.pi;
      final g = positive > 1 && sweep > gap * 2 ? gap : 0.0;
      arc(i == selected ? r + 4 : r, a + g / 2, math.max(0.0001, sweep - g),
          colors[i % colors.length]);
      a += sweep;
    }
  }

  @override
  bool shouldRepaint(_SlicePainter o) =>
      !listEquals(o.values, values) ||
      !listEquals(o.colors, colors) ||
      o.selected != selected ||
      o.holeRatio != holeRatio ||
      o.empty != empty ||
      o.emptyColor != emptyColor;
}
