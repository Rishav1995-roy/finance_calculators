import 'package:finance_calculators/finance_calculators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CurrencyFormat', () {
    test('INR lakh/crore grouping', () {
      expect(CurrencyFormat.inr.format(0), '₹0');
      expect(CurrencyFormat.inr.format(999), '₹999');
      expect(CurrencyFormat.inr.format(1000), '₹1,000');
      expect(CurrencyFormat.inr.format(123456), '₹1,23,456');
      expect(CurrencyFormat.inr.format(12345678), '₹1,23,45,678');
      expect(CurrencyFormat.inr.format(1234567890),
          '₹123,45,67,890'.replaceFirst('123,', '1,23,'));
    });

    test('international, euro, decimals, negatives', () {
      expect(CurrencyFormat.usd.format(1234567), r'$1,234,567');
      expect(CurrencyFormat.usd.format(1234.5, decimals: 2), r'$1,234.50');
      expect(CurrencyFormat.eur.format(-1234), '-€1,234');
      expect(CurrencyFormat.eurEuropean.format(1234567.891, decimals: 2),
          '1.234.567,89 €');
      expect(CurrencyFormat.usd.format(-0.2), r'$0');
    });

    test('compact units', () {
      expect(CurrencyFormat.inr.formatCompact(150000), '₹1.5 L');
      expect(CurrencyFormat.inr.formatCompact(35000000), '₹3.5 Cr');
      expect(CurrencyFormat.inr.formatCompact(500), '₹500');
      expect(CurrencyFormat.usd.formatCompact(2400000), r'$2.4M');
      expect(CurrencyFormat.usd.formatCompact(1500), r'$1.5K');
    });

    test('non-finite and huge values never produce garbage', () {
      expect(CurrencyFormat.inr.format(double.nan), '–');
      expect(CurrencyFormat.inr.format(double.infinity), '–');
      expect(CurrencyFormat.usd.format(1e21), isNot(contains('e+')));
      expect(CurrencyFormat.inr.format(1e18), contains('L Cr'));
    });

    test('parse', () {
      expect(CurrencyFormat.inr.parse('₹ 12,50,000'), 1250000);
      expect(CurrencyFormat.eurEuropean.parse('1.234,5'), 1234.5);
      expect(CurrencyFormat.usd.parse(''), isNull);
      expect(CurrencyFormat.usd.parse('abc'), isNull);
    });

    test('custom formatter via copyWith', () {
      final f =
          CurrencyFormat.usd.copyWith(symbol: 'Rs', spaceAfterSymbol: true);
      expect(f.format(1500), 'Rs 1,500');
    });
  });
}
