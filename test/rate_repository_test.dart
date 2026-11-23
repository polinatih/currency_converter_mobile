import 'package:currency_converter_mobile/src/data/rate_cache.dart';
import 'package:currency_converter_mobile/src/data/rate_repository.dart';
import 'package:currency_converter_mobile/src/data/bnm_parser.dart';
import 'package:currency_converter_mobile/src/domain/dates.dart';
import 'package:currency_converter_mobile/src/domain/rate_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Monday 23.11.2026; the weekend before is 21–22.11.
final monday = DateTime(2026, 11, 23, 15, 30);
final sunday = DateTime(2026, 11, 22, 10, 0);

bool isWeekend(DateTime d) => d.weekday == DateTime.saturday || d.weekday == DateTime.sunday;

/// BNM-like behaviour: rates on working days (USD grows by 0.01 per day), nothing at weekends.
Future<String> workingDays(DateTime day) async {
  if (isWeekend(day)) return bnmXml(formatDay(day), const []);
  final usd = (17 + day.day / 100).toStringAsFixed(4);
  return bnmXml(formatDay(day), [('USD', 1, 'Доллар США', usd), ('EUR', 1, 'Евро', '20.0000')]);
}

void main() {
  late MemoryStore store;
  late RateCache cache;

  setUp(() {
    store = MemoryStore();
    cache = RateCache(store);
  });

  RateRepository repo(FakeSource source, DateTime now) =>
      RateRepository(source: source, cache: cache, clock: () => now);

  group('Latest rates', () {
    test('today is published: live data, saved to cache', () async {
      final source = FakeSource(workingDays);
      final result = await repo(source, monday).loadLatest();

      expect(result.origin, RatesOrigin.live);
      expect(result.notice, isNull);
      expect(result.sheet.date, DateTime(2026, 11, 23));
      expect(source.requested, hasLength(1));
      expect((await cache.loadLatest())!.date, DateTime(2026, 11, 23));
    });

    test('weekend: steps back to Friday and tells the user', () async {
      final source = FakeSource(workingDays);
      final result = await repo(source, sunday).loadLatest();

      expect(result.origin, RatesOrigin.earlierDay);
      expect(result.sheet.date, DateTime(2026, 11, 20));
      expect(source.requested, [DateTime(2026, 11, 22), DateTime(2026, 11, 21), DateTime(2026, 11, 20)]);
      expect(result.notice, contains('20.11.2026'));
    });

    test('nothing published for 11 days and no cache: clear error', () async {
      final source = FakeSource((day) async => bnmXml(formatDay(day), const []));
      await expectLater(repo(source, monday).loadLatest(), throwsA(isA<NoRatesException>()));
      expect(source.requested, hasLength(11));
    });

    test('offline with cache: cached rates and their date are shown', () async {
      await cache.saveLatest(BnmParser.parse(sampleXml('18.11.2026'))!);

      final result = await repo(offlineSource(), monday).loadLatest();
      expect(result.origin, RatesOrigin.cache);
      expect(result.sheet.date, DateTime(2026, 11, 18));
      expect(result.notice, contains('Нет подключения к интернету'));
      expect(result.notice, contains('18.11.2026'));
    });

    test('offline without cache: NoRatesException with a readable message', () async {
      await expectLater(
        repo(offlineSource(), monday).loadLatest(),
        throwsA(isA<NoRatesException>().having((e) => e.message, 'message', contains('Сохранённых курсов пока нет'))),
      );
    });

    test('HTML instead of XML: no date search, falls back to cache', () async {
      await cache.saveLatest(BnmParser.parse(sampleXml('18.11.2026'))!);
      final source = FakeSource((_) async => '<html><body>502 Bad Gateway</body></html>');

      final result = await repo(source, monday).loadLatest();
      expect(source.requested, hasLength(1));
      expect(result.origin, RatesOrigin.cache);
    });

    test('a failed request never overwrites the cache', () async {
      await cache.saveLatest(BnmParser.parse(sampleXml('18.11.2026'))!);
      await repo(offlineSource(), monday).loadLatest();
      expect((await cache.loadLatest())!.date, DateTime(2026, 11, 18));
    });
  });

  group('Pair history (week / month screens)', () {
    test('one point per working day, weekends are gaps', () async {
      final history = await repo(FakeSource(workingDays), monday)
          .loadPairHistory(from: 'USD', to: 'MDL', days: 7);

      expect(history.start, DateTime(2026, 11, 17));
      expect(history.end, DateTime(2026, 11, 23));
      expect(history.points.map((p) => p.date.day), [17, 18, 19, 20, 23]);
      expect(history.points.first.value, closeTo(17.17, 1e-9));
      expect(history.points.last.value, closeTo(17.23, 1e-9));
      expect(history.unloadedDays, 0);
      expect(history.notice, isNull);
    });

    test('second load works offline from the cache (airplane mode after restart)', () async {
      await repo(FakeSource(workingDays), monday).loadPairHistory(from: 'USD', to: 'MDL', days: 30);

      // New repository on the same storage = app restarted without network.
      final offline = offlineSource();
      final history = await repo(offline, monday).loadPairHistory(from: 'USD', to: 'MDL', days: 30);

      expect(offline.requested, isEmpty);
      expect(history.points, hasLength(21)); // working days in 25.10–23.11.2026
      expect(history.unloadedDays, 0);
    });

    test('offline with an empty cache: no points and an explanation', () async {
      final history = await repo(offlineSource(), monday).loadPairHistory(from: 'USD', to: 'MDL', days: 7);
      expect(history.points, isEmpty);
      expect(history.unloadedDays, 7);
      expect(history.notice, contains('7 из 7'));
    });

    test('cross pair from history: EUR in USD', () async {
      final history = await repo(FakeSource(workingDays), monday)
          .loadPairHistory(from: 'EUR', to: 'USD', days: 7);
      expect(history.points.last.value, closeTo(20 / 17.23, 1e-9));
    });

    test('today without rates is not cached as empty (BNM may publish later)', () async {
      final source = FakeSource((day) async => bnmXml(formatDay(day), const []));
      await repo(source, monday).loadPairHistory(from: 'USD', to: 'MDL', days: 3);
      expect(await cache.loadDay(DateTime(2026, 11, 23)), isNull);
      expect((await cache.loadDay(DateTime(2026, 11, 22)))!.sheet, isNull);
    });
  });

  group('RateCache', () {
    test('damaged data in storage is ignored', () async {
      store.data['latest_sheet'] = '{not json';
      expect(await cache.loadLatest(), isNull);
      store.data['day:2026-11-20'] = '{"date": 5}';
      expect(await cache.loadDay(DateTime(2026, 11, 20)), isNull);
    });

    test('a sheet without foreign rates is never saved as latest', () async {
      await cache.saveLatest(RateSheet(date: DateTime(2026, 11, 22), rates: const []));
      expect(store.data.containsKey('latest_sheet'), isFalse);

      await cache.saveLatest(BnmParser.parse(sampleXml('18.11.2026'))!);
      expect(store.data.containsKey('latest_sheet'), isTrue);
    });
  });
}
