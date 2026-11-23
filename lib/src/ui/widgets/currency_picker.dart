import 'package:flutter/material.dart';

/// Compact chip "USD ▾"; opens a searchable list of currencies in a bottom sheet.
class CurrencyChip extends StatelessWidget {
  const CurrencyChip({
    super.key,
    required this.code,
    required this.codes,
    required this.nameOf,
    required this.onSelected,
  });

  final String code;
  final List<String> codes;
  final String Function(String code) nameOf;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      shape: StadiumBorder(side: BorderSide(color: scheme.outlineVariant)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () async {
          final picked = await showModalBottomSheet<String>(
            context: context,
            isScrollControlled: true,
            showDragHandle: true,
            builder: (_) => _CurrencySheet(codes: codes, nameOf: nameOf, selected: code),
          );
          if (picked != null) onSelected(picked);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(code, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              const SizedBox(width: 4),
              const Icon(Icons.expand_more, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _CurrencySheet extends StatefulWidget {
  const _CurrencySheet({required this.codes, required this.nameOf, required this.selected});

  final List<String> codes;
  final String Function(String code) nameOf;
  final String selected;

  @override
  State<_CurrencySheet> createState() => _CurrencySheetState();
}

class _CurrencySheetState extends State<_CurrencySheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final visible = widget.codes
        .where((c) => q.isEmpty || c.toLowerCase().contains(q) || widget.nameOf(c).toLowerCase().contains(q))
        .toList();

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              autofocus: false,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Поиск: код или название',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: visible.isEmpty
                ? const Center(child: Text('Ничего не найдено'))
                : ListView.builder(
                    itemCount: visible.length,
                    itemBuilder: (context, i) {
                      final code = visible[i];
                      return ListTile(
                        leading: CircleAvatar(
                          radius: 18,
                          child: Text(code.substring(0, 2), style: const TextStyle(fontSize: 12)),
                        ),
                        title: Text(code),
                        subtitle: Text(widget.nameOf(code)),
                        trailing: code == widget.selected ? const Icon(Icons.check) : null,
                        onTap: () => Navigator.of(context).pop(code),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
