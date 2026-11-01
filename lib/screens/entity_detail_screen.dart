import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/list_query.dart';
import 'package:provider/provider.dart';
import '../models/app_user.dart';
import '../state/auth_notifier.dart';
import '../state/entity_detail_notifier.dart';
import '../state/entity_list_notifier.dart';
import '../widgets/confirmation_dialog.dart';
import '../widgets/detail_sheet.dart';
import '../widgets/feedback_panel.dart';
import '../widgets/library_scaffold.dart';

class EntityDetailScreen<T, Q extends ListQuery> extends StatelessWidget {
  const EntityDetailScreen({
    super.key,
    required this.controller,
    required this.listController,
    required this.id,
    required this.section,
    required this.titleOf,
    required this.fields,
    this.back,
    this.extraActions,
  });
  final EntityDetailNotifier<T> controller;
  final EntityListNotifier<T, Q> listController;
  final int id;
  final String section;
  final String Function(T) titleOf;
  final Map<String, String> Function(T) fields;
  final String? back;
  final Widget? extraActions;
  String get backPath {
    final uri = Uri.tryParse(back ?? '');
    return uri != null &&
            !uri.hasScheme &&
            !uri.hasAuthority &&
            uri.path == '/$section'
        ? uri.toString()
        : '/$section';
  }

  Future<void> _delete(BuildContext context, T item) async {
    final confirmed = await confirmAction(
      context,
      title: 'Удалить запись?',
      message: '«${titleOf(item)}». Запись можно будет восстановить.',
    );
    if (!confirmed || !context.mounted) return;
    final success = await listController.softDelete(id);
    if (!context.mounted) return;
    if (success) {
      context.go(backPath);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            listController.operationError ?? 'Не удалось удалить запись.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => LibraryScaffold(
    section: section,
    child: ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final item = controller.item;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextButton.icon(
                onPressed: () => context.go(backPath),
                icon: const Icon(Icons.arrow_back),
                label: const Text('К списку'),
              ),
              const SizedBox(height: 20),
              if (controller.status == LoadStatus.idle ||
                  controller.status == LoadStatus.loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(60),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (controller.status == LoadStatus.error || item == null)
                FeedbackPanel(
                  icon: Icons.description_outlined,
                  title: 'Запись недоступна',
                  message: controller.error ?? 'Запись не найдена.',
                  isError: true,
                  action: OutlinedButton(
                    onPressed: () => controller.load(id),
                    child: const Text('Повторить'),
                  ),
                )
              else ...[
                if (context.watch<AuthNotifier>().allows(
                  Permission.manageCatalog,
                ))
                  OutlinedButton.icon(
                    key: const ValueKey('edit-entity'),
                    onPressed: () => context.go(
                      Uri(
                        path: '/$section/$id/edit',
                        queryParameters: {'back': backPath},
                      ).toString(),
                    ),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Редактировать'),
                  ),
                const SizedBox(height: 16),
                if (extraActions != null) ...[
                  extraActions!,
                  const SizedBox(height: 16),
                ],
                DetailSheet(title: titleOf(item), fields: fields(item)),
                const SizedBox(height: 20),
                if (context.watch<AuthNotifier>().allows(
                  Permission.manageCatalog,
                ))
                  ListenableBuilder(
                    listenable: listController,
                    builder: (context, _) => OutlinedButton.icon(
                      onPressed: listController.busy
                          ? null
                          : () => _delete(context, item),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Удалить запись'),
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    ),
  );
}
