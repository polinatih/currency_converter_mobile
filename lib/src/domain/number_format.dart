/// Russian-style number formatting without extra packages:
/// `17 452,30` — narrow spaces between thousands, comma before decimals.
library;

const String _thinSpace = ' ';

String formatNumber(double value, {int decimals = 2}) {
  if (value.isNaN || value.isInfinite) return '—';
  final negative = value < 0;
  final fixed = value.abs().toStringAsFixed(decimals);
  final parts = fixed.split('.');
  final digits = parts[0];
  final grouped = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final fromEnd = digits.length - i;
    grouped.write(digits[i]);
    if (fromEnd > 1 && fromEnd % 3 == 1) grouped.write(_thinSpace);
  }
  final sign = negative && double.parse(fixed) != 0 ? '−' : '';
  final fraction = decimals > 0 ? ',${parts[1]}' : '';
  return '$sign$grouped$fraction';
}

/// Always shows the sign: `+0,1234`, `−2,50`, `0,00`.
String formatSigned(double value, {int decimals = 2}) {
  final body = formatNumber(value.abs(), decimals: decimals);
  final rounded = double.parse(value.toStringAsFixed(decimals));
  if (rounded > 0) return '+$body';
  if (rounded < 0) return '−$body';
  return body;
}
