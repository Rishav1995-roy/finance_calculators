/// The calculation core of `finance_calculators`: no widgets, no `dart:ui`.
///
/// Import this library when you only need the numbers.
library;

export 'src/core/common.dart'
    show
        Compounding,
        InvalidInputException,
        PaymentTiming,
        RateConvention,
        Tenure,
        maxRatePercent,
        maxTenureMonths;
export 'src/core/emi.dart';
export 'src/core/lumpsum.dart';
export 'src/core/planning.dart';
export 'src/core/rates.dart';
export 'src/core/result.dart'
    show BreakdownRow, CalculatorResult, aggregateYearly;
export 'src/core/sip.dart'
    show RdCalculator, RdResult, SipCalculator, SipResult, StepUp;
export 'src/core/swp.dart';
