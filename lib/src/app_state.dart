import 'package:flutter/foundation.dart';

import 'data/rate_repository.dart';
import 'domain/rate_sheet.dart';

/// Shared state of the whole app: latest rates and the selected pair. Screens listen to it via ListenableBuilder.
class AppState extends ChangeNotifier {
  AppState(this._repository);

  final RateRepository _repository;

  bool loadingRates = false;
  LatestRates? latest;
  String? ratesError;

  String from = 'USD';
  String to = RateSheet.baseCode;

  RateSheet? get sheet => latest?.sheet;

  List<String> get codes => sheet?.codes ?? const ['EUR', 'MDL', 'USD'];

  String nameOf(String code) => sheet?[code]?.name ?? code;

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
    notifyListeners();
  }

  /// A currency may disappear from the feed; fall back to a pair that exists.
  void _keepPairValid() {
    final available = sheet;
    if (available == null) return;
    if (!available.contains(from)) from = available.contains('USD') ? 'USD' : available.codes.first;
    if (!available.contains(to)) to = RateSheet.baseCode;
  }
}
