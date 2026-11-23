import 'currency_rate.dart';
import 'dates.dart';

/// All official BNM rates valid for one day, plus the Moldovan leu itself.
///
/// BNM does not list MDL (it is the base currency), so it is added here
/// with rate 1 per 1 unit. Every cross rate is calculated through MDL.
class RateSheet {
  RateSheet({required DateTime date, required Iterable<CurrencyRate> rates})
      : date = dateOnly(date),
        _rates = {
          for (final rate in rates) rate.code: rate,
          mdl.code: mdl,
        };

  static const String baseCode = 'MDL';

  static const CurrencyRate mdl = CurrencyRate(
    code: baseCode,
    name: 'Молдавский лей',
    nominal: 1,
    value: 1,
  );

  /// Day the rates are valid for.
  final DateTime date;

  final Map<String, CurrencyRate> _rates;

  /// Currency codes sorted alphabetically, MDL included.
  List<String> get codes => _rates.keys.toList()..sort();

  /// True when the sheet contains nothing but the synthetic MDL entry.
  bool get hasForeignRates => _rates.length > 1;

  bool contains(String code) => _rates.containsKey(code);

  CurrencyRate? operator [](String code) => _rates[code];

  /// Units of [to] for one unit of [from].
  double crossRate(String from, String to) {
    if (from == to) return 1;
    final source = _rates[from];
    final target = _rates[to];
    if (source == null || target == null) {
      throw ArgumentError('Нет курса для пары $from/$to на ${formatDay(date)}');
    }
    return source.mdlPerUnit / target.mdlPerUnit;
  }

  /// Converts [amount] of [from] into [to]. The same currency returns [amount] unchanged.
  double convert(double amount, String from, String to) {
    if (from == to) return amount;
    return amount * crossRate(from, to);
  }

  Map<String, Object> toJson() => {
        'date': dayKey(date),
        'rates': [
          for (final rate in _rates.values)
            if (rate.code != baseCode) rate.toJson(),
        ],
      };

  factory RateSheet.fromJson(Map<String, dynamic> json) {
    final parts = (json['date'] as String).split('-').map(int.parse).toList();
    return RateSheet(
      date: DateTime(parts[0], parts[1], parts[2]),
      rates: [
        for (final item in json['rates'] as List<dynamic>)
          CurrencyRate.fromJson(item as Map<String, dynamic>),
      ],
    );
  }
}
