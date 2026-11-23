/// One currency quoted by the National Bank of Moldova.
///
/// BNM quotes the amount of Moldovan lei (MDL) for [nominal] units of the
/// currency, e.g. "100 HUF = 4.95 MDL".
class CurrencyRate {
  const CurrencyRate({
    required this.code,
    required this.name,
    required this.nominal,
    required this.value,
  });

  /// ISO 4217 code, e.g. `USD`.
  final String code;

  /// Human-readable name as published by BNM (Russian feed).
  final String name;

  /// How many units of the currency [value] refers to.
  final int nominal;

  /// MDL for [nominal] units.
  final double value;

  /// MDL for exactly one unit of the currency.
  double get mdlPerUnit => value / nominal;

  Map<String, Object> toJson() => {
        'code': code,
        'name': name,
        'nominal': nominal,
        'value': value,
      };

  factory CurrencyRate.fromJson(Map<String, dynamic> json) => CurrencyRate(
        code: json['code'] as String,
        name: (json['name'] as String?) ?? json['code'] as String,
        nominal: (json['nominal'] as num).toInt(),
        value: (json['value'] as num).toDouble(),
      );
}
