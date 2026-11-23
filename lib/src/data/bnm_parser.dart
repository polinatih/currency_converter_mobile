import 'package:xml/xml.dart';

import '../domain/currency_rate.dart';
import '../domain/dates.dart';
import '../domain/rate_sheet.dart';

/// The source answered, but the answer is not a BNM rates document.
class BnmFormatException implements Exception {
  const BnmFormatException(this.message);
  final String message;

  @override
  String toString() => 'BnmFormatException: $message';
}

/// Parses the official XML feed of the National Bank of Moldova:
///
/// ```xml
/// <ValCurs Date="11.11.2026" name="Официальный курс молдавского лея">
///   <Valute ID="47">
///     <NumCode>978</NumCode><CharCode>EUR</CharCode><Nominal>1</Nominal>
///     <Name>Евро</Name><Value>19.5512</Value>
///   </Valute>
/// </ValCurs>
/// ```
abstract final class BnmParser {
  /// Returns the rates, or `null` when the document is valid but contains no
  /// rates (weekends, holidays, today before publication).
  ///
  /// Throws [BnmFormatException] for empty bodies, broken XML, HTML pages or
  /// any document whose root is not `<ValCurs>`.
  static RateSheet? parse(String body, {DateTime? requestedDate}) {
    if (body.trim().isEmpty) {
      throw const BnmFormatException('Источник вернул пустой ответ');
    }

    final XmlDocument document;
    try {
      document = XmlDocument.parse(body);
    } on XmlException {
      throw const BnmFormatException('Источник вернул повреждённые данные');
    }

    final root = document.rootElement;
    if (root.name.local != 'ValCurs') {
      throw BnmFormatException('Неожиданный ответ источника (<${root.name.local}>)');
    }

    final date = parseDay(root.getAttribute('Date')) ?? requestedDate;
    if (date == null) {
      throw const BnmFormatException('В ответе источника нет даты курса');
    }

    final rates = <CurrencyRate>[];
    for (final item in root.findElements('Valute')) {
      final rate = _parseItem(item);
      if (rate != null) rates.add(rate);
    }
    if (rates.isEmpty) return null;
    return RateSheet(date: date, rates: rates);
  }

  /// One `<Valute>`; entries with missing or non-positive numbers are skipped
  /// so that a single broken line does not break the whole sheet.
  static CurrencyRate? _parseItem(XmlElement item) {
    String text(String tag) => item.getElement(tag)?.innerText.trim() ?? '';

    final code = text('CharCode').toUpperCase();
    final nominal = int.tryParse(text('Nominal'));
    final value = double.tryParse(text('Value').replaceAll(',', '.'));

    if (!RegExp(r'^[A-Z]{3}$').hasMatch(code)) return null;
    if (code == RateSheet.baseCode) return null;
    if (nominal == null || nominal <= 0) return null;
    if (value == null || !value.isFinite || value <= 0) return null;

    final name = text('Name');
    return CurrencyRate(
      code: code,
      name: name.isEmpty ? code : name,
      nominal: nominal,
      value: value,
    );
  }
}
