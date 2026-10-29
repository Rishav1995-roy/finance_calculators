import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Replaces NaN and infinity with 0.
double safe(double v) => v.isFinite ? v : 0;

/// Like [safe], but also clamps negatives to 0.
double safePositive(double v) => v.isFinite && v > 0 ? v : 0;

/// Linearly resamples [a] to [n] values (zeros when [a] is empty).
List<double> resample(List<double> a, int n) {
  if (n <= 0) return const <double>[];
  if (a.isEmpty) return List<double>.filled(n, 0);
  if (a.length == n) return a;
  if (a.length == 1) return List<double>.filled(n, a.first);
  return List<double>.generate(n, (i) {
    final pos = n == 1 ? 0.0 : i * (a.length - 1) / (n - 1);
    final lo = pos.floor();
    final hi = math.min(lo + 1, a.length - 1);
    return a[lo] + (a[hi] - a[lo]) * (pos - lo);
  });
}

/// "Nice" axis tick values covering `[min, max]` with about [count] steps.
///
/// Always returns at least two finite values, in ascending order, even for
/// empty ranges, zeros, negative or huge input.
List<double> niceTicks(double min, double max, {int count = 4}) {
  var lo = safe(min), hi = safe(max);
  if (hi < lo) {
    final t = lo;
    lo = hi;
    hi = t;
  }
  if (hi == lo) {
    if (hi == 0) return const <double>[0, 1];
    hi = lo + lo.abs();
    lo = lo > 0 ? 0 : lo;
  }
  final rough = (hi - lo) / math.max(1, count);
  final mag = math.pow(10, (math.log(rough) / math.ln10).floor()).toDouble();
  final norm = rough / mag;
  final step = (norm <= 1
          ? 1
          : norm <= 2
              ? 2
              : norm <= 5
                  ? 5
                  : 10) *
      mag;
  final start = (lo / step).floor() * step;
  final ticks = <double>[];
  for (var v = start; ticks.length < 64; v += step) {
    ticks.add(v);
    if (v >= hi - step * 1e-9) break;
  }
  return ticks.length < 2 ? <double>[start, start + step] : ticks;
}

/// Builds a [TextPainter] laid out for [text].
TextPainter layoutText(String text, TextStyle style,
    {double maxWidth = double.infinity, TextAlign align = TextAlign.left}) {
  return TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    textAlign: align,
    maxLines: 1,
    ellipsis: '…',
  )..layout(maxWidth: maxWidth);
}

/// Draws a rounded tooltip with [lines] near [anchor], kept inside [bounds].
void paintTooltip(
  Canvas canvas,
  Rect bounds,
  Offset anchor,
  List<String> lines, {
  required Color background,
  required TextStyle style,
  double radius = 8,
}) {
  if (lines.isEmpty) return;
  final painters = <TextPainter>[
    for (final l in lines) layoutText(l, style, maxWidth: bounds.width - 16),
  ];
  var w = 0.0, h = 0.0;
  for (final p in painters) {
    w = math.max(w, p.width);
    h += p.height;
  }
  w += 16;
  h += 12;
  var left = anchor.dx - w / 2;
  var top = anchor.dy - h - 10;
  if (top < bounds.top) top = anchor.dy + 14;
  left = left.clamp(bounds.left, math.max(bounds.left, bounds.right - w));
  top = top.clamp(bounds.top, math.max(bounds.top, bounds.bottom - h));
  canvas.drawRRect(
    RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, w, h), Radius.circular(radius)),
    Paint()..color = background,
  );
  var y = top + 6;
  for (final p in painters) {
    p.paint(canvas, Offset(left + 8, y));
    y += p.height;
  }
}

/// Animates a list of numbers towards new targets.
///
/// Whenever [values] change the builder receives values that glide from the
/// current picture to the new one. With a zero [duration] the target is used
/// directly. On first build the values grow from zero.
class MorphBuilder extends StatefulWidget {
  /// Creates a morph builder.
  const MorphBuilder({
    super.key,
    required this.values,
    required this.duration,
    required this.curve,
    required this.builder,
  });

  /// Target values.
  final List<double> values;

  /// Animation length.
  final Duration duration;

  /// Easing.
  final Curve curve;

  /// Builds the chart from the current interpolated values.
  final Widget Function(BuildContext context, List<double> values) builder;

  @override
  State<MorphBuilder> createState() => _MorphBuilderState();
}

class _MorphBuilderState extends State<MorphBuilder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.duration);
  late List<double> _from;
  late List<double> _to;

  List<double> _current() {
    final t = widget.curve.transform(_c.value);
    if (t >= 1) return _to;
    final a = resample(_from, _to.length);
    return List<double>.generate(_to.length, (i) => a[i] + (_to[i] - a[i]) * t);
  }

  @override
  void initState() {
    super.initState();
    _to = widget.values;
    _from = List<double>.filled(_to.length, 0);
    if (widget.duration == Duration.zero) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  @override
  void didUpdateWidget(MorphBuilder old) {
    super.didUpdateWidget(old);
    _c.duration = widget.duration;
    if (!listEquals(old.values, widget.values)) {
      _from = _current();
      _to = widget.values;
      if (widget.duration == Duration.zero) {
        _c.value = 1;
      } else {
        _c.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, _) => widget.builder(context, _current()),
      );
}

/// Plot rectangle and y axis labels shared by bar and line charts.
class PlotLayout {
  PlotLayout._(this.plot, this.ticks, this.tickPainters);

  /// Area that holds the data.
  final Rect plot;

  /// Y axis tick values, ascending.
  final List<double> ticks;

  /// Laid out tick labels (same order as [ticks]).
  final List<TextPainter> tickPainters;

  /// Computes the layout, or null when [size] is too small to draw anything.
  static PlotLayout? compute(Size size, List<double> ticks,
      String Function(double) fmt, TextStyle style,
      {double bottomPad = 22}) {
    final painters = <TextPainter>[
      for (final t in ticks) layoutText(fmt(t), style),
    ];
    var w = 0.0;
    for (final p in painters) {
      w = math.max(w, p.width);
    }
    final left = math.min(w + 8, size.width * 0.4);
    final plot =
        Rect.fromLTRB(left, 8, size.width - 8, size.height - bottomPad);
    if (plot.width < 4 || plot.height < 4) return null;
    return PlotLayout._(plot, ticks, painters);
  }

  /// Y pixel of value [v].
  double y(double v) {
    final lo = ticks.first, hi = ticks.last;
    final f = hi == lo ? 0.0 : (v - lo) / (hi - lo);
    return plot.bottom - f * plot.height;
  }

  /// Draws grid lines and y labels.
  void paintGrid(Canvas canvas, Color grid, Color text) {
    final paint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var i = 0; i < ticks.length; i++) {
      final yy = y(ticks[i]);
      canvas.drawLine(Offset(plot.left, yy), Offset(plot.right, yy), paint);
      final p = tickPainters[i];
      p.paint(canvas, Offset(plot.left - 6 - p.width, yy - p.height / 2));
    }
  }

  /// Draws x labels under the plot, skipping labels so they never overlap.
  void paintXLabels(Canvas canvas, List<String> labels,
      double Function(int) xOf, TextStyle style) {
    if (labels.isEmpty) return;
    var every = 1;
    final probe = layoutText(
        labels.reduce((a, b) => a.length >= b.length ? a : b), style);
    final slot =
        labels.length == 1 ? plot.width : plot.width / (labels.length - 1);
    while (slot * every < probe.width + 8 && every < labels.length) {
      every++;
    }
    for (var i = 0; i < labels.length; i += every) {
      final p = layoutText(labels[i], style);
      final x = (xOf(i) - p.width / 2)
          .clamp(
              plot.left - 4, math.max(plot.left - 4, plot.right - p.width + 4))
          .toDouble();
      p.paint(canvas, Offset(x, plot.bottom + 5));
    }
  }
}

/// Default compact axis formatter: `1.2K`, `3.5M`.
String defaultCompact(double v) {
  if (!v.isFinite) return '–';
  final a = v.abs();
  const units = <List<Object>>[
    <Object>[1e12, 'T'],
    <Object>[1e9, 'B'],
    <Object>[1e6, 'M'],
    <Object>[1e3, 'K'],
  ];
  for (final u in units) {
    if (a >= (u[0] as double)) {
      var s = (v / (u[0] as double)).toStringAsFixed(1);
      if (s.endsWith('.0')) s = s.substring(0, s.length - 2);
      return '$s${u[1]}';
    }
  }
  return v.toStringAsFixed(a < 10 && a != a.roundToDouble() ? 1 : 0);
}
