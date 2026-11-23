import '../domain/dates.dart';
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

/// Single entry point for rates: BNM first, the local cache as a fallback.
class RateRepository {
  RateRepository({
    required RateSource source,
    required RateCache cache,
    DateTime Function()? clock,
    this.lookbackDays = 10,
  })  : _source = source,
        _cache = cache,
        _clock = clock ?? DateTime.now;

  final RateSource _source;
  final RateCache _cache;
  final DateTime Function() _clock;

  /// How many days back to look when today has no published rates.
  final int lookbackDays;

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
}
