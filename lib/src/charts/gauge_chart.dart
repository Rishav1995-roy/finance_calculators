import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/calculator_theme.dart';
import 'chart_utils.dart';

/// A semi-circle gauge, for example "share of the final value that is
/// returns". Animated, themable, with a center text slot.
class GaugeChart extends StatelessWidget {
  /// Creates a gauge.
  const GaugeChart({
    super.key,
    required this.value,
    this.min = 0,
    this.max = 100,
    this.label,
    this.valueText,
    this.thickness = 16,
    this.color,
    this.trackColor,
    this.startLabel,
    this.endLabel,
    this.centerBuilder,
    this.theme,
    this.animate = true,
    this.width = 240,
  });

  /// Current value (clamped to `[min, max]`; NaN counts as [min]).
  final double value;

  /// Value at the left end.
  final double min;

  /// Value at the right end.
  final double max;

  /// Small text under the value.
  final String? label;

  /// Big text in the middle (defaults to the percentage).
  final String? valueText;

  /// Ring thickness in pixels.
  final double thickness;

  /// Progress color (defaults to the theme's returns color).
  final Color? color;

  /// Track color (defaults to the theme grid color).
  final Color? trackColor;

  /// Text under the left end.
  final String? startLabel;

  /// Text under the right end.
  final String? endLabel;

  /// Replaces the center text. Receives the fraction (0 to 1).
  final Widget Function(BuildContext context, double fraction)? centerBuilder;

  /// Theme override.
  final FinanceCalculatorTheme? theme;

  /// Animate changes.
  final bool animate;

  /// Preferred width (shrinks to fit; height is half of it).
  final double width;

  double get _fraction {
    final span = max - min;
    if (!value.isFinite || !span.isFinite || span <= 0) return 0;
    return ((value - min) / span).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final t = theme ?? FinanceCalculatorTheme.of(context);
    final f = _fraction;
    return Semantics(
      label: 'Gauge ${(f * 100).round()} percent',
      child: LayoutBuilder(builder: (context, c) {
        final w = math.max(
            0.0, math.min(width, c.maxWidth.isFinite ? c.maxWidth : width));
        final h = w / 2 + 28;
        return SizedBox(
          width: w,
          height: h,
          child: MorphBuilder(
            values: <double>[f],
            duration: animate ? t.animationDuration : Duration.zero,
            curve: t.animationCurve,
            builder: (context, v) => Stack(
              children: <Widget>[
                CustomPaint(
                  size: Size(w, h),
                  painter: _GaugePainter(
                    fraction: v.first,
                    thickness: math.min(thickness, w / 4),
                    color: color ?? t.returnsColor,
                    track: trackColor ?? t.gridColor,
                    textColor: t.mutedTextColor,
                    style:
                        DefaultTextStyle.of(context).style.merge(t.labelStyle),
                    start: startLabel,
                    end: endLabel,
                  ),
                ),
                if (w > 80)
                  Positioned(
                    left: w * 0.2,
                    right: w * 0.2,
                    bottom: 22,
                    child: centerBuilder?.call(context, v.first) ??
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                  valueText ?? '${(v.first * 100).round()}%',
                                  style: t.valueStyle
                                      .copyWith(color: t.textColor)),
                            ),
                            if (label != null)
                              Text(label!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: t.labelStyle
                                      .copyWith(color: t.mutedTextColor)),
                          ],
                        ),
                  ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({
    required this.fraction,
    required this.thickness,
    required this.color,
    required this.track,
    required this.textColor,
    required this.style,
    this.start,
    this.end,
  });

  final double fraction, thickness;
  final Color color, track, textColor;
  final TextStyle style;
  final String? start, end;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2 - thickness / 2 - 2;
    if (r <= 2) return;
    final center = Offset(size.width / 2, size.width / 2 + 2 - 0);
    final rect = Rect.fromCircle(center: center, radius: r);
    Paint p(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    canvas.drawArc(rect, math.pi, math.pi, false, p(track));
    if (fraction > 0.001) {
      canvas.drawArc(
          rect, math.pi, math.pi * fraction.clamp(0.0, 1.0), false, p(color));
    }
    final s = style.copyWith(color: textColor, fontSize: 11);
    if (start != null) {
      final tp = layoutText(start!, s);
      tp.paint(canvas,
          Offset(center.dx - r - tp.width / 2, center.dy + thickness / 2 + 2));
    }
    if (end != null) {
      final tp = layoutText(end!, s);
      tp.paint(canvas,
          Offset(center.dx + r - tp.width / 2, center.dy + thickness / 2 + 2));
    }
  }

  @override
  bool shouldRepaint(_GaugePainter o) =>
      o.fraction != fraction ||
      o.color != color ||
      o.track != track ||
      o.thickness != thickness ||
      o.start != start ||
      o.end != end;
}
