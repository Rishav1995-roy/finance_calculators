## 0.0.1

Initial release.

- Calculation core (no widgets): SIP with yearly step-up, lumpsum, SWP with depletion month, EMI with full amortization schedule and prepayments, FD, RD, goal planner (SIP or lumpsum needed, inflation aware), CAGR, inflation, retirement corpus. Immutable results with totals, monthly and yearly breakdown and `toJson`.
- Ready views: `SipCalculatorView`, `LumpsumCalculatorView`, `EmiCalculatorView`, `SwpCalculatorView`, `FdCalculatorView`, `RdCalculatorView`, `GoalPlannerView`, plus the generic `CalculatorView` and `CalculatorController`.
- Every part replaceable through builders; `FinanceCalculatorTheme` (ThemeExtension) with light, dark and color-scheme derived presets.
- Charts drawn with `CustomPainter`: `DonutChart`, `PieChart`, `GaugeChart`, `StackedBarChart`, `LineAreaChart`, `ChartLegend`; animated, tappable tooltips.
- Locale-free `CurrencyFormat` with INR (lakh / crore), USD and EUR presets.
