import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/list_query.dart';
import 'package:provider/provider.dart';
import '../models/app_user.dart';
import '../state/auth_notifier.dart';
import '../state/entity_list_notifier.dart';
import '../widgets/confirmation_dialog.dart';
import '../widgets/entity_actions.dart';
import '../widgets/entity_table.dart';
import '../widgets/feedback_panel.dart';
import '../widgets/library_scaffold.dart';
import '../widgets/pagination_bar.dart';
import '../widgets/adaptive_grid.dart';

class CatalogScreen<T, Q extends ListQuery> extends StatefulWidget {
  const CatalogScreen({
    super.key,
    required this.uri,
    required this.controller,
    required this.parseQuery,
    required this.path,
    required this.section,
    required this.title,
    required this.description,
    required this.searchHint,
    required this.titleOf,
    required this.summary,
    required this.columns,
    this.filters,
  });
  final Uri uri;
  final EntityListNotifier<T, Q> controller;
  final Q Function(Map<String, String>) parseQuery;
  final String path;
  final String section;
  final String title;
  final String description;
  final String searchHint;
  final String Function(T) titleOf;
  final String Function(T) summary;
  final List<TableColumnSpec<T>> Function(BuildContext, ValueChanged<T>)
  columns;
  final Widget Function(Q, ValueChanged<Q>)? filters;
  @override
  State<CatalogScreen<T, Q>> createState() => _CatalogScreenState<T, Q>();
}

class _CatalogScreenState<T, Q extends ListQuery>
    extends State<CatalogScreen<T, Q>> {
  late final TextEditingController _search;
  Timer? _debounce;
  EntityListNotifier<T, Q> get _state => widget.controller;
  bool get _canManage =>
      context.read<AuthNotifier>().allows(Permission.manageCatalog);
  @override
  void initState() {
    super.initState();
    _search = TextEditingController(
      text: widget.parseQuery(widget.uri.queryParameters).search,
    );
    _loadFromUri();
  }

  @override
  void didUpdateWidget(covariant CatalogScreen<T, Q> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uri != widget.uri || _state.needsReload) {
      _debounce?.cancel();
      final text = widget.parseQuery(widget.uri.queryParameters).search;
      if (_search.text != text) {
        _search.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
      }
      _loadFromUri();
    }
  }

  void _loadFromUri() {
    final uri = widget.uri;
    Future.microtask(() async {
      if (!mounted || uri != widget.uri) return;
      await _state.applyQuery(
        widget.parseQuery(uri.queryParameters),
        simulateError: uri.queryParameters['__fail'] == '500',
      );
      if (mounted && uri == widget.uri) _correctPage();
    });
  }

  void _correctPage() {
    if (!mounted || _state.status != LoadStatus.success) return;
    final requested = widget.parseQuery(widget.uri.queryParameters);
    if (requested.page != _state.query.page ||
        requested.size != _state.query.size) {
      Router.neglect(
        context,
        () => context.go(_state.query.toUri(widget.path).toString()),
      );
    }
  }

  void _go(Q query) {
    _debounce?.cancel();
    final searchChanged = _search.text.trim() != _state.query.search.trim();
    final merged =
        query.copyWith(
              search: _search.text,
              page: searchChanged ? 1 : query.page,
            )
            as Q;
    final target = merged.toUri(widget.path).toString();
    if (target != widget.uri.toString()) context.go(target);
  }

  void _reset() {
    _search.clear();
    _go(widget.parseQuery(const {}));
  }

  void _searchChanged(String text) {
    _debounce?.cancel();
    _state.cancelPending();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) _go(_state.updated(search: text));
    });
  }

  void _open(T item) {
    final id = _state.idOf(item);
    context.go(
      Uri(
        path: '${widget.path}/$id',
        queryParameters: {'back': widget.uri.toString()},
      ).toString(),
    );
  }

  Future<void> _action(T item, EntityAction action) async {
    if (action == EntityAction.open) {
      _open(item);
      return;
    }
    final id = _state.idOf(item);
    if (action == EntityAction.edit) {
      context.go(
        Uri(
          path: '${widget.path}/$id/edit',
          queryParameters: {'back': widget.uri.toString()},
        ).toString(),
      );
      return;
    }
    if (action == EntityAction.restore) {
      await _state.restore(id);
    } else {
      final hard = action == EntityAction.hardDelete;
      final confirmed = await confirmAction(
        context,
        title: hard ? 'Удалить навсегда?' : 'Удалить запись?',
        message:
            '«${widget.titleOf(item)}». ${hard ? 'Восстановить запись будет невозможно.' : 'Запись можно восстановить из списка удалённых.'}',
      );
      if (!confirmed || !mounted) return;
      if (hard) {
        await _state.hardDelete(id);
      } else {
        await _state.softDelete(id);
      }
    }
    if (mounted) _correctPage();
  }

  Future<void> _deleteSelected() async {
    final ids = _state.selected.toList();
    final count = ids.length;
    if (count == 0) return;
    final confirmed = await confirmAction(
      context,
      title: 'Удалить выбранные записи?',
      message: 'Выбрано: $count. Записи можно будет восстановить.',
    );
    if (!confirmed || !mounted) return;
    await _state.deleteIds(ids);
    if (mounted) _correctPage();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _state.cancelPending();
    _search.dispose();
    super.dispose();
  }

  Widget _toolbar() => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) => Wrap(
          spacing: 16,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: math.min(440, constraints.maxWidth),
              child: TextField(
                key: const ValueKey('catalog-search'),
                controller: _search,
                decoration: InputDecoration(
                  labelText: 'Поиск',
                  hintText: widget.searchHint,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    tooltip: 'Очистить поиск',
                    onPressed: () {
                      _search.clear();
                      _searchChanged('');
                    },
                    icon: const Icon(Icons.close),
                  ),
                ),
                onChanged: _searchChanged,
                onSubmitted: (text) => _go(_state.updated(search: text)),
              ),
            ),
            if (_canManage)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Switch(
                    key: const ValueKey('include-deleted'),
                    value: _state.query.includeDeleted,
                    onChanged: _state.busy
                        ? null
                        : (value) => _go(_state.updated(includeDeleted: value)),
                  ),
                  const Flexible(child: Text('Показать удалённые')),
                ],
              ),
            TextButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.restart_alt),
              label: const Text('Сбросить'),
            ),
            IconButton(
              tooltip: 'Обновить список',
              onPressed: _state.busy
                  ? null
                  : () async {
                      await _state.load();
                      if (mounted) _correctPage();
                    },
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
      ),
    ),
  );
  Widget _selection() {
    final count = _state.selected.length;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xffeaf1ff),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'Выбрано: $count',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          FilledButton.icon(
            key: const ValueKey('delete-selected'),
            onPressed: _state.busy ? null : _deleteSelected,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Удалить выбранные'),
          ),
          TextButton(
            onPressed: _state.clearSelection,
            child: const Text('Снять выделение'),
          ),
        ],
      ),
    );
  }

  Widget _content(bool mobile) {
    if (_state.status == LoadStatus.idle ||
        _state.status == LoadStatus.loading) {
      return const Card(
        child: SizedBox(
          width: double.infinity,
          height: 240,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text('Загружаем каталог…'),
            ],
          ),
        ),
      );
    }
    if (_state.status == LoadStatus.error) {
      return FeedbackPanel(
        icon: Icons.cloud_off_outlined,
        title: 'Не удалось загрузить данные',
        message: _state.error ?? 'Повторите запрос.',
        isError: true,
        action: FilledButton.icon(
          icon: const Icon(Icons.refresh),
          label: const Text('Повторить'),
          onPressed: () async {
            if (widget.uri.queryParameters.containsKey('__fail')) {
              _go(
                _state.query.copyWith(debugFail: null, debugDelay: null) as Q,
              );
            } else {
              await _state.load();
              if (mounted) _correctPage();
            }
          },
        ),
      );
    }
    if (_state.result.items.isEmpty) {
      return FeedbackPanel(
        icon: Icons.search_off,
        title: 'Ничего не найдено',
        message: 'Измените поисковый запрос или сбросьте фильтры.',
        action: OutlinedButton(
          onPressed: _reset,
          child: const Text('Сбросить фильтры'),
        ),
      );
    }
    Widget actions(T item) => EntityActions(
      deleted: _state.isDeleted(item),
      enabled: !_state.busy,
      onAction: (action) => _action(item, action),
    );
    if (mobile) {
      return AdaptiveGrid(
        key: const ValueKey('entity-cards'),
        children: _state.result.items.map((item) {
          final deleted = _state.isDeleted(item);
          final id = _state.idOf(item);
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_canManage)
                        Checkbox(
                          semanticLabel: 'Выбрать ${widget.titleOf(item)}',
                          value: _state.selected.contains(id),
                          onChanged: deleted || _state.busy
                              ? null
                              : (_) => _state.toggleSelection(id),
                        ),
                      Expanded(
                        child: TextButton(
                          style: TextButton.styleFrom(
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.all(8),
                          ),
                          onPressed: deleted ? null : () => _open(item),
                          child: Text(
                            widget.titleOf(item),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      actions(item),
                    ],
                  ),
                  if (deleted)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Удалено',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  Text(
                    widget.summary(item),
                    style: const TextStyle(height: 1.6),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      );
    }
    return Card(
      clipBehavior: Clip.antiAlias,
      child: EntityTable<T>(
        key: const ValueKey('entity-table'),
        columns: widget.columns(context, _open),
        items: _state.result.items,
        idOf: _state.idOf,
        isDeleted: _state.isDeleted,
        selectable: _canManage,
        selected: _state.selected,
        onToggleSelect: _state.toggleSelection,
        onSelectAll: _state.selectAll,
        enabled: !_state.busy,
        sortField: _state.query.sortField,
        sortAscending: _state.query.sortAscending,
        onSort: (field) => _go(
          _state.updated(
            sortField: field,
            sortAscending: field == _state.query.sortField
                ? !_state.query.sortAscending
                : true,
          ),
        ),
        actions: actions,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AuthNotifier>();
    final mobile = MediaQuery.sizeOf(context).width < 1100;
    return LibraryScaffold(
      section: widget.section,
      child: ListenableBuilder(
        listenable: _state,
        builder: (context, _) => SingleChildScrollView(
          key: const ValueKey('catalog-scroll'),
          padding: EdgeInsets.all(mobile ? 16 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_canManage)
                FilledButton.icon(
                  key: const ValueKey('create-entity'),
                  onPressed: _state.busy
                      ? null
                      : () => context.go(
                          Uri(
                            path: '${widget.path}/new',
                            queryParameters: {'back': widget.uri.toString()},
                          ).toString(),
                        ),
                  icon: const Icon(Icons.add),
                  label: const Text('Добавить запись'),
                ),
              const SizedBox(height: 16),
              Text(
                widget.title,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(widget.description),
              const SizedBox(height: 24),
              _toolbar(),
              if (widget.filters != null) ...[
                const SizedBox(height: 16),
                if (MediaQuery.sizeOf(context).width < 600)
                  ExpansionTile(
                    title: const Text('Фильтры каталога'),
                    maintainState: true,
                    children: [widget.filters!(_state.query, _go)],
                  )
                else
                  widget.filters!(_state.query, _go),
              ],
              const SizedBox(height: 20),
              if (_state.operationError != null) ...[
                FeedbackPanel(
                  icon: Icons.link_off,
                  title: 'Действие не выполнено',
                  message: _state.operationError!,
                  isError: true,
                  action: TextButton(
                    onPressed: _state.clearOperationError,
                    child: const Text('Закрыть'),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (_canManage && _state.selected.isNotEmpty) _selection(),
              if (_state.busy) const LinearProgressIndicator(),
              _content(mobile),
              if (_state.status == LoadStatus.success)
                PaginationBar(
                  page: _state.result.page,
                  totalPages: _state.result.totalPages,
                  total: _state.result.total,
                  size: _state.query.size,
                  enabled: !_state.busy,
                  onPage: (page) => _go(_state.updated(page: page)),
                  onSize: (size) => _go(_state.updated(size: size)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
