/// Turns a number into display text. Used for every value the views show.
typedef ValueFormatter = String Function(double value);

/// Digit grouping style.
enum DigitGrouping {
  /// 1,234,567 (groups of three).
  international,

  /// 12,34,567 (last three digits, then groups of two: lakh / crore).
  indian,

  /// 1234567.
  none,
}

/// A unit used by [CurrencyFormat.formatCompact], for example `L` for lakh.
class CompactUnit {
  /// A unit that starts at [threshold] and is written with [suffix].
  const CompactUnit(this.threshold, this.suffix);

  /// Smallest absolute value that uses this unit.
  final double threshold;

  /// Text appended after the scaled number (include a leading space if wanted).
  final String suffix;
}

/// Locale-free money formatting (no `intl` needed).
///
/// Presets: [inr] (₹, lakh/crore grouping), [usd], [eur] and [eurEuropean]
/// (`1.234,56 €`). Everything is overridable with [copyWith], and a view
/// accepts a plain `String Function(double)` hook for full control.
class CurrencyFormat {
  /// Creates a format.
  const CurrencyFormat({
    this.symbol = '',
    this.symbolAfter = false,
    this.grouping = DigitGrouping.international,
    this.decimals = 0,
    this.groupSeparator = ',',
    this.decimalSeparator = '.',
    this.compactUnits = _internationalUnits,
    this.spaceAfterSymbol = false,
  });

  /// Indian rupee with lakh / crore grouping: `₹12,34,567`.
  static const CurrencyFormat inr = CurrencyFormat(
    symbol: '₹',
    grouping: DigitGrouping.indian,
    compactUnits: _indianUnits,
  );

  /// US dollar: `$1,234,567`.
  static const CurrencyFormat usd = CurrencyFormat(symbol: r'$');

  /// Euro, English style: `€1,234,567`.
  static const CurrencyFormat eur = CurrencyFormat(symbol: '€');

  /// Euro, continental style: `1.234.567 €`.
  static const CurrencyFormat eurEuropean = CurrencyFormat(
    symbol: '€',
    symbolAfter: true,
    spaceAfterSymbol: true,
    groupSeparator: '.',
    decimalSeparator: ',',
  );

  /// Plain numbers with no symbol.
  static const CurrencyFormat plain = CurrencyFormat();

  static const List<CompactUnit> _internationalUnits = <CompactUnit>[
    CompactUnit(1e3, 'K'),
    CompactUnit(1e6, 'M'),
    CompactUnit(1e9, 'B'),
    CompactUnit(1e12, 'T'),
  ];

  static const List<CompactUnit> _indianUnits = <CompactUnit>[
    CompactUnit(1e3, 'K'),
    CompactUnit(1e5, ' L'),
    CompactUnit(1e7, ' Cr'),
    CompactUnit(1e12, ' L Cr'),
  ];

  /// Currency symbol (may be empty).
  final String symbol;

  /// Put the symbol after the number.
  final bool symbolAfter;

  /// Digit grouping.
  final DigitGrouping grouping;

  /// Decimal places for [format].
  final int decimals;

  /// Thousands separator.
  final String groupSeparator;

  /// Decimal separator.
  final String decimalSeparator;

  /// Units for [formatCompact], ascending by threshold.
  final List<CompactUnit> compactUnits;

  /// Insert a space between number and symbol.
  final bool spaceAfterSymbol;

  /// A copy with some fields replaced.
  CurrencyFormat copyWith({
    String? symbol,
    bool? symbolAfter,
    DigitGrouping? grouping,
    int? decimals,
    String? groupSeparator,
    String? decimalSeparator,
    List<CompactUnit>? compactUnits,
    bool? spaceAfterSymbol,
  }) =>
      CurrencyFormat(
        symbol: symbol ?? this.symbol,
        symbolAfter: symbolAfter ?? this.symbolAfter,
        grouping: grouping ?? this.grouping,
        decimals: decimals ?? this.decimals,
        groupSeparator: groupSeparator ?? this.groupSeparator,
        decimalSeparator: decimalSeparator ?? this.decimalSeparator,
        compactUnits: compactUnits ?? this.compactUnits,
        spaceAfterSymbol: spaceAfterSymbol ?? this.spaceAfterSymbol,
      );

  String _wrap(String number, bool negative) {
    final gap = spaceAfterSymbol ? ' ' : '';
    final body = symbol.isEmpty
        ? number
        : (symbolAfter ? '$number$gap$symbol' : '$symbol$gap$number');
    return negative ? '-$body' : body;
  }

  String _group(String digits) {
    if (grouping == DigitGrouping.none || digits.length <= 3) return digits;
    final out = StringBuffer();
    if (grouping == DigitGrouping.international) {
      final first = digits.length % 3;
      if (first > 0) out.write(digits.substring(0, first));
      for (var i = first; i < digits.length; i += 3) {
        if (out.isNotEmpty) out.write(groupSeparator);
        out.write(digits.substring(i, i + 3));
      }
    } else {
      final head = digits.substring(0, digits.length - 3);
      final tail = digits.substring(digits.length - 3);
      final first = head.length % 2;
      if (first > 0) out.write(head.substring(0, first));
      for (var i = first; i < head.length; i += 2) {
        if (out.isNotEmpty) out.write(groupSeparator);
        out.write(head.substring(i, i + 2));
      }
      out
        ..write(groupSeparator)
        ..write(tail);
    }
    return out.toString();
  }

  /// Full number, for example `₹12,34,568`. Non-finite values give `-`; values
  /// of 1e15 or more fall back to [formatCompact] to avoid 20-digit strings.
  String format(double value, {int? decimals}) {
    if (!value.isFinite) return '–';
    if (value.abs() >= 1e15) return formatCompact(value);
    final d = decimals ?? this.decimals;
    var text = value.abs().toStringAsFixed(d);
    final isZero = double.parse(text) == 0;
    final dot = text.indexOf('.');
    final intPart = dot < 0 ? text : text.substring(0, dot);
    final frac = dot < 0 ? '' : text.substring(dot + 1);
    text = _group(intPart) + (frac.isEmpty ? '' : '$decimalSeparator$frac');
    return _wrap(text, value < 0 && !isZero);
  }

  /// Short number such as `₹1.2 L`, `₹3.5 Cr` or `$2.4M`. Below the first
  /// unit it behaves like [format].
  String formatCompact(double value) {
    if (!value.isFinite) return '–';
    final a = value.abs();
    CompactUnit? unit;
    for (final u in compactUnits) {
      if (a >= u.threshold) unit = u;
    }
    if (unit == null) return format(value);
    final scaled = a / unit.threshold;
    var s = scaled.toStringAsFixed(2);
    if (s.contains('.')) {
      s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
    }
    s = s.replaceFirst('.', decimalSeparator);
    return _wrap('$s${unit.suffix}', value < 0);
  }

  /// Parses text typed by a user (digits, either separator, optional symbol)
  /// back into a number, or returns null.
  double? parse(String text) {
    var t = text.trim();
    if (t.isEmpty) return null;
    t = t.replaceAll(symbol, '').replaceAll(RegExp(r'\s'), '');
    if (groupSeparator.isNotEmpty) t = t.replaceAll(groupSeparator, '');
    if (decimalSeparator != '.') t = t.replaceAll(decimalSeparator, '.');
    return double.tryParse(t);
  }
}
