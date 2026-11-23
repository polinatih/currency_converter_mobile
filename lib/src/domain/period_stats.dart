/// Statistics for the "week" and "month" comparison screens.
library;

/// Value of the indicator (here: a currency pair rate) on one day.
class RatePoint {
  const RatePoint(this.date, this.value);
  final DateTime date;
  final double value;
}

enum Trend {
  up('Рост'),
  down('Падение'),
  flat('Без изменений');

  const Trend(this.label);
  final String label;
}

/// Min / max / average / change over a period.
class PeriodStats {
  const PeriodStats._({
    required this.first,
    required this.last,
    required this.min,
    required this.max,
    required this.average,
    required this.count,
  });

  /// A change smaller than this (in percent) is treated as "no change",
  /// otherwise rounding noise in the 4th decimal would show up as a trend.
  static const double flatThresholdPercent = 0.01;

  final RatePoint first;
  final RatePoint last;
  final RatePoint min;
  final RatePoint max;
  final double average;
  final int count;

  /// Last value minus first value, in units of the indicator.
  double get absoluteChange => last.value - first.value;

  /// Change relative to the first value, in percent.
  double get percentChange =>
      first.value == 0 ? 0 : absoluteChange / first.value * 100;

  Trend get trend {
    if (percentChange.abs() < flatThresholdPercent) return Trend.flat;
    return absoluteChange > 0 ? Trend.up : Trend.down;
  }

  /// Returns `null` for an empty list — there is nothing to compare.
  /// Points may come in any order; they are sorted by date.
  static PeriodStats? compute(Iterable<RatePoint> points) {
    final sorted = points.where((p) => p.value.isFinite).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    if (sorted.isEmpty) return null;

    var min = sorted.first;
    var max = sorted.first;
    var sum = 0.0;
    for (final point in sorted) {
      if (point.value < min.value) min = point;
      if (point.value > max.value) max = point;
      sum += point.value;
    }

    return PeriodStats._(
      first: sorted.first,
      last: sorted.last,
      min: min,
      max: max,
      average: sum / sorted.length,
      count: sorted.length,
    );
  }
}
