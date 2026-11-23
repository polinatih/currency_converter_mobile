import 'package:currency_converter_mobile/src/data/bnm_parser.dart';
import 'package:currency_converter_mobile/src/domain/number_format.dart';
import 'package:currency_converter_mobile/src/domain/rate_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  final sheet = BnmParser.parse(sampleXml())!;

  group('Conversion', () {
    test('foreign currency to MDL and back', () {
      expect(sheet.convert(100, 'USD', 'MDL'), closeTo(1800, 1e-9));
      expect(sheet.convert(1800, 'MDL', 'USD'), closeTo(100, 1e-9));
    });

    test('cross rate through MDL in both directions', () {
      expect(sheet.convert(100, 'EUR', 'USD'), closeTo(111.111111, 1e-6));
      expect(sheet.convert(111.111111111, 'USD', 'EUR'), closeTo(100, 1e-6));
      expect(sheet.crossRate('USD', 'EUR') * sheet.crossRate('EUR', 'USD'), closeTo(1, 1e-12));
    });

    test('nominal 100: 1000 HUF = 50 MDL = 2.5 EUR', () {
      expect(sheet.convert(1000, 'HUF', 'MDL'), closeTo(50, 1e-9));
      expect(sheet.convert(1000, 'HUF', 'EUR'), closeTo(2.5, 1e-9));
      expect(sheet.convert(2.5, 'EUR', 'HUF'), closeTo(1000, 1e-9));
    });

    test('same currency returns exactly the same amount', () {
      expect(sheet.convert(123.45, 'EUR', 'EUR'), 123.45);
      expect(sheet.crossRate('RON', 'RON'), 1);
    });

    test('unknown currency is an error, not a crash with null', () {
      expect(() => sheet.convert(1, 'USD', 'JPY'), throwsArgumentError);
    });
  });

  group('RateSheet JSON (cache format)', () {
    test('round trip keeps date and rates; MDL is not stored', () {
      final json = sheet.toJson();
      expect((json['rates'] as List).length, 4);

      final restored = RateSheet.fromJson(json);
      expect(restored.date, sheet.date);
      expect(restored.codes, sheet.codes);
      expect(restored.convert(1000, 'HUF', 'EUR'), closeTo(2.5, 1e-9));
    });
  });

  group('Number formatting', () {
    test('thousands and decimal comma', () {
      expect(formatNumber(17452.3), '17 452,30');
      expect(formatNumber(0.05561, decimals: 4), '0,0556');
      expect(formatNumber(1234567), '1 234 567,00');
    });

    test('signed values', () {
      expect(formatSigned(0.1234, decimals: 4), '+0,1234');
      expect(formatSigned(-2.5), '−2,50');
      expect(formatSigned(-0.001), '0,00');
    });
  });
}
