import 'package:flutter/material.dart';

import 'app_state.dart';
import 'data/bnm_api.dart';
import 'data/rate_cache.dart';
import 'data/rate_repository.dart';
import 'ui/analytics_screen.dart';
import 'ui/converter_screen.dart';

class CurrencyApp extends StatefulWidget {
  const CurrencyApp({super.key, this.state});

  /// Injected in widget tests; the real app builds its own.
  final AppState? state;

  @override
  State<CurrencyApp> createState() => _CurrencyAppState();
}

class _CurrencyAppState extends State<CurrencyApp> {
  late final AppState _state = widget.state ??
      AppState(
        RateRepository(
          source: BnmApi(),
          cache: RateCache(SharedPrefsStore()),
        ),
      );

  int _tab = 0;

  @override
  void initState() {
    super.initState();
    if (widget.state == null) _state.refreshRates();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Курсы НБМ',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF0F6E56),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF0F6E56),
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: Text(const ['Конвертер валют', 'Курс за неделю', 'Курс за месяц'][_tab]),
          actions: [
            IconButton(
              tooltip: 'Обновить курсы',
              icon: const Icon(Icons.refresh),
              onPressed: () {
                _state.refreshRates();
                if (_tab > 0) _state.loadHistory(_tab == 1 ? 7 : 30, force: true);
              },
            ),
          ],
        ),
        body: SafeArea(
          child: switch (_tab) {
            1 => AnalyticsScreen(key: const ValueKey(7), state: _state, days: 7),
            2 => AnalyticsScreen(key: const ValueKey(30), state: _state, days: 30),
            _ => ConverterScreen(state: _state),
          },
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.currency_exchange), label: 'Конвертер'),
            NavigationDestination(icon: Icon(Icons.show_chart), label: 'Неделя'),
            NavigationDestination(icon: Icon(Icons.calendar_month), label: 'Месяц'),
          ],
        ),
      ),
    );
  }
}
