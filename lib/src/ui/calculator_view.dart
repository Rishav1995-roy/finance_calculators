import 'package:flutter/material.dart';

import '../charts/chart_data.dart';
import '../charts/donut_chart.dart';
import '../charts/gauge_chart.dart';
import '../charts/line_area_chart.dart';
import '../charts/stacked_bar_chart.dart';
import '../core/result.dart';
import '../format/currency_format.dart';
import '../theme/calculator_theme.dart';
import 'breakdown_table.dart';
import 'controllers.dart';
import 'input_tile.dart';

/// Chart styles a calculator view can show.
enum CalculatorChartType {
  /// Donut of the main split (invested vs returns).
  donut,

  /// Pie of the main split.
  pie,

  /// Semi-circle gauge of one ratio.
  gauge,

  /// Stacked bars per year.
  bar,

  /// Growth line / area per year.
  line,
}

/// Everything a custom input widget needs.
class CalculatorInputData {
  /// Creates the data.
  const CalculatorInputData({
    required this.input,
    required this.value,
    required this.onChanged,
    required this.format,
    required this.theme,
  });

  /// Definition (label, range, kind).
  final CalculatorInput input;

  /// Current value.
  final double value;

  /// Report a new value.
  final ValueChanged<double> onChanged;

  /// Currency format.
  final CurrencyFormat format;

  /// Resolved theme.
  final FinanceCalculatorTheme theme;
}

/// Everything a custom summary widget needs.
class CalculatorSummaryData {
  /// Creates the data.
  const CalculatorSummaryData({
    required this.result,
    required this.entries,
    required this.formatEntry,
    required this.theme,
  });

  /// The calculation result.
  final CalculatorResult result;

  /// Figures to show.
  final List<SummaryEntry> entries;

  /// Formats an entry's value according to its kind.
  final String Function(SummaryEntry entry) formatEntry;

  /// Resolved theme.
  final FinanceCalculatorTheme theme;
}

/// Everything a custom chart builder needs. Plug in any chart library with
/// [bars], [lines] or [slices], or reuse [defaultChart].
class CalculatorChartData {
  /// Creates the data.
  const CalculatorChartData({
    required this.type,
    required this.result,
    required this.slices,
    required this.bars,
    required this.lines,
    required this.lineLabels,
    required this.gaugeFraction,
    required this.theme,
    required this.format,
    required this.defaultChart,
  });

  /// The chart type the user selected.
  final CalculatorChartType type;

  /// The calculation result (monthly and yearly rows included).
  final CalculatorResult result;

  /// Slices for donut / pie, colored from the theme.
  final List<ChartSlice> slices;

  /// Stacked bar data, one bar per year.
  final StackedBarData bars;

  /// Line series, one point per year.
  final List<LineSeries> lines;

  /// X labels of [lines].
  final List<String> lineLabels;

  /// Gauge fraction between 0 and 1.
  final double gaugeFraction;

  /// Resolved theme.
  final FinanceCalculatorTheme theme;

  /// Currency format in use.
  final CurrencyFormat format;

  /// The built-in chart for [type]; return it to keep the default.
  final Widget defaultChart;
}

/// Everything a custom breakdown builder needs.
class CalculatorBreakdownData {
  /// Creates the data.
  const CalculatorBreakdownData({
    required this.rows,
    required this.monthly,
    required this.columns,
    required this.format,
    required this.theme,
    required this.defaultTable,
  });

  /// Rows being shown (yearly, or monthly when the toggle is on).
  final List<BreakdownRow> rows;

  /// True when [rows] are months.
  final bool monthly;

  /// Value columns for the active calculator.
  final List<BreakdownColumn> columns;

  /// Currency format in use.
  final CurrencyFormat format;

  /// Resolved theme.
  final FinanceCalculatorTheme theme;

  /// The built-in table.
  final Widget defaultTable;
}

/// A complete calculator: sliders and text inputs, a summary card, a chart
/// (with a type switcher) and a breakdown table, driven by a
/// [CalculatorController].
///
/// Every part can be replaced through the `*Builder` arguments and styled
/// through a [FinanceCalculatorTheme]. Use the ready subclasses such as
/// `SipCalculatorView`, or pass any controller to this class directly.
class CalculatorView<R extends CalculatorResult> extends StatefulWidget {
  /// Creates a view for [controller]. When it is null, [createController] must
  /// be given and the view owns the controller it creates.
  const CalculatorView({
    super.key,
    this.controller,
    this.createController,
    this.theme,
    this.format = CurrencyFormat.inr,
    this.valueFormatter,
    this.title,
    this.chartTypes = const <CalculatorChartType>[
      CalculatorChartType.donut,
      CalculatorChartType.bar,
      CalculatorChartType.line,
    ],
    this.initialChartType,
    this.showChartSwitcher = true,
    this.showBreakdown = true,
    this.allowMonthlyBreakdown = true,
    this.inputBuilder,
    this.summaryBuilder,
    this.chartBuilder,
    this.breakdownBuilder,
    this.errorBuilder,
    this.chartTypeLabels,
    this.padding = const EdgeInsets.all(16),
    this.scrollable = true,
    this.onResultChanged,
  }) : assert(controller != null || createController != null);

  /// The controller to drive (you own it).
  final CalculatorController<R>? controller;

  /// Creates a controller the view owns when [controller] is null.
  final CalculatorController<R> Function()? createController;

  /// Theme override (otherwise [FinanceCalculatorTheme.of]).
  final FinanceCalculatorTheme? theme;

  /// Currency format (default: Indian rupee).
  final CurrencyFormat format;

  /// Replaces all money formatting in the view and charts.
  final ValueFormatter? valueFormatter;

  /// Title text. Defaults to the controller's title; empty hides it.
  final String? title;

  /// Chart types offered by the switcher.
  final List<CalculatorChartType> chartTypes;

  /// Chart shown first (default: the first of [chartTypes]).
  final CalculatorChartType? initialChartType;

  /// Show the chart type chips.
  final bool showChartSwitcher;

  /// Show the breakdown table.
  final bool showBreakdown;

  /// Offer a yearly / monthly switch.
  final bool allowMonthlyBreakdown;

  /// Replaces the slider + text field of every input.
  final Widget Function(BuildContext context, CalculatorInputData data)?
      inputBuilder;

  /// Replaces the summary card.
  final Widget Function(BuildContext context, CalculatorSummaryData data)?
      summaryBuilder;

  /// Replaces (or wraps) the chart.
  final Widget Function(BuildContext context, CalculatorChartData data)?
      chartBuilder;

  /// Replaces (or wraps) the breakdown table.
  final Widget Function(BuildContext context, CalculatorBreakdownData data)?
      breakdownBuilder;

  /// Replaces the message shown when inputs are invalid.
  final Widget Function(BuildContext context, String message)? errorBuilder;

  /// Names of the chart chips (for localization).
  final Map<CalculatorChartType, String>? chartTypeLabels;

  /// Padding around the content.
  final EdgeInsetsGeometry padding;

  /// Wrap the content in a `SingleChildScrollView`.
  final bool scrollable;

  /// Called after every recomputation (null result when inputs are invalid).
  final ValueChanged<R?>? onResultChanged;

  @override
  State<CalculatorView<R>> createState() => _CalculatorViewState<R>();
}

class _CalculatorViewState<R extends CalculatorResult>
    extends State<CalculatorView<R>> {
  late CalculatorController<R> _c;
  bool _owned = false;
  late CalculatorChartType _type;
  bool _monthly = false;

  static const Map<CalculatorChartType, String> _defaultLabels =
      <CalculatorChartType, String>{
    CalculatorChartType.donut: 'Donut',
    CalculatorChartType.pie: 'Pie',
    CalculatorChartType.gauge: 'Gauge',
    CalculatorChartType.bar: 'Bar',
    CalculatorChartType.line: 'Line',
  };

  @override
  void initState() {
    super.initState();
    _attach();
    _type = widget.initialChartType ?? widget.chartTypes.first;
  }

  void _attach() {
    _owned = widget.controller == null;
    _c = widget.controller ?? widget.createController!();
    _c.addListener(_changed);
  }

  void _changed() => widget.onResultChanged?.call(_c.result);

  @override
  void didUpdateWidget(CalculatorView<R> old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      _c.removeListener(_changed);
      if (_owned) _c.dispose();
      _attach();
    }
    if (!widget.chartTypes.contains(_type)) _type = widget.chartTypes.first;
  }

  @override
  void dispose() {
    _c.removeListener(_changed);
    if (_owned) _c.dispose();
    super.dispose();
  }

  String _fmt(double v) =>
      widget.valueFormatter?.call(v) ?? widget.format.format(v);

  String _entry(SummaryEntry e) {
    switch (e.kind) {
      case SummaryKind.currency:
        return _fmt(e.value);
      case SummaryKind.percent:
        return '${_trim(e.value)}%';
      case SummaryKind.months:
        final m = e.value.round();
        final y = m ~/ 12, r = m % 12;
        return y == 0 ? '$r mo' : (r == 0 ? '$y yr' : '$y yr $r mo');
      case SummaryKind.number:
        return _trim(e.value);
    }
  }

  static String _trim(double v) {
    final s = v.toStringAsFixed(2);
    return s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme ?? FinanceCalculatorTheme.of(context);
    Widget body = FinanceCalculatorThemeScope(
      theme: t,
      child: ListenableBuilder(
        listenable: _c,
        builder: (context, _) => LayoutBuilder(builder: (context, c) {
          final wide = c.maxWidth >= 720;
          final inputs = _inputsCard(context, t);
          final results = _results(context, t);
          final title = widget.title ?? _c.title;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (title.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(title,
                      style: t.titleStyle.copyWith(color: t.textColor)),
                ),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(flex: 4, child: inputs),
                    const SizedBox(width: 16),
                    Expanded(flex: 6, child: results),
                  ],
                )
              else ...<Widget>[
                inputs,
                const SizedBox(height: 16),
                results,
              ],
            ],
          );
        }),
      ),
    );
    body = Padding(padding: widget.padding, child: body);
    return widget.scrollable ? SingleChildScrollView(child: body) : body;
  }

  Widget _card(FinanceCalculatorTheme t, Widget child) => DecoratedBox(
        decoration: BoxDecoration(
          color: t.surfaceColor,
          borderRadius: BorderRadius.circular(t.cardRadius),
          border: Border.all(color: t.borderColor),
        ),
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      );

  Widget _inputsCard(BuildContext context, FinanceCalculatorTheme t) {
    return _card(
      t,
      Column(
        children: <Widget>[
          for (final i in _c.inputs)
            if (i.visible)
              widget.inputBuilder?.call(
                    context,
                    CalculatorInputData(
                      input: i,
                      value: _c.value(i.id),
                      onChanged: (v) => _c.setValue(i.id, v),
                      format: widget.format,
                      theme: t,
                    ),
                  ) ??
                  CalculatorInputTile(
                    key: ValueKey<String>('input-${i.id}'),
                    input: i,
                    value: _c.value(i.id),
                    onChanged: (v) => _c.setValue(i.id, v),
                    format: widget.format,
                    theme: t,
                  ),
        ],
      ),
    );
  }

  Widget _results(BuildContext context, FinanceCalculatorTheme t) {
    final r = _c.result;
    if (r == null) {
      final msg = _c.error ?? 'Invalid input';
      return widget.errorBuilder?.call(context, msg) ??
          _card(
              t,
              Row(children: <Widget>[
                Icon(Icons.error_outline,
                    color: Theme.of(context).colorScheme.error),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(msg,
                        style: t.labelStyle.copyWith(color: t.textColor))),
              ]));
    }
    final entries = _c.summary(r);
    final summary = widget.summaryBuilder?.call(
          context,
          CalculatorSummaryData(
              result: r, entries: entries, formatEntry: _entry, theme: t),
        ) ??
        _card(t, _DefaultSummary(entries: entries, format: _entry, theme: t));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        summary,
        const SizedBox(height: 16),
        _card(t, _chartSection(context, t, r, entries)),
        if (widget.showBreakdown) ...<Widget>[
          const SizedBox(height: 16),
          _card(t, _breakdownSection(context, t, r)),
        ],
      ],
    );
  }

  Color _sliceColor(FinanceCalculatorTheme t, int i) =>
      <Color>[t.investedColor, t.returnsColor, t.accentColor][i % 3];

  Widget _chartSection(BuildContext context, FinanceCalculatorTheme t, R r,
      List<SummaryEntry> entries) {
    final labels = <CalculatorChartType, String>{
      ..._defaultLabels,
      ...?widget.chartTypeLabels,
    };
    final yearly = r.yearly;
    final slices = <ChartSlice>[
      for (final (i, s) in _c.slices(r).indexed)
        ChartSlice(
            label: s.label,
            value: s.value,
            color: s.color ?? _sliceColor(t, i)),
    ];
    final yl = _c.label('yearShort', 'Y');
    final xLabels = <String>[for (final y in yearly) '$yl${y.period}'];
    final barSeries = _c.barSeries;
    final lineSeries = _c.lineSeries;
    final bars = StackedBarData(labels: xLabels, series: <BarSeries>[
      for (final s in barSeries)
        BarSeries(
            label: s.label,
            color: s.color(t),
            values: <double>[for (final y in yearly) s.valueOf(y)]),
    ]);
    final lines = <LineSeries>[
      for (final s in lineSeries)
        LineSeries(
            label: s.label,
            color: s.color(t),
            values: <double>[for (final y in yearly) s.valueOf(y)]),
    ];
    final axis = widget.valueFormatter ??
        ((double v) => widget.format.copyWith(symbol: '').formatCompact(v));
    final value =
        widget.valueFormatter ?? (double v) => widget.format.format(v);
    SummaryEntry? total;
    for (final e in entries) {
      if (e.id == 'total' || e.id == 'final' || e.id == 'target') total = e;
    }
    final Widget chart;
    switch (_type) {
      case CalculatorChartType.donut:
      case CalculatorChartType.pie:
        chart = DonutChart(
          slices: slices,
          holeRatio: _type == CalculatorChartType.pie ? 0 : null,
          gapDegrees: _type == CalculatorChartType.pie ? 0 : 2,
          centerLabel: total?.label,
          centerValue:
              total == null ? null : widget.format.formatCompact(total.value),
          valueFormatter: value,
          theme: t,
        );
      case CalculatorChartType.gauge:
        final f = _c.gaugeFraction(r);
        chart = GaugeChart(
            value: f * 100,
            label: _c.gaugeLabel,
            startLabel: '0%',
            endLabel: '100%',
            theme: t);
      case CalculatorChartType.bar:
        chart = StackedBarChart(
            data: bars, axisFormatter: axis, valueFormatter: value, theme: t);
      case CalculatorChartType.line:
        chart = LineAreaChart(
            series: lines,
            xLabels: xLabels,
            axisFormatter: axis,
            valueFormatter: value,
            theme: t);
    }
    final data = CalculatorChartData(
      type: _type,
      result: r,
      slices: slices,
      bars: bars,
      lines: lines,
      lineLabels: xLabels,
      gaugeFraction: _c.gaugeFraction(r),
      theme: t,
      format: widget.format,
      defaultChart: chart,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (widget.showChartSwitcher && widget.chartTypes.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: <Widget>[
                for (final ct in widget.chartTypes)
                  ChoiceChip(
                    key: ValueKey<String>('chart-${ct.name}'),
                    label: Text(labels[ct]!),
                    selected: ct == _type,
                    selectedColor: t.returnsColor.withValues(alpha: 0.18),
                    labelStyle: t.labelStyle.copyWith(
                        color: ct == _type ? t.returnsColor : t.textColor,
                        fontWeight:
                            ct == _type ? FontWeight.w700 : FontWeight.w500),
                    side: BorderSide(
                        color: ct == _type ? t.returnsColor : t.borderColor),
                    onSelected: (_) => setState(() => _type = ct),
                  ),
              ],
            ),
          ),
        Center(child: widget.chartBuilder?.call(context, data) ?? chart),
      ],
    );
  }

  Widget _breakdownSection(
      BuildContext context, FinanceCalculatorTheme t, R r) {
    final rows = _monthly ? r.monthly : r.yearly;
    final table = BreakdownTable(
      rows: rows,
      columns: _c.breakdownColumns,
      format: widget.format,
      valueFormatter: widget.valueFormatter,
      periodLabel:
          _c.label(_monthly ? 'month' : 'year', _monthly ? 'Mo' : 'Year'),
      theme: t,
    );
    final data = CalculatorBreakdownData(
      rows: rows,
      monthly: _monthly,
      columns: _c.breakdownColumns,
      format: widget.format,
      theme: t,
      defaultTable: table,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(_c.label('breakdown', 'Breakdown'),
                  style:
                      t.titleStyle.copyWith(color: t.textColor, fontSize: 15)),
            ),
            if (widget.allowMonthlyBreakdown) ...<Widget>[
              Text(_c.label('monthlyToggle', 'Monthly'),
                  style: t.labelStyle.copyWith(color: t.mutedTextColor)),
              Switch(
                key: const ValueKey<String>('monthly-switch'),
                value: _monthly,
                onChanged: (v) => setState(() => _monthly = v),
              ),
            ],
          ],
        ),
        widget.breakdownBuilder?.call(context, data) ?? table,
      ],
    );
  }
}

class _DefaultSummary extends StatelessWidget {
  const _DefaultSummary(
      {required this.entries, required this.format, required this.theme});

  final List<SummaryEntry> entries;
  final String Function(SummaryEntry) format;
  final FinanceCalculatorTheme theme;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    if (entries.isEmpty) return const SizedBox.shrink();
    final head = entries.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(head.label, style: t.labelStyle.copyWith(color: t.mutedTextColor)),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(format(head),
              key: const ValueKey<String>('summary-headline'),
              style:
                  t.valueStyle.copyWith(color: t.returnsColor, fontSize: 30)),
        ),
        const SizedBox(height: 10),
        for (final e in entries.skip(1))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: <Widget>[
                Expanded(
                    child: Text(e.label,
                        style: t.labelStyle.copyWith(color: t.mutedTextColor))),
                Text(format(e),
                    key: ValueKey<String>('summary-${e.id}'),
                    style: t.labelStyle.copyWith(
                        color: t.textColor, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
      ],
    );
  }
}
