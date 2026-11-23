import 'package:flutter/material.dart';

import '../app_state.dart';
import '../data/rate_repository.dart';
import '../domain/amount_input.dart';
import '../domain/dates.dart';
import '../domain/number_format.dart';
import 'widgets/currency_picker.dart';
import 'widgets/status_banner.dart';

class ConverterScreen extends StatefulWidget {
  const ConverterScreen({super.key, required this.state});

  final AppState state;

  @override
  State<ConverterScreen> createState() => _ConverterScreenState();
}

class _ConverterScreenState extends State<ConverterScreen> {
  final _amount = TextEditingController(text: '100');

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.state, _amount]),
      builder: (context, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final state = widget.state;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final input = parseAmount(_amount.text);
    final sheet = state.sheet;

    double? result;
    if (input is ValidAmount && sheet != null) {
      result = sheet.convert(input.value, state.from, state.to);
    }
    final errorText = switch (input) {
      InvalidAmount(isEmpty: false, :final message) => message,
      _ => null,
    };

    return RefreshIndicator(
      onRefresh: state.refreshRates,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _Panel(
            label: 'Отдаю',
            trailing: CurrencyChip(
              code: state.from,
              codes: state.codes,
              nameOf: state.nameOf,
              onSelected: state.setFrom,
            ),
            child: TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: theme.textTheme.headlineMedium,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: '0',
                errorText: errorText,
                isDense: true,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Center(
              child: IconButton.filled(
                tooltip: 'Поменять валюты местами',
                onPressed: state.swap,
                icon: const Icon(Icons.swap_vert),
              ),
            ),
          ),
          _Panel(
            label: 'Получаю',
            trailing: CurrencyChip(
              code: state.to,
              codes: state.codes,
              nameOf: state.nameOf,
              onSelected: state.setTo,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                result == null ? '—' : formatNumber(result),
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (sheet != null) ...[
            Text(
              '1 ${state.from} = ${formatNumber(sheet.crossRate(state.from, state.to), decimals: 4)} ${state.to}',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Курс на ${formatDay(sheet.date)} · Источник: Национальный банк Молдовы',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
          ],
          if (state.loadingRates)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (state.latest?.notice != null)
            StatusBanner(
              message: state.latest!.notice!,
              kind: state.latest!.origin == RatesOrigin.cache ? BannerKind.warning : BannerKind.info,
              actionLabel: state.latest!.origin == RatesOrigin.cache ? 'Обновить' : null,
              onAction: state.refreshRates,
            ),
          if (state.ratesError != null)
            StatusBanner(
              message: state.ratesError!,
              kind: BannerKind.error,
              actionLabel: 'Повторить',
              onAction: state.refreshRates,
            ),
        ],
      ),
    );
  }
}

/// Rounded panel with a caption, a currency chip and content.
class _Panel extends StatelessWidget {
  const _Panel({required this.label, required this.trailing, required this.child});

  final String label;
  final Widget trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: scheme.onSurfaceVariant)),
          Row(
            children: [
              Expanded(child: child),
              const SizedBox(width: 8),
              trailing,
            ],
          ),
        ],
      ),
    );
  }
}
