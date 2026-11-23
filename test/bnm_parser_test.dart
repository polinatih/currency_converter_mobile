import 'package:currency_converter_mobile/src/data/bnm_parser.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  group('BnmParser — valid documents', () {
    test('reads date, codes, names and adds MDL', () {
      final sheet = BnmParser.parse(sampleXml())!;

      expect(sheet.date, DateTime(2026, 11, 20));
      expect(sheet.codes, ['EUR', 'HUF', 'MDL', 'RON', 'USD']);
      expect(sheet['USD']!.name, 'Доллар США');
      expect(sheet['MDL']!.mdlPerUnit, 1);
    });

    test('takes the nominal into account', () {
      final sheet = BnmParser.parse(sampleXml())!;
      expect(sheet['HUF']!.nominal, 100);
      expect(sheet['HUF']!.mdlPerUnit, closeTo(0.05, 1e-12));
    });

    test('accepts a comma as decimal separator', () {
      final sheet = BnmParser.parse(bnmXml('20.11.2026', const [('USD', 1, 'Доллар США', '17,9458')]))!;
      expect(sheet['USD']!.value, closeTo(17.9458, 1e-12));
    });

    test('valid document without rates means "not published" and returns null', () {
      expect(BnmParser.parse(bnmXml('22.11.2026', const [])), isNull);
    });

    test('skips broken entries but keeps the rest', () {
      final sheet = BnmParser.parse(bnmXml('20.11.2026', const [
        ('USD', 1, 'Доллар США', '18.0'),
        ('ZER', 1, 'Нулевой курс', '0'),
        ('NEG', 1, 'Отрицательный', '-3'),
        ('TXT', 1, 'Не число', 'abc'),
        ('NOM', 0, 'Нулевой номинал', '5'),
        ('XX', 1, 'Неверный код', '5'),
      ]))!;
      expect(sheet.codes, ['MDL', 'USD']);
    });

    test('all entries broken behaves like an empty day', () {
      expect(BnmParser.parse(bnmXml('20.11.2026', const [('ZER', 1, 'x', '0')])), isNull);
    });

    test('uses the requested date when the document has none or an impossible one', () {
      final noDate = sampleXml().replaceFirst('Date="20.11.2026"', '');
      expect(BnmParser.parse(noDate, requestedDate: DateTime(2026, 11, 19))!.date, DateTime(2026, 11, 19));

      final badDate = sampleXml('31.02.2026');
      expect(BnmParser.parse(badDate, requestedDate: DateTime(2026, 11, 18))!.date, DateTime(2026, 11, 18));
    });
  });

  group('BnmParser — invalid responses', () {
    test('empty body', () {
      expect(() => BnmParser.parse(''), throwsA(isA<BnmFormatException>()));
      expect(() => BnmParser.parse('   \n'), throwsA(isA<BnmFormatException>()));
    });

    test('broken XML', () {
      expect(() => BnmParser.parse('<ValCurs Date="20.11.2026"><Valute>'), throwsA(isA<BnmFormatException>()));
    });

    test('HTML error page instead of XML', () {
      expect(
        () => BnmParser.parse('<html><body>Service unavailable</body></html>'),
        throwsA(isA<BnmFormatException>()),
      );
    });

    test('no date anywhere', () {
      final noDate = sampleXml().replaceFirst('Date="20.11.2026"', '');
      expect(() => BnmParser.parse(noDate), throwsA(isA<BnmFormatException>()));
    });
  });
}
