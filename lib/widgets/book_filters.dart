import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/book_query.dart';
import '../state/catalog_references.dart';

class BookFilters extends StatefulWidget {
  const BookFilters({super.key, required this.query, required this.onApply});
  final BookQuery query;
  final ValueChanged<BookQuery> onApply;
  @override
  State<BookFilters> createState() => _BookFiltersState();
}

class _BookFiltersState extends State<BookFilters> {
  final _form = GlobalKey<FormState>();
  final _from = TextEditingController();
  final _to = TextEditingController();
  int? _genre;
  int? _publisher;
  @override
  void initState() {
    super.initState();
    _sync();
  }

  void _sync() {
    _genre = widget.query.genreId;
    _publisher = widget.query.publisherId;
    _from.text = widget.query.yearFrom?.toString() ?? '';
    _to.text = widget.query.yearTo?.toString() ?? '';
  }

  @override
  void didUpdateWidget(covariant BookFilters oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget.query;
    final next = widget.query;
    if (old.genreId != next.genreId ||
        old.publisherId != next.publisherId ||
        old.yearFrom != next.yearFrom ||
        old.yearTo != next.yearTo) {
      _sync();
    }
  }

  @override
  void dispose() {
    _from.dispose();
    _to.dispose();
    super.dispose();
  }

  String? _year(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    final year = int.tryParse(text.trim());
    return year == null || year < 1 || year > 9999 ? 'Год от 1 до 9999' : null;
  }

  void _apply() {
    if (!_form.currentState!.validate()) return;
    widget.onApply(
      widget.query.copyWith(
        genreId: _genre,
        publisherId: _publisher,
        yearFrom: int.tryParse(_from.text.trim()),
        yearTo: int.tryParse(_to.text.trim()),
      ),
    );
  }

  Widget _dropdown(
    String label,
    int? value,
    Map<int, String> values,
    ValueChanged<int?> onChanged,
  ) {
    return DropdownButtonFormField<int>(
      key: ValueKey('$label-$value'),
      initialValue: value ?? 0,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        const DropdownMenuItem(value: 0, child: Text('Все')),
        if (value != null && !values.containsKey(value))
          DropdownMenuItem(value: value, child: Text('Неизвестный ID $value')),
        for (final entry in values.entries)
          DropdownMenuItem(value: entry.key, child: Text(entry.value)),
      ],
      onChanged: (id) => onChanged(id == 0 ? null : id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final refs = context.watch<CatalogReferences>();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _form,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final selectWidth = width < 500
                  ? width
                  : (width >= 1000 ? 230.0 : (width - 12) / 2);
              final yearWidth = width < 500 ? (width - 12) / 2 : 150.0;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Фильтры',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 12,
                    runSpacing: 16,
                    crossAxisAlignment: WrapCrossAlignment.start,
                    children: [
                      SizedBox(
                        width: selectWidth,
                        child: _dropdown(
                          'Жанр',
                          _genre,
                          refs.activeGenres,
                          (value) => setState(() => _genre = value),
                        ),
                      ),
                      SizedBox(
                        width: selectWidth,
                        child: _dropdown(
                          'Издательство',
                          _publisher,
                          refs.activePublishers,
                          (value) => setState(() => _publisher = value),
                        ),
                      ),
                      SizedBox(
                        width: yearWidth,
                        child: TextFormField(
                          key: const ValueKey('year-from'),
                          controller: _from,
                          decoration: const InputDecoration(
                            labelText: 'Год от',
                          ),
                          keyboardType: TextInputType.number,
                          validator: _year,
                          onFieldSubmitted: (_) => _apply(),
                        ),
                      ),
                      SizedBox(
                        width: yearWidth,
                        child: TextFormField(
                          key: const ValueKey('year-to'),
                          controller: _to,
                          decoration: const InputDecoration(
                            labelText: 'Год до',
                          ),
                          keyboardType: TextInputType.number,
                          validator: (text) {
                            final error = _year(text);
                            if (error != null) return error;
                            final from = int.tryParse(_from.text.trim());
                            final to = int.tryParse(text?.trim() ?? '');
                            return from != null && to != null && to < from
                                ? 'Меньше начала'
                                : null;
                          },
                          onFieldSubmitted: (_) => _apply(),
                        ),
                      ),
                      SizedBox(
                        height: 56,
                        child: FilledButton.tonal(
                          key: const ValueKey('apply-filters'),
                          onPressed: _apply,
                          child: const Text('Применить'),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
