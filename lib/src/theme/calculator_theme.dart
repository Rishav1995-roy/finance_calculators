import 'package:flutter/material.dart';

/// Colors, text styles and motion for every calculator view and chart.
///
/// Register it once in `ThemeData(extensions: [...])`, scope it with
/// [FinanceCalculatorThemeScope] or pass it to a view's `theme` argument.
/// Without any of these a theme is derived from the app's [ColorScheme], so
/// light and dark work out of the box.
@immutable
class FinanceCalculatorTheme extends ThemeExtension<FinanceCalculatorTheme> {
  /// Creates a theme from explicit values.
  const FinanceCalculatorTheme({
    required this.investedColor,
    required this.returnsColor,
    required this.accentColor,
    required this.seriesColors,
    required this.surfaceColor,
    required this.borderColor,
    required this.textColor,
    required this.mutedTextColor,
    required this.gridColor,
    required this.tooltipBackground,
    required this.tooltipTextColor,
    this.cardRadius = 16,
    this.chartStrokeWidth = 2.5,
    this.donutHoleRatio = 0.62,
    this.titleStyle =
        const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
    this.valueStyle =
        const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
    this.labelStyle =
        const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
    this.tooltipStyle =
        const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
    this.animationDuration = const Duration(milliseconds: 600),
    this.animationCurve = Curves.easeOutCubic,
  });

  /// Light preset (indigo and teal).
  const FinanceCalculatorTheme.light()
      : this(
          investedColor: const Color(0xFFC7D2FE),
          returnsColor: const Color(0xFF4F46E5),
          accentColor: const Color(0xFF0D9488),
          seriesColors: const <Color>[
            Color(0xFF4F46E5),
            Color(0xFF0D9488),
            Color(0xFFF59E0B),
            Color(0xFFEC4899),
            Color(0xFF0EA5E9),
          ],
          surfaceColor: Colors.white,
          borderColor: const Color(0xFFE2E8F0),
          textColor: const Color(0xFF0F172A),
          mutedTextColor: const Color(0xFF64748B),
          gridColor: const Color(0xFFE2E8F0),
          tooltipBackground: const Color(0xE60F172A),
          tooltipTextColor: Colors.white,
        );

  /// Dark preset.
  const FinanceCalculatorTheme.dark()
      : this(
          investedColor: const Color(0xFF475569),
          returnsColor: const Color(0xFF818CF8),
          accentColor: const Color(0xFF2DD4BF),
          seriesColors: const <Color>[
            Color(0xFF818CF8),
            Color(0xFF2DD4BF),
            Color(0xFFFBBF24),
            Color(0xFFF472B6),
            Color(0xFF38BDF8),
          ],
          surfaceColor: const Color(0xFF1E293B),
          borderColor: const Color(0xFF334155),
          textColor: const Color(0xFFF1F5F9),
          mutedTextColor: const Color(0xFF94A3B8),
          gridColor: const Color(0xFF334155),
          tooltipBackground: const Color(0xF2F1F5F9),
          tooltipTextColor: const Color(0xFF0F172A),
        );

  /// Derives a theme from [scheme] (primary for returns, tertiary as accent).
  factory FinanceCalculatorTheme.fromColorScheme(ColorScheme scheme) {
    final dark = scheme.brightness == Brightness.dark;
    final base = dark
        ? const FinanceCalculatorTheme.dark()
        : const FinanceCalculatorTheme.light();
    return base.copyWith(
      investedColor: Color.alphaBlend(
          scheme.primary.withValues(alpha: dark ? 0.35 : 0.28), scheme.surface),
      returnsColor: scheme.primary,
      accentColor: scheme.tertiary,
      seriesColors: <Color>[
        scheme.primary,
        scheme.tertiary,
        scheme.secondary,
        scheme.error,
        ...base.seriesColors.skip(4),
      ],
      surfaceColor: scheme.surfaceContainerLow,
      borderColor: scheme.outlineVariant,
      textColor: scheme.onSurface,
      mutedTextColor: scheme.onSurfaceVariant,
      gridColor: scheme.outlineVariant,
      tooltipBackground: scheme.inverseSurface.withValues(alpha: 0.92),
      tooltipTextColor: scheme.onInverseSurface,
    );
  }

  /// Color of invested money / principal.
  final Color investedColor;

  /// Color of returns / interest.
  final Color returnsColor;

  /// Third color (for example the final value, or a gauge).
  final Color accentColor;

  /// Colors used for slices and series that do not set their own.
  final List<Color> seriesColors;

  /// Card background.
  final Color surfaceColor;

  /// Card and divider border.
  final Color borderColor;

  /// Main text color.
  final Color textColor;

  /// Secondary text color.
  final Color mutedTextColor;

  /// Chart grid lines.
  final Color gridColor;

  /// Chart tooltip background.
  final Color tooltipBackground;

  /// Chart tooltip text color.
  final Color tooltipTextColor;

  /// Corner radius of cards.
  final double cardRadius;

  /// Stroke width of chart lines.
  final double chartStrokeWidth;

  /// Hole size of a donut as a fraction of its radius (0 = pie).
  final double donutHoleRatio;

  /// Style of titles.
  final TextStyle titleStyle;

  /// Style of big numbers.
  final TextStyle valueStyle;

  /// Style of labels, legends and axes.
  final TextStyle labelStyle;

  /// Style of tooltip text.
  final TextStyle tooltipStyle;

  /// Length of chart animations (`Duration.zero` turns them off).
  final Duration animationDuration;

  /// Easing of chart animations.
  final Curve animationCurve;

  /// Color number [i] of [seriesColors] (wraps around).
  Color seriesColor(int i) => seriesColors[i % seriesColors.length];

  /// Resolves the theme for [context]: nearest
  /// [FinanceCalculatorThemeScope], else the `ThemeData` extension, else one
  /// derived from the color scheme.
  static FinanceCalculatorTheme of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<FinanceCalculatorThemeScope>();
    if (scope != null) return scope.theme;
    final t = Theme.of(context);
    return t.extension<FinanceCalculatorTheme>() ??
        FinanceCalculatorTheme.fromColorScheme(t.colorScheme);
  }

  @override
  FinanceCalculatorTheme copyWith({
    Color? investedColor,
    Color? returnsColor,
    Color? accentColor,
    List<Color>? seriesColors,
    Color? surfaceColor,
    Color? borderColor,
    Color? textColor,
    Color? mutedTextColor,
    Color? gridColor,
    Color? tooltipBackground,
    Color? tooltipTextColor,
    double? cardRadius,
    double? chartStrokeWidth,
    double? donutHoleRatio,
    TextStyle? titleStyle,
    TextStyle? valueStyle,
    TextStyle? labelStyle,
    TextStyle? tooltipStyle,
    Duration? animationDuration,
    Curve? animationCurve,
  }) =>
      FinanceCalculatorTheme(
        investedColor: investedColor ?? this.investedColor,
        returnsColor: returnsColor ?? this.returnsColor,
        accentColor: accentColor ?? this.accentColor,
        seriesColors: seriesColors ?? this.seriesColors,
        surfaceColor: surfaceColor ?? this.surfaceColor,
        borderColor: borderColor ?? this.borderColor,
        textColor: textColor ?? this.textColor,
        mutedTextColor: mutedTextColor ?? this.mutedTextColor,
        gridColor: gridColor ?? this.gridColor,
        tooltipBackground: tooltipBackground ?? this.tooltipBackground,
        tooltipTextColor: tooltipTextColor ?? this.tooltipTextColor,
        cardRadius: cardRadius ?? this.cardRadius,
        chartStrokeWidth: chartStrokeWidth ?? this.chartStrokeWidth,
        donutHoleRatio: donutHoleRatio ?? this.donutHoleRatio,
        titleStyle: titleStyle ?? this.titleStyle,
        valueStyle: valueStyle ?? this.valueStyle,
        labelStyle: labelStyle ?? this.labelStyle,
        tooltipStyle: tooltipStyle ?? this.tooltipStyle,
        animationDuration: animationDuration ?? this.animationDuration,
        animationCurve: animationCurve ?? this.animationCurve,
      );

  @override
  FinanceCalculatorTheme lerp(
      ThemeExtension<FinanceCalculatorTheme>? other, double t) {
    if (other is! FinanceCalculatorTheme) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return FinanceCalculatorTheme(
      investedColor: c(investedColor, other.investedColor),
      returnsColor: c(returnsColor, other.returnsColor),
      accentColor: c(accentColor, other.accentColor),
      seriesColors: <Color>[
        for (var i = 0; i < seriesColors.length; i++)
          c(seriesColors[i], other.seriesColor(i)),
      ],
      surfaceColor: c(surfaceColor, other.surfaceColor),
      borderColor: c(borderColor, other.borderColor),
      textColor: c(textColor, other.textColor),
      mutedTextColor: c(mutedTextColor, other.mutedTextColor),
      gridColor: c(gridColor, other.gridColor),
      tooltipBackground: c(tooltipBackground, other.tooltipBackground),
      tooltipTextColor: c(tooltipTextColor, other.tooltipTextColor),
      cardRadius: cardRadius + (other.cardRadius - cardRadius) * t,
      chartStrokeWidth:
          chartStrokeWidth + (other.chartStrokeWidth - chartStrokeWidth) * t,
      donutHoleRatio:
          donutHoleRatio + (other.donutHoleRatio - donutHoleRatio) * t,
      titleStyle: TextStyle.lerp(titleStyle, other.titleStyle, t)!,
      valueStyle: TextStyle.lerp(valueStyle, other.valueStyle, t)!,
      labelStyle: TextStyle.lerp(labelStyle, other.labelStyle, t)!,
      tooltipStyle: TextStyle.lerp(tooltipStyle, other.tooltipStyle, t)!,
      animationDuration: t < 0.5 ? animationDuration : other.animationDuration,
      animationCurve: t < 0.5 ? animationCurve : other.animationCurve,
    );
  }
}

/// Applies a [FinanceCalculatorTheme] to everything below it, without
/// touching `ThemeData`.
class FinanceCalculatorThemeScope extends InheritedWidget {
  /// Creates a scope.
  const FinanceCalculatorThemeScope(
      {super.key, required this.theme, required super.child});

  /// The theme for descendants.
  final FinanceCalculatorTheme theme;

  @override
  bool updateShouldNotify(FinanceCalculatorThemeScope oldWidget) =>
      theme != oldWidget.theme;
}
