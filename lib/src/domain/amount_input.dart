/// Validation of the amount typed by the user.
library;

/// Result of [parseAmount].
sealed class AmountInput {
  const AmountInput();
}

final class ValidAmount extends AmountInput {
  const ValidAmount(this.value);
  final double value;
}

final class InvalidAmount extends AmountInput {
  const InvalidAmount(this.message, {this.isEmpty = false});

  /// Text shown under the input field.
  final String message;

  /// The field is simply empty — the UI may stay quiet instead of showing an error.
  final bool isEmpty;
}

/// Upper bound that keeps results readable and far from double precision limits.
const double maxAmount = 1e12;

final RegExp _plainDecimal = RegExp(r'^\d+(\.\d{1,6})?$');

/// Accepts "150", "99,50", "1 000.25". Rejects empty input, zero, negative
/// numbers, letters, exponents and special values such as `NaN` or `Infinity`.
AmountInput parseAmount(String raw) {
  // Users type spaces (incl. non-breaking) as thousand separators.
  final compact = raw.replaceAll(RegExp(r'[\s  ]'), '');
  if (compact.isEmpty) {
    return const InvalidAmount('Введите сумму', isEmpty: true);
  }
  if (compact.startsWith('-') || compact.startsWith('−')) {
    return const InvalidAmount('Сумма не может быть отрицательной');
  }
  final normalized = compact.replaceAll(',', '.');
  if (!_plainDecimal.hasMatch(normalized)) {
    return const InvalidAmount('Введите число, например 150 или 99,50');
  }
  final value = double.parse(normalized);
  if (value == 0) {
    return const InvalidAmount('Сумма должна быть больше нуля');
  }
  if (value > maxAmount) {
    return const InvalidAmount('Слишком большая сумма');
  }
  return ValidAmount(value);
}
