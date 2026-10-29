import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../format/currency_format.dart';
import '../theme/calculator_theme.dart';
import 'controllers.dart';

/// A label, an editable number field and a slider for one [CalculatorInput].
///
/// This is the default input widget of every calculator view; use it directly
/// when you compose your own layout.
class CalculatorInputTile extends StatefulWidget {
  /// Creates an input tile.
  const CalculatorInputTile({
    super.key,
    required this.input,
    required this.value,
    required this.onChanged,
    this.format = CurrencyFormat.inr,
    this.theme,
  });

  /// Definition (label, range, kind).
  final CalculatorInput input;

  /// Current value.
  final double value;

  /// Called with every new value (typed values may exceed the slider range).
  final ValueChanged<double> onChanged;

  /// Currency format (symbol for money inputs, compact hint).
  final CurrencyFormat format;

  /// Theme override.
  final FinanceCalculatorTheme? theme;

  @override
  State<CalculatorInputTile> createState() => _CalculatorInputTileState();
}

class _CalculatorInputTileState extends State<CalculatorInputTile> {
  late final TextEditingController _text =
      TextEditingController(text: _show(widget.value));
  final FocusNode _focus = FocusNode();

  String _show(double v) => v.toStringAsFixed(widget.input.decimals);

  @override
  void didUpdateWidget(CalculatorInputTile old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus && old.value != widget.value) {
      _text.text = _show(widget.value);
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _typed(String s) {
    final v = widget.input.kind == InputKind.currency
        ? widget.format.parse(s)
        : double.tryParse(s.trim());
    if (v != null && v.isFinite) widget.onChanged(v);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme ?? FinanceCalculatorTheme.of(context);
    final i = widget.input;
    final divisions = ((i.max - i.min) / i.step).round();
    final sliderValue = widget.value.clamp(i.min, i.max).toDouble();
    final suffix = switch (i.kind) {
      InputKind.percent => '%',
      InputKind.years => 'Yr',
      _ => null,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(i.label,
                    style: t.labelStyle.copyWith(color: t.textColor)),
              ),
              SizedBox(
                width: 118,
                child: TextField(
                  controller: _text,
                  focusNode: _focus,
                  textAlign: TextAlign.end,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  style: t.labelStyle.copyWith(
                      color: t.returnsColor, fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    isDense: true,
                    prefixText: i.kind == InputKind.currency &&
                            widget.format.symbol.isNotEmpty
                        ? '${widget.format.symbol} '
                        : null,
                    suffixText: suffix,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: t.borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: t.returnsColor, width: 1.5),
                    ),
                  ),
                  onChanged: _typed,
                  onSubmitted: (_) => _text.text = _show(widget.value),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: t.returnsColor,
              inactiveTrackColor: t.investedColor,
              thumbColor: t.returnsColor,
              overlayColor: t.returnsColor.withValues(alpha: 0.12),
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(
                  elevation: 0, pressedElevation: 0),
            ),
            child: Slider(
              value: sliderValue,
              min: i.min,
              max: i.max,
              divisions: divisions >= 1 && divisions <= 2000 ? divisions : null,
              onChanged: (v) {
                widget.onChanged(v);
                if (!_focus.hasFocus) _text.text = _show(v);
              },
            ),
          ),
          if (i.helper != null || i.kind == InputKind.currency)
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                i.helper ?? widget.format.formatCompact(widget.value),
                style: t.labelStyle
                    .copyWith(color: t.mutedTextColor, fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }
}
