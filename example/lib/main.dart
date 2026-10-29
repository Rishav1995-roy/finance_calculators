import 'package:finance_calculators/finance_calculators.dart';
import 'package:flutter/material.dart';

void main() => runApp(const ExampleApp());

/// Demo app: every calculator, a customization screen and the raw core API.
class ExampleApp extends StatefulWidget {
  /// Creates the app. [initialDark] is used by the demo generator.
  const ExampleApp({super.key, this.initialDark = false});

  /// Start in dark mode.
  final bool initialDark;

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  late bool _dark = widget.initialDark;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'finance_calculators',
      themeMode: _dark ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
          colorSchemeSeed: const Color(0xFF4F46E5), useMaterial3: true),
      darkTheme: ThemeData(
          colorSchemeSeed: const Color(0xFF4F46E5),
          brightness: Brightness.dark,
          useMaterial3: true),
      home: Gallery(
          dark: _dark, onToggleDark: () => setState(() => _dark = !_dark)),
    );
  }
}

/// Tabbed gallery of all calculators.
class Gallery extends StatefulWidget {
  /// Creates the gallery.
  const Gallery({super.key, required this.dark, required this.onToggleDark});

  /// Whether dark mode is on.
  final bool dark;

  /// Switch light / dark.
  final VoidCallback onToggleDark;

  @override
  State<Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<Gallery> {
  static const List<String> _names = <String>[
    'SIP',
    'EMI',
    'Lumpsum',
    'Goal',
    'SWP',
    'FD',
    'RD',
    'Custom',
    'Core API',
  ];
  int _tab = 0;

  Widget _page() {
    switch (_tab) {
      case 0:
        return const SipCalculatorView(chartTypes: CalculatorChartType.values);
      case 1:
        return const EmiCalculatorView(chartTypes: <CalculatorChartType>[
          CalculatorChartType.donut,
          CalculatorChartType.gauge,
          CalculatorChartType.bar,
          CalculatorChartType.line,
        ]);
      case 2:
        return const LumpsumCalculatorView();
      case 3:
        return const GoalPlannerView();
      case 4:
        return const SwpCalculatorView();
      case 5:
        return const FdCalculatorView();
      case 6:
        return const RdCalculatorView();
      case 7:
        return const CustomizedDemo();
      default:
        return const CoreApiDemo();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Finance calculators'),
        actions: <Widget>[
          IconButton(
            key: const ValueKey<String>('theme-toggle'),
            icon: Icon(widget.dark ? Icons.light_mode : Icons.dark_mode),
            onPressed: widget.onToggleDark,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: <Widget>[
                for (var i = 0; i < _names.length; i++)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    child: ChoiceChip(
                      key: ValueKey<String>('tab-${_names[i]}'),
                      label: Text(_names[i]),
                      selected: i == _tab,
                      onSelected: (_) => setState(() => _tab = i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(child: _page()),
    );
  }
}

/// Shows theme + builders + currency presets + localized labels.
class CustomizedDemo extends StatefulWidget {
  /// Creates the demo.
  const CustomizedDemo({super.key});

  @override
  State<CustomizedDemo> createState() => _CustomizedDemoState();
}

class _CustomizedDemoState extends State<CustomizedDemo> {
  bool _usd = false;

  @override
  Widget build(BuildContext context) {
    // 1. A fully custom theme (could also live in ThemeData.extensions).
    final theme = const FinanceCalculatorTheme.light().copyWith(
      investedColor: const Color(0xFFFFD6A5),
      returnsColor: const Color(0xFFE76F51),
      accentColor: const Color(0xFF2A9D8F),
      cardRadius: 28,
      surfaceColor: const Color(0xFFFFF8F0),
      textColor: const Color(0xFF3D2C29),
      mutedTextColor: const Color(0xFF8C6E66),
      borderColor: const Color(0xFFF2D7C4),
      gridColor: const Color(0xFFF2D7C4),
    );
    return Column(
      children: <Widget>[
        SwitchListTile(
          title: const Text('Show in US dollars'),
          value: _usd,
          onChanged: (v) => setState(() => _usd = v),
        ),
        Expanded(
          child: LumpsumCalculatorView(
            theme: theme,
            format: _usd ? CurrencyFormat.usd : CurrencyFormat.inr,
            // 2. Replace the summary card with your own widget.
            summaryBuilder: (context, data) => Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.returnsColor,
                borderRadius: BorderRadius.circular(theme.cardRadius),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('You will have',
                      style: TextStyle(color: Colors.white70)),
                  Text(data.formatEntry(data.entries.first),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            // 3. Take over the chart: plug in any chart library with the data.
            chartBuilder: (context, data) => data.defaultChart,
            chartTypes: const <CalculatorChartType>[
              CalculatorChartType.pie,
              CalculatorChartType.gauge,
              CalculatorChartType.line,
            ],
          ),
        ),
      ],
    );
  }
}

/// The calculation core used without any widget.
class CoreApiDemo extends StatelessWidget {
  /// Creates the demo.
  const CoreApiDemo({super.key});

  @override
  Widget build(BuildContext context) {
    final sip = const SipCalculator(
      monthlyInvestment: 10000,
      annualReturnPercent: 12,
      tenure: Tenure.years(10),
      stepUp: StepUp.percent(10),
    ).calculate();
    final emi = const EmiCalculator(
      principal: 2500000,
      annualRatePercent: 8.5,
      tenure: Tenure.years(20),
    ).calculate();
    final goal = const GoalPlanner(
      targetAmount: 10000000,
      tenure: Tenure.years(15),
      annualReturnPercent: 12,
      inflationPercent: 6,
    ).calculate();
    const f = CurrencyFormat.inr;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Text('Step-up SIP: ${f.format(sip.maturityValue)}'),
        Text('  invested ${f.format(sip.investedAmount)}, '
            'returns ${f.format(sip.estimatedReturns)}'),
        const SizedBox(height: 12),
        Text('EMI: ${f.format(emi.emi)} / month, '
            'interest ${f.format(emi.totalInterest)}'),
        const SizedBox(height: 12),
        Text('Goal of ${f.format(goal.targetAmount)} in 15 years: '
            '${f.format(goal.requiredMonthlySip)} / month'),
        const SizedBox(height: 12),
        Text('First year rows as JSON: ${sip.yearly.first.toJson()}'),
      ],
    );
  }
}
