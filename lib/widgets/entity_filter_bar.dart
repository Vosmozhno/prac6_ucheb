import 'package:flutter/material.dart';
import '../models/list_query.dart';

class EntityFilterBar extends StatelessWidget {
  const EntityFilterBar({
    super.key,
    required this.query,
    required this.label,
    required this.options,
    required this.onApply,
  });
  final ListQuery query;
  final String label;
  final Map<String, String> options;
  final ValueChanged<ListQuery> onApply;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: DropdownButtonFormField<String>(
          key: ValueKey('$label-${query.filter}'),
          initialValue: query.filter,
          isExpanded: true,
          decoration: InputDecoration(labelText: label),
          items: [
            const DropdownMenuItem(value: '', child: Text('Все')),
            if (query.filter.isNotEmpty && !options.containsKey(query.filter))
              DropdownMenuItem(value: query.filter, child: Text(query.filter)),
            for (final entry in options.entries)
              DropdownMenuItem(value: entry.key, child: Text(entry.value)),
          ],
          onChanged: (value) => onApply(query.copyWith(filter: value ?? '')),
        ),
      ),
    ),
  );
}
