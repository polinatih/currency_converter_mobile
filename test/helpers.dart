import 'package:currency_converter_mobile/src/data/bnm_api.dart';

/// Builds a BNM-like XML document. Each item: (code, nominal, name, value).
String bnmXml(String date, List<(String, int, String, String)> items) {
  final buffer = StringBuffer(
    '<?xml version="1.0" encoding="UTF-8"?>\n'
    '<ValCurs Date="$date" name="Официальный курс молдавского лея">\n',
  );
  for (final (code, nominal, name, value) in items) {
    buffer.write(
      '  <Valute ID="1"><NumCode>000</NumCode><CharCode>$code</CharCode>'
      '<Nominal>$nominal</Nominal><Name>$name</Name><Value>$value</Value></Valute>\n',
    );
  }
  buffer.write('</ValCurs>');
  return buffer.toString();
}

/// Sample day: USD 18, EUR 20, HUF 5 per 100 (= 0.05 per unit), RON 4.
String sampleXml([String date = '20.11.2026']) => bnmXml(date, const [
      ('USD', 1, 'Доллар США', '18.0000'),
      ('EUR', 1, 'Евро', '20.0000'),
      ('HUF', 100, 'Венгерский форинт', '5.0000'),
      ('RON', 1, 'Румынский лей', '4.0000'),
    ]);

/// A rate source driven by a callback; remembers every requested day.
class FakeSource implements RateSource {
  FakeSource(this.handler);

  final Future<String> Function(DateTime day) handler;
  final List<DateTime> requested = [];

  @override
  Future<String> fetchDay(DateTime day) {
    requested.add(day);
    return handler(day);
  }
}

/// Source that always fails like a phone in airplane mode.
FakeSource offlineSource() => FakeSource(
      (_) async => throw const SourceUnavailableException('Нет подключения к интернету'),
    );
