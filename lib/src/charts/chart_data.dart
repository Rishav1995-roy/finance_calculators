import 'package:flutter/painting.dart';

/// One slice of a [DonutChart] or [PieChart].
class ChartSlice {
  /// Creates a slice. A null [color] takes the next theme series color.
  const ChartSlice({required this.label, required this.value, this.color});

  /// Legend text.
  final String label;

  /// Size of the slice (negative and non-finite values count as 0).
  final double value;

  /// Slice color.
  final Color? color;
}

/// One stacked series of a [StackedBarChart].
class BarSeries {
  /// Creates a series with one value per bar.
  const BarSeries({required this.label, required this.values, this.color});

  /// Legend and tooltip text.
  final String label;

  /// Value of this series in each bar.
  final List<double> values;

  /// Segment color (null takes a theme series color).
  final Color? color;
}

/// Data of a [StackedBarChart]: bar [labels] and the stacked [series].
class StackedBarData {
  /// Creates the data. Every series should have `labels.length` values;
  /// missing values count as 0.
  const StackedBarData({required this.labels, required this.series});

  /// Label under each bar (for example the year number).
  final List<String> labels;

  /// Segments, bottom to top.
  final List<BarSeries> series;
}

/// One line of a [LineAreaChart].
class LineSeries {
  /// Creates a line with one value per x position.
  const LineSeries({required this.label, required this.values, this.color});

  /// Legend and tooltip text.
  final String label;

  /// Value at each x position.
  final List<double> values;

  /// Line color (null takes a theme series color).
  final Color? color;
}

/// One entry of a [ChartLegend].
class LegendItem {
  /// Creates a legend entry.
  const LegendItem({required this.label, required this.color, this.valueText});

  /// Name.
  final String label;

  /// Swatch color.
  final Color color;

  /// Optional value shown after the name.
  final String? valueText;
}
