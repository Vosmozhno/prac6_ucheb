import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/form_schema.dart';
import '../models/json_values.dart';
import '../state/catalog_references.dart';
import '../state/entity_form_notifier.dart';
import '../state/unsaved_changes_guard.dart';
import '../validation/validators.dart';
import '../widgets/feedback_panel.dart';
import '../widgets/library_scaffold.dart';

class EntityFormScreen extends StatefulWidget {
  const EntityFormScreen({super.key, required this.section, this.back});
  final String section;
  final String? back;
  @override
  State<EntityFormScreen> createState() => _EntityFormScreenState();
}

class _EntityFormScreenState extends State<EntityFormScreen> {
  final _form = GlobalKey<FormState>();
  final _text = <String, TextEditingController>{};
  late final EntityFormNotifier _state;
  late final UnsavedChangesGuard _guard;
  bool _initialized = false;
  String get _backPath {
    final uri = Uri.tryParse(widget.back ?? '');
    return uri != null &&
            !uri.hasScheme &&
            !uri.hasAuthority &&
            uri.path == '/${widget.section}'
        ? uri.toString()
        : '/${widget.section}';
  }

  @override
  void initState() {
    super.initState();
    _state = context.read<EntityFormNotifier>();
    _guard = context.read<UnsavedChangesGuard>();
    _guard.attach(_state);
  }

  @override
  void dispose() {
    _guard.detach(_state);
    for (final controller in _text.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _initializeControllers() {
    if (_initialized) return;
    for (final field in _state.fields) {
      if ([
        CatalogFieldKind.publisher,
        CatalogFieldKind.authors,
        CatalogFieldKind.genres,
      ].contains(field.kind)) {
        continue;
      }
      _text[field.key] = TextEditingController(
        text: _state.values[field.key]?.toString() ?? '',
      );
    }
    _initialized = true;
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) return;
    final saved = await _state.save();
    if (!mounted) return;
    if (saved == null) {
      _form.currentState?.validate();
      return;
    }
    context.go(
      Uri(
        path: '/${widget.section}/${saved.id}',
        queryParameters: {'back': _backPath},
      ).toString(),
    );
  }

  Widget _field(CatalogFieldSpec field, CatalogReferences refs) {
    final key = field.key;
    final value = _state.values[key];
    if (field.kind == CatalogFieldKind.publisher) {
      final selected = value is int && value > 0 ? value : null;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<int>(
            key: ValueKey('form-$key-$selected'),
            initialValue: selected,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: field.label,
              errorMaxLines: 3,
            ),
            items: [
              if (selected != null &&
                  !refs.activePublishers.containsKey(selected))
                DropdownMenuItem(
                  value: selected,
                  child: Text('Недоступное издательство #$selected'),
                ),
              for (final entry in refs.activePublishers.entries)
                DropdownMenuItem(value: entry.key, child: Text(entry.value)),
            ],
            onChanged: _state.busy
                ? null
                : (value) => _state.setValue(key, value),
            validator: (_) => _state.fieldError(key),
          ),
          if (_state.relatedLoading) const LinearProgressIndicator(),
          SwitchListTile.adaptive(
            key: const ValueKey('all-related-options'),
            contentPadding: EdgeInsets.zero,
            value: _state.showAllRelated,
            onChanged: _state.saving ? null : _state.setRelatedScope,
            title: const Text('Все авторы и жанры'),
            subtitle: const Text(
              'Выключите, чтобы сузить выбор по издательству',
            ),
          ),
        ],
      );
    }
    if (field.kind == CatalogFieldKind.authors ||
        field.kind == CatalogFieldKind.genres) {
      final options = field.kind == CatalogFieldKind.authors
          ? (_state.showAllRelated
                ? refs.activeAuthors
                : refs.availableAuthors(_state.publisherId))
          : (_state.showAllRelated
                ? refs.activeGenres
                : refs.availableGenres(_state.publisherId));
      return FormField<List<int>>(
        key: ValueKey(
          'form-$key-${_state.publisherId}-${_state.showAllRelated}',
        ),
        initialValue: JsonValues.ids(value),
        validator: (_) => _state.fieldError(key),
        builder: (formField) => InputDecorator(
          decoration: InputDecoration(
            labelText: field.label,
            errorText: formField.errorText,
            errorMaxLines: 3,
            helperMaxLines: 3,
            helperText: _state.showAllRelated || _state.publisherId == null
                ? 'Выберите одного или нескольких'
                : !refs.hasPublisherBooks(_state.publisherId)
                ? 'У издательства пока нет книг — доступны все значения'
                : 'Доступны значения из книг выбранного издательства',
          ),
          child: options.isEmpty
              ? const Text(
                  'Сначала добавьте записи в соответствующий справочник.',
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final entry in options.entries)
                      FilterChip(
                        key: ValueKey('choice-$key-${entry.key}'),
                        label: Text(entry.value),
                        selected: (formField.value ?? []).contains(entry.key),
                        onSelected: _state.saving
                            ? null
                            : (selected) {
                                final next = List<int>.of(
                                  formField.value ?? [],
                                );
                                selected
                                    ? next.add(entry.key)
                                    : next.remove(entry.key);
                                formField.didChange(next);
                                _state.setValue(key, next);
                              },
                      ),
                  ],
                ),
        ),
      );
    }
    return TextFormField(
      key: ValueKey('form-$key'),
      controller: _text[key],
      enabled: !_state.saving,
      maxLines: field.lines,
      keyboardType: switch (field.kind) {
        CatalogFieldKind.integer => TextInputType.number,
        CatalogFieldKind.email => TextInputType.emailAddress,
        CatalogFieldKind.phone => TextInputType.phone,
        CatalogFieldKind.date => TextInputType.datetime,
        _ => TextInputType.text,
      },
      decoration: InputDecoration(
        labelText: field.label,
        errorMaxLines: 3,
        hintText: field.kind == CatalogFieldKind.date
            ? 'ГГГГ-ММ-ДД'
            : field.hint,
        suffixIcon: field.kind != CatalogFieldKind.date
            ? null
            : IconButton(
                tooltip: 'Выбрать дату',
                onPressed: _state.saving
                    ? null
                    : () async {
                        final now = DateTime.now();
                        var initial =
                            Validators.parseDate(_text[key]!.text) ?? now;
                        final first = DateTime(1900);
                        final last = DateTime(now.year + 30, 12, 31);
                        if (initial.isBefore(first) || initial.isAfter(last)) {
                          initial = now;
                        }
                        final date = await showDatePicker(
                          context: context,
                          initialDate: initial,
                          firstDate: first,
                          lastDate: last,
                        );
                        if (date == null || !mounted) return;
                        final text = Validators.dateText(date);
                        _text[key]!.text = text;
                        _state.setValue(key, text);
                      },
                icon: const Icon(Icons.calendar_month_outlined),
              ),
      ),
      onChanged: (value) => _state.setValue(key, value),
      validator: (_) => _state.fieldError(key),
    );
  }

  Widget _fields(List<CatalogFieldSpec> fields, CatalogReferences refs) =>
      LayoutBuilder(
        builder: (context, constraints) => Wrap(
          spacing: 20,
          runSpacing: 24,
          children: [
            for (final field in fields)
              SizedBox(
                width: constraints.maxWidth < 740 || field.wide
                    ? constraints.maxWidth
                    : (constraints.maxWidth - 20) / 2,
                child: _field(field, refs),
              ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final refs = context.watch<CatalogReferences>();
    return ListenableBuilder(
      listenable: Listenable.merge([_state, _guard]),
      builder: (context, _) => PopScope<Object?>(
        canPop: _guard.canLeave,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop || !mounted) return;
          if (await _guard.confirm(context) && context.mounted) {
            context.go(_backPath);
          }
        },
        child: LibraryScaffold(
          section: widget.section,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(
              MediaQuery.sizeOf(context).width < 600 ? 16 : 24,
            ),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1040),
                child: _content(refs),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(CatalogReferences refs) {
    if (_state.loading) {
      return const Padding(
        padding: EdgeInsets.all(64),
        child: CircularProgressIndicator(),
      );
    }
    if (!_initialized && _state.error != null) {
      return FeedbackPanel(
        icon: Icons.description_outlined,
        title: 'Форма недоступна',
        message: _state.error!,
        action: OutlinedButton(
          onPressed: _state.load,
          child: const Text('Повторить'),
        ),
      );
    }
    _initializeControllers();
    final grouped = _state.fields
        .where((field) => field.group.isNotEmpty)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          onPressed: _state.saving ? null : () => context.go(_backPath),
          icon: const Icon(Icons.arrow_back),
          label: const Text('К списку'),
        ),
        const SizedBox(height: 16),
        Text(
          (_state.isEditing
              ? editFormTitles
              : createFormTitles)[widget.section]!,
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text('Проверьте поля и сохраните изменения.'),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _form,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _fields(
                    _state.fields
                        .where((field) => field.group.isEmpty)
                        .toList(),
                    refs,
                  ),
                  if (grouped.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    Text(
                      'Читательский билет',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    const Text('Билет принадлежит этому читателю.'),
                    const SizedBox(height: 24),
                    _fields(grouped, refs),
                  ],
                  if (_state.error != null) ...[
                    const SizedBox(height: 20),
                    Text(
                      _state.error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  if (_state.saving) const LinearProgressIndicator(),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        key: const ValueKey('save-entity'),
                        onPressed: _state.busy ? null : _save,
                        icon: const Icon(Icons.save_outlined),
                        label: Text(
                          _state.saving
                              ? 'Сохраняем…'
                              : _state.isEditing
                              ? 'Сохранить изменения'
                              : 'Создать',
                        ),
                      ),
                      OutlinedButton(
                        onPressed: _state.saving
                            ? null
                            : () => context.go(_backPath),
                        child: const Text('Отмена'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
