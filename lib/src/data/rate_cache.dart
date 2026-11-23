import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/dates.dart';
import '../domain/rate_sheet.dart';

/// Minimal persistent key-value storage, so the cache can be tested without a device.
abstract interface class KeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

/// Real storage on the device (survives app restarts).
class SharedPrefsStore implements KeyValueStore {
  SharedPreferences? _prefs;

  Future<SharedPreferences> get _instance async =>
      _prefs ??= await SharedPreferences.getInstance();

  @override
  Future<String?> read(String key) async => (await _instance).getString(key);

  @override
  Future<void> write(String key, String value) async {
    await (await _instance).setString(key, value);
  }
}

/// In-memory storage for unit tests.
class MemoryStore implements KeyValueStore {
  final Map<String, String> data = {};

  @override
  Future<String?> read(String key) async => data[key];

  @override
  Future<void> write(String key, String value) async => data[key] = value;
}

/// A cached day: either rates, or a confirmed "BNM published nothing" (weekend/holiday).
class CachedDay {
  const CachedDay(this.sheet);

  /// `null` means the day is known to have no published rates.
  final RateSheet? sheet;
}

/// Local cache of BNM data.
///
/// * `latest` — the last successfully loaded sheet, shown when the source is unavailable.
/// * `day:yyyy-MM-dd` — every day loaded for the charts. Past rates never change,
///   so these entries are kept forever and the week/month screens work offline.
class RateCache {
  RateCache(this._store);

  final KeyValueStore _store;

  static const String _latestKey = 'latest_sheet';
  static const String _emptyMarker = 'EMPTY';
  static String _dayKey(DateTime day) => 'day:${dayKey(day)}';

  Future<void> saveLatest(RateSheet sheet) async {
    if (!sheet.hasForeignRates) return; // never replace good data with nothing
    await _store.write(_latestKey, jsonEncode(sheet.toJson()));
  }

  /// Returns null if nothing is cached or the stored value is damaged.
  Future<RateSheet?> loadLatest() async => _decode(await _store.read(_latestKey));

  Future<void> saveDay(DateTime day, RateSheet? sheet) async {
    final value = sheet == null ? _emptyMarker : jsonEncode(sheet.toJson());
    await _store.write(_dayKey(day), value);
  }

  /// Null when the day was never loaded (or the entry is damaged).
  Future<CachedDay?> loadDay(DateTime day) async {
    final raw = await _store.read(_dayKey(day));
    if (raw == null) return null;
    if (raw == _emptyMarker) return const CachedDay(null);
    final sheet = _decode(raw);
    return sheet == null ? null : CachedDay(sheet);
  }

  RateSheet? _decode(String? raw) {
    if (raw == null) return null;
    try {
      return RateSheet.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on Object {
      // FormatException, TypeError, missing fields — treat as "no cache".
      return null;
    }
  }
}
