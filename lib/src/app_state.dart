import 'package:flutter/foundation.dart';

import 'data/rate_repository.dart';
import 'domain/rate_sheet.dart';

/// Loading state of one comparison period (7 or 30 days).
class HistoryState {
  const HistoryState({this.loading = false, this.history, this.error});

  final bool loading;
  final PairHistory? history;
  final String? error;
}

/// Shared state of the whole app: latest rates, the selected pair and
/// cached history per period. Screens listen to it via ListenableBuilder.
class AppState extends ChangeNotifier {
  AppState(this._repository);

  final RateRepository _repository;

  bool loadingRates = false;
  LatestRates? latest;
  String? ratesError;

  String from = 'USD';
  String to = RateSheet.baseCode;

  final Map<int, HistoryState> _history = {};

  RateSheet? get sheet => latest?.sheet;

  List<String> get codes => sheet?.codes ?? const ['EUR', 'MDL', 'USD'];

  String nameOf(String code) => sheet?[code]?.name ?? code;

  HistoryState historyFor(int days) => _history[days] ?? const HistoryState();

  Future<void> refreshRates() async {
    if (loadingRates) return;
    loadingRates = true;
    ratesError = null;
    notifyListeners();
    try {
      latest = await _repository.loadLatest();
      _keepPairValid();
    } on NoRatesException catch (e) {
      ratesError = e.message;
    } catch (e) {
      ratesError = 'Не удалось загрузить курсы. Попробуйте ещё раз.';
    } finally {
      loadingRates = false;
      notifyListeners();
    }
  }

  void setFrom(String code) => _setPair(code, to);
  void setTo(String code) => _setPair(from, code);
  void swap() => _setPair(to, from);

  void _setPair(String newFrom, String newTo) {
    if (newFrom == from && newTo == to) return;
    from = newFrom;
    to = newTo;
    _history.clear(); // charts are per pair
    notifyListeners();
  }

  /// A currency may disappear from the feed; fall back to a pair that exists.
  void _keepPairValid() {
    final available = sheet;
    if (available == null) return;
    if (!available.contains(from)) from = available.contains('USD') ? 'USD' : available.codes.first;
    if (!available.contains(to)) to = RateSheet.baseCode;
  }

  /// Loads history once per pair and period; [force] reloads it.
  Future<void> loadHistory(int days, {bool force = false}) async {
    final current = historyFor(days);
    if (current.loading) return;
    if (!force && current.history != null) return;

    final pairFrom = from;
    final pairTo = to;
    _history[days] = HistoryState(loading: true, history: current.history);
    notifyListeners();

    HistoryState next;
    try {
      final history = await _repository.loadPairHistory(from: pairFrom, to: pairTo, days: days);
      next = HistoryState(history: history);
    } catch (e) {
      next = const HistoryState(error: 'Не удалось загрузить историю курса.');
    }
    // The user may have switched the pair while we were loading.
    if (pairFrom == from && pairTo == to) {
      _history[days] = next;
      notifyListeners();
    }
  }
}
