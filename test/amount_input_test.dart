import 'package:currency_converter_mobile/src/domain/amount_input.dart';
import 'package:flutter_test/flutter_test.dart';

double valid(String text) {
  final result = parseAmount(text);
  expect(result, isA<ValidAmount>(), reason: 'expected "$text" to be valid');
  return (result as ValidAmount).value;
}

InvalidAmount invalid(String text) {
  final result = parseAmount(text);
  expect(result, isA<InvalidAmount>(), reason: 'expected "$text" to be invalid');
  return result as InvalidAmount;
}

void main() {
  group('parseAmount — accepted', () {
    test('integers and decimals with dot or comma', () {
      expect(valid('150'), 150);
      expect(valid('99,50'), 99.5);
      expect(valid('0.01'), 0.01);
    });

    test('spaces as thousand separators and around the number', () {
      expect(valid('1 000.25'), 1000.25);
      expect(valid('  5  '), 5);
      expect(valid('1 000'), 1000);
    });
  });

  group('parseAmount — rejected', () {
    test('empty field is flagged as empty (no red error)', () {
      final result = invalid('');
      expect(result.isEmpty, isTrue);
      expect(invalid('   ').isEmpty, isTrue);
    });

    test('zero', () {
      expect(invalid('0').message, 'Сумма должна быть больше нуля');
      expect(invalid('0,00').isEmpty, isFalse);
    });

    test('negative numbers', () {
      expect(invalid('-5').message, 'Сумма не может быть отрицательной');
      expect(invalid('−5').message, 'Сумма не может быть отрицательной');
    });

    test('letters and special values', () {
      for (final text in ['abc', '12a', 'nan', 'NaN', 'inf', 'Infinity']) {
        expect(invalid(text).message, 'Введите число, например 150 или 99,50', reason: text);
      }
    });

    test('other number formats', () {
      for (final text in ['1e3', '1_000', '1.2.3', '.5', '5.', '+5', '1,234,5', '1.1234567']) {
        invalid(text);
      }
    });

    test('too large', () {
      expect(invalid('2000000000000').message, 'Слишком большая сумма');
    });
  });
}
