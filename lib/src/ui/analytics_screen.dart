import 'package:flutter/material.dart';

import '../app_state.dart';
import '../domain/dates.dart';
import '../domain/number_format.dart';
import '../domain/period_stats.dart';
import 'widgets/currency_picker.dart';
import 'widgets/rate_chart.dart';
import 'widgets/status_banner.dart';

/// "Неделя" (7 days) and "Месяц" (30 days) comparison screens.
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key, required this.state, required this.days});

  final AppState state;
  final int days;

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        // First visit, or the pair changed on another tab: load after this frame
        // (notifying listeners during build is not allowed).
        final current = widget.state.historyFor(widget.days);
        if (!current.loading && current.history == null && current.error == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) => widget.state.loadHistory(widget.days));
        }
        return _build(context, current);
      },
    );
  }

  Widget _build(BuildContext context, HistoryState current) {
    final state = widget.state;
    final theme = Theme.of(context);
    final history = current.history;
    final stats = history == null ? null : PeriodStats.compute(history.points);

    return RefreshIndicator(
      onRefresh: () => state.loadHistory(widget.days, force: true),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Row(
            children: [
              CurrencyChip(code: state.from, codes: state.codes, nameOf: state.nameOf, onSelected: state.setFrom),
              IconButton(
                tooltip: 'Поменять местами',
                onPressed: state.swap,
                icon: const Icon(Icons.swap_horiz),
              ),
              CurrencyChip(code: state.to, codes: state.codes, nameOf: state.nameOf, onSelected: state.setTo),
              const Spacer(),
              Text('${widget.days} дн.', style: theme.textTheme.labelLarge),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Сколько ${state.to} стоит 1 ${state.from} · курс НБМ',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          if (current.loading && history == null)
            _Loading(days: widget.days)
          else if (current.error != null)
            StatusBanner(
              message: current.error!,
              kind: BannerKind.error,
              actionLabel: 'Повторить',
              onAction: () => state.loadHistory(widget.days, force: true),
            )
          else if (history != null && stats == null)
            StatusBanner(
              message: history.notice ??
                  'За период ${formatDay(history.start)} – ${formatDay(history.end)} нет данных по этой паре.',
              kind: BannerKind.warning,
              actionLabel: 'Повторить',
              onAction: () => state.loadHistory(widget.days, force: true),
            )
          else if (history != null && stats != null) ...[
            _TrendHeader(stats: stats, to: state.to),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 16, 12, 8),
                child: RateChart(points: history.points, start: history.start, end: history.end),
              ),
            ),
            const SizedBox(height: 12),
            _StatsGrid(stats: stats),
            const SizedBox(height: 8),
            Text(
              'Период: ${formatDay(history.start)} – ${formatDay(history.end)} · '
              'дней с курсом: ${stats.count}. В выходные и праздники НБМ курс не публикует.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            if (history.notice != null) ...[
              const SizedBox(height: 12),
              StatusBanner(
                message: history.notice!,
                actionLabel: 'Повторить',
                onAction: () => state.loadHistory(widget.days, force: true),
              ),
            ],
            if (current.loading)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: LinearProgressIndicator(),
              ),
          ],
        ],
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading({required this.days});
  final int days;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Загружаем курсы за $days дн.…'),
          ],
        ),
      );
}

/// Big trend line: "Рост ↑ +0,1234 MDL (+0,69 %)".
class _TrendHeader extends StatelessWidget {
  const _TrendHeader({required this.stats, required this.to});

  final PeriodStats stats;
  final String to;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (Color color, IconData icon) = switch (stats.trend) {
      Trend.up => (const Color(0xFF0F6E56), Icons.trending_up),
      Trend.down => (const Color(0xFFA32D2D), Icons.trending_down),
      Trend.flat => (theme.colorScheme.onSurfaceVariant, Icons.trending_flat),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Тенденция: ${stats.trend.label.toLowerCase()}',
                  style: theme.textTheme.titleMedium?.copyWith(color: color, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '${formatSigned(stats.absoluteChange, decimals: 4)} $to '
                  '(${formatSigned(stats.percentChange)} %)',
                  style: theme.textTheme.bodyLarge?.copyWith(color: color),
                ),
              ],
            ),
          ),
          Text(
            formatNumber(stats.last.value, decimals: 4),
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});
  final PeriodStats stats;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      _Tile('Минимум', formatNumber(stats.min.value, decimals: 4), formatDay(stats.min.date), const Color(0xFF185FA5)),
      _Tile('Максимум', formatNumber(stats.max.value, decimals: 4), formatDay(stats.max.date), const Color(0xFFBA7517)),
      _Tile('Среднее', formatNumber(stats.average, decimals: 4), 'за ${stats.count} дн. с курсом', null),
      _Tile('Изменение', formatSigned(stats.absoluteChange, decimals: 4), 'с ${formatDay(stats.first.date)}', null),
      _Tile('Изменение, %', '${formatSigned(stats.percentChange)} %', 'к началу периода', null),
      _Tile('Начало → конец', '${formatNumber(stats.first.value, decimals: 4)} → ${formatNumber(stats.last.value, decimals: 4)}', '', null),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.9,
      children: tiles,
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.title, this.value, this.caption, this.accent);

  final String title;
  final String value;
  final String caption;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: theme.textTheme.labelMedium?.copyWith(color: accent ?? scheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          ),
          if (caption.isNotEmpty)
            Text(caption, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
