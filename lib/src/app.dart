import 'package:flutter/material.dart';

import 'app_state.dart';
import 'data/bnm_api.dart';
import 'data/rate_cache.dart';
import 'data/rate_repository.dart';
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
          title: const Text('Конвертер валют'),
          actions: [
            IconButton(
              tooltip: 'Обновить курсы',
              icon: const Icon(Icons.refresh),
              onPressed: _state.refreshRates,
            ),
          ],
        ),
        body: SafeArea(child: ConverterScreen(state: _state)),
      ),
    );
  }
}
