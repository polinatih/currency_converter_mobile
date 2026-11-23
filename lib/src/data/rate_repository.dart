import 'dart:math' as math;

import '../domain/dates.dart';
import '../domain/period_stats.dart';
import '../domain/rate_sheet.dart';
import 'bnm_api.dart';
import 'bnm_parser.dart';
import 'rate_cache.dart';

/// Where the rates on screen came from.
enum RatesOrigin {
  /// Today's rates straight from BNM.
  live,

  /// BNM has nothing for today yet (weekend, holiday, before ~13:00) —
  /// the latest published day is used.
  earlierDay,

  /// BNM is unreachable or broken — the last saved rates are used.
  cache,
}

class LatestRates {
  const LatestRates(this.sheet, this.origin, {this.notice});

  final RateSheet sheet;
  final RatesOrigin origin;

  /// Explanation for the user when [origin] is not [RatesOrigin.live].
  final String? notice;
}

/// Neither BNM nor the local cache can provide rates.
class NoRatesException implements Exception {
  const NoRatesException(this.message);
  final String message;

  @override
  String toString() => 'NoRatesException: $message';
}

/// Daily values of one currency pair for the comparison screens.
class PairHistory {
  const PairHistory({
    required this.from,
    required this.to,
    required this.start,
    required this.end,
    required this.points,
    required this.unloadedDays,
    this.notice,
  });

  final String from;
  final String to;
  final DateTime start;
  final DateTime end;

  /// One point per day that has published rates, oldest first.
  final List<RatePoint> points;

  /// Days that could not be loaded (no network and not in the cache).
  final int unloadedDays;

  final String? notice;
}

/// Single entry point for rates: BNM first, the local cache as a fallback.
class RateRepository {
  RateRepository({
    required RateSource source,
    required RateCache cache,
    DateTime Function()? clock,
    this.lookbackDays = 10,
    this.parallelRequests = 6,
  })  : _source = source,
        _cache = cache,
        _clock = clock ?? DateTime.now;

  final RateSource _source;
  final RateCache _cache;
  final DateTime Function() _clock;

  /// How many days back to look when today has no published rates.
  final int lookbackDays;

  /// Simultaneous requests while loading a month of history.
  final int parallelRequests;

  DateTime get today => dateOnly(_clock());

  /// Today's rates, or the latest earlier day, or the cache.
  Future<LatestRates> loadLatest() async {
    String? problem;

    for (var back = 0; back <= lookbackDays; back++) {
      final day = daysBefore(today, back);
      final RateSheet? sheet;
      try {
        sheet = BnmParser.parse(await _source.fetchDay(day), requestedDate: day);
      } on SourceUnavailableException catch (e) {
        problem = e.message;
        break;
      } on BnmFormatException catch (e) {
        problem = e.message;
        break;
      }

      // Remember the day for the charts. Today's "empty" is not final
      // (BNM publishes around 13:00), so it is not cached.
      if (sheet != null || back > 0) await _cache.saveDay(day, sheet);
      if (sheet == null) continue; // weekend / holiday / not published yet

      await _cache.saveLatest(sheet);
      return LatestRates(
        sheet,
        back == 0 ? RatesOrigin.live : RatesOrigin.earlierDay,
        notice: back == 0
            ? null
            : 'На сегодня курс ещё не опубликован. '
                'Используется последний доступный курс на ${formatDay(sheet.date)}.',
      );
    }

    problem ??= 'НБМ не публиковал курс последние $lookbackDays дней';

    final cached = await _cache.loadLatest();
    if (cached != null) {
      return LatestRates(
        cached,
        RatesOrigin.cache,
        notice: '$problem. Показан сохранённый курс на ${formatDay(cached.date)}.',
      );
    }
    throw NoRatesException(
      '$problem. Сохранённых курсов пока нет — подключитесь к интернету и обновите.',
    );
  }

  /// Rates of [from]/[to] for the last [days] calendar days including today.
  ///
  /// Days already in the cache are not requested again. Missing days are
  /// fetched from BNM in small parallel batches. Without network the result
  /// contains whatever is cached and [PairHistory.unloadedDays] > 0.
  Future<PairHistory> loadPairHistory({
    required String from,
    required String to,
    required int days,
  }) async {
    final end = today;
    final dates = [for (var back = days - 1; back >= 0; back--) daysBefore(end, back)];

    final known = <DateTime, RateSheet?>{};
    final toFetch = <DateTime>[];
    for (final day in dates) {
      final cached = await _cache.loadDay(day);
      // Today's "empty" is not final: BNM may still publish later in the day.
      final reliable = cached != null && !(cached.sheet == null && day == end);
      if (reliable) {
        known[day] = cached.sheet;
      } else {
        toFetch.add(day);
      }
    }

    String? problem;
    for (var i = 0; i < toFetch.length && problem == null; i += parallelRequests) {
      final batch = toFetch.sublist(i, math.min(i + parallelRequests, toFetch.length));
      final results = await Future.wait(batch.map(_fetchDay));
      for (var j = 0; j < batch.length; j++) {
        final result = results[j];
        if (result.error != null) {
          problem ??= result.error;
          continue;
        }
        known[batch[j]] = result.sheet;
        if (result.sheet != null || batch[j] != end) {
          await _cache.saveDay(batch[j], result.sheet);
        }
      }
    }

    final points = <RatePoint>[];
    for (final day in dates) {
      final sheet = known[day];
      if (sheet != null && sheet.contains(from) && sheet.contains(to)) {
        points.add(RatePoint(day, sheet.crossRate(from, to)));
      }
    }
    final unloaded = dates.where((d) => !known.containsKey(d)).length;

    return PairHistory(
      from: from,
      to: to,
      start: dates.first,
      end: end,
      points: points,
      unloadedDays: unloaded,
      notice: problem == null
          ? null
          : '$problem. Показаны сохранённые данные: не загружено дней — $unloaded из $days.',
    );
  }

  Future<({RateSheet? sheet, String? error})> _fetchDay(DateTime day) async {
    try {
      final body = await _source.fetchDay(day);
      return (sheet: BnmParser.parse(body, requestedDate: day), error: null);
    } on SourceUnavailableException catch (e) {
      return (sheet: null, error: e.message);
    } on BnmFormatException catch (e) {
      return (sheet: null, error: e.message);
    }
  }
}
