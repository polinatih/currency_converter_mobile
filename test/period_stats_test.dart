import 'package:currency_converter_mobile/src/domain/period_stats.dart';
import 'package:flutter_test/flutter_test.dart';

List<RatePoint> series(List<double> values) => [
      for (var i = 0; i < values.length; i++) RatePoint(DateTime(2026, 11, 1 + i), values[i]),
    ];

void main() {
  group('PeriodStats', () {
    test('min, max, average, change and percent', () {
      final stats = PeriodStats.compute(series([10, 12, 9, 11]))!;

      expect(stats.min.value, 9);
      expect(stats.min.date, DateTime(2026, 11, 3));
      expect(stats.max.value, 12);
      expect(stats.max.date, DateTime(2026, 11, 2));
      expect(stats.average, closeTo(10.5, 1e-12));
      expect(stats.first.value, 10);
      expect(stats.last.value, 11);
      expect(stats.absoluteChange, closeTo(1, 1e-12));
      expect(stats.percentChange, closeTo(10, 1e-12));
      expect(stats.count, 4);
      expect(stats.trend, Trend.up);
    });

    test('falling rate', () {
      final stats = PeriodStats.compute(series([20, 19, 18]))!;
      expect(stats.absoluteChange, closeTo(-2, 1e-12));
      expect(stats.percentChange, closeTo(-10, 1e-12));
      expect(stats.trend, Trend.down);
    });

    test('tiny change below the threshold counts as "no change"', () {
      final stats = PeriodStats.compute(series([10, 10.0005]))!; // +0.005 %
      expect(stats.trend, Trend.flat);
    });

    test('same first and last value is "no change" even if it moved inside the period', () {
      final stats = PeriodStats.compute(series([10, 15, 5, 10]))!;
      expect(stats.absoluteChange, 0);
      expect(stats.percentChange, 0);
      expect(stats.trend, Trend.flat);
      expect(stats.min.value, 5);
      expect(stats.max.value, 15);
    });

    test('points in random order are sorted by date', () {
      final points = series([1, 2, 3]).reversed.toList();
      final stats = PeriodStats.compute(points)!;
      expect(stats.first.value, 1);
      expect(stats.last.value, 3);
      expect(stats.trend, Trend.up);
    });

    test('single point: no change', () {
      final stats = PeriodStats.compute(series([17.9]))!;
      expect(stats.min.value, 17.9);
      expect(stats.max.value, 17.9);
      expect(stats.average, 17.9);
      expect(stats.absoluteChange, 0);
      expect(stats.trend, Trend.flat);
    });

    test('empty data set returns null instead of crashing', () {
      expect(PeriodStats.compute(const []), isNull);
    });

    test('non-finite values are ignored', () {
      final stats = PeriodStats.compute([
        RatePoint(DateTime(2026, 11, 1), double.nan),
        RatePoint(DateTime(2026, 11, 2), 5),
      ])!;
      expect(stats.count, 1);
      expect(PeriodStats.compute([RatePoint(DateTime(2026, 11, 1), double.infinity)]), isNull);
    });

    test('zero first value does not divide by zero', () {
      final stats = PeriodStats.compute(series([0, 5]))!;
      expect(stats.percentChange, 0);
    });
  });
}
