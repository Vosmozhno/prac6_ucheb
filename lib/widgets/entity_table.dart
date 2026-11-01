import 'dart:math' as math;
import 'package:flutter/material.dart';

class TableColumnSpec<T> {
  const TableColumnSpec({
    required this.label,
    required this.build,
    this.sortField,
    this.numeric = false,
  });
  final String label;
  final String? sortField;
  final bool numeric;
  final Widget Function(T) build;
}

class EntityTable<T> extends StatefulWidget {
  const EntityTable({
    super.key,
    required this.columns,
    required this.items,
    required this.idOf,
    required this.isDeleted,
    required this.selected,
    required this.onToggleSelect,
    required this.onSelectAll,
    required this.sortField,
    required this.sortAscending,
    required this.onSort,
    required this.actions,
    this.enabled = true,
    this.selectable = true,
  });
  final List<TableColumnSpec<T>> columns;
  final List<T> items;
  final int Function(T) idOf;
  final bool Function(T) isDeleted;
  final Set<int> selected;
  final ValueChanged<int> onToggleSelect;
  final ValueChanged<bool> onSelectAll;
  final String sortField;
  final bool sortAscending;
  final ValueChanged<String> onSort;
  final Widget Function(T) actions;
  final bool enabled, selectable;

  @override
  State<EntityTable<T>> createState() => _EntityTableState<T>();
}

class _EntityTableState<T> extends State<EntityTable<T>> {
  final _vertical = ScrollController();
  final _horizontal = ScrollController();

  @override
  void dispose() {
    _vertical.dispose();
    _horizontal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final index = widget.columns.indexWhere(
      (c) => c.sortField == widget.sortField,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          height: math.min(580.0, 64.0 * widget.items.length + 70),
          child: Scrollbar(
            controller: _vertical,
            thumbVisibility: true,
            notificationPredicate: (n) => n.metrics.axis == Axis.vertical,
            child: SingleChildScrollView(
              controller: _vertical,
              child: Scrollbar(
                controller: _horizontal,
                thumbVisibility: true,
                notificationPredicate: (n) => n.metrics.axis == Axis.horizontal,
                child: SingleChildScrollView(
                  controller: _horizontal,
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: DataTable(
                      sortColumnIndex: index < 0 ? null : index,
                      sortAscending: widget.sortAscending,
                      showCheckboxColumn: widget.selectable,
                      onSelectAll: widget.enabled && widget.selectable
                          ? (value) => widget.onSelectAll(value ?? false)
                          : null,
                      headingRowHeight: 54,
                      dataRowMinHeight: 64,
                      dataRowMaxHeight: 76,
                      columnSpacing: 24,
                      horizontalMargin: 16,
                      headingRowColor: const WidgetStatePropertyAll(
                        Color(0xfff1f5fb),
                      ),
                      columns: [
                        for (final column in widget.columns)
                          DataColumn(
                            label: Text(
                              column.label,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            numeric: column.numeric,
                            onSort: column.sortField == null || !widget.enabled
                                ? null
                                : (_, _) => widget.onSort(column.sortField!),
                          ),
                        const DataColumn(label: Text('Действия')),
                      ],
                      rows: [
                        for (final item in widget.items)
                          DataRow(
                            key: ValueKey(widget.idOf(item)),
                            selected: widget.selected.contains(
                              widget.idOf(item),
                            ),
                            onSelectChanged:
                                !widget.enabled ||
                                    !widget.selectable ||
                                    widget.isDeleted(item)
                                ? null
                                : (_) =>
                                      widget.onToggleSelect(widget.idOf(item)),
                            color: widget.isDeleted(item)
                                ? const WidgetStatePropertyAll(
                                    Color(0xfff5f5f6),
                                  )
                                : null,
                            cells: [
                              for (final column in widget.columns)
                                DataCell(column.build(item)),
                              DataCell(widget.actions(item)),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
