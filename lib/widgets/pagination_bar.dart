import 'package:flutter/material.dart';
import '../models/list_query.dart';

class PaginationBar extends StatelessWidget {
  const PaginationBar({
    super.key,
    required this.page,
    required this.totalPages,
    required this.total,
    required this.size,
    required this.onPage,
    required this.onSize,
    this.enabled = true,
  });
  final int page;
  final int totalPages;
  final int total;
  final int size;
  final ValueChanged<int> onPage;
  final ValueChanged<int> onSize;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Wrap(
        spacing: 16,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Text('Всего записей: $total'),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('На странице: '),
              DropdownButton<int>(
                key: const ValueKey('page-size'),
                value: size,
                underline: const SizedBox.shrink(),
                items: [
                  for (final value in ListQuery.pageSizes)
                    DropdownMenuItem(value: value, child: Text('$value')),
                ],
                onChanged: !enabled
                    ? null
                    : (value) {
                        if (value != null) onSize(value);
                      },
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Первая страница',
                onPressed: enabled && page > 1 ? () => onPage(1) : null,
                icon: const Icon(Icons.first_page),
              ),
              IconButton(
                tooltip: 'Предыдущая страница',
                onPressed: enabled && page > 1 ? () => onPage(page - 1) : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text('$page / $totalPages'),
              ),
              IconButton(
                tooltip: 'Следующая страница',
                onPressed: enabled && page < totalPages
                    ? () => onPage(page + 1)
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
              IconButton(
                tooltip: 'Последняя страница',
                onPressed: enabled && page < totalPages
                    ? () => onPage(totalPages)
                    : null,
                icon: const Icon(Icons.last_page),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
