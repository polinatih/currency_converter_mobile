import 'package:flutter/material.dart';

enum BannerKind { info, warning, error }

/// Coloured message box for notices (cached / earlier-day data) and errors.
class StatusBanner extends StatelessWidget {
  const StatusBanner({
    super.key,
    required this.message,
    this.kind = BannerKind.warning,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final BannerKind kind;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (Color background, Color foreground, IconData icon) = switch (kind) {
      BannerKind.info => (scheme.secondaryContainer, scheme.onSecondaryContainer, Icons.info_outline),
      BannerKind.warning => (const Color(0xFFFAEEDA), const Color(0xFF633806), Icons.cloud_off_outlined),
      BannerKind.error => (scheme.errorContainer, scheme.onErrorContainer, Icons.error_outline),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: foreground),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: TextStyle(color: foreground, height: 1.3)),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(foregroundColor: foreground),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}
