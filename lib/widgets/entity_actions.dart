import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_user.dart';
import '../state/auth_notifier.dart';

enum EntityAction { open, edit, softDelete, restore, hardDelete }

class EntityActions extends StatelessWidget {
  const EntityActions({
    super.key,
    required this.deleted,
    required this.onAction,
    this.enabled = true,
  });
  final bool deleted;
  final bool enabled;
  final ValueChanged<EntityAction> onAction;

  @override
  Widget build(BuildContext context) => PopupMenuButton<EntityAction>(
    tooltip: 'Действия с записью',
    enabled: enabled,
    onSelected: onAction,
    itemBuilder: (context) => [
      if (!deleted &&
          context.read<AuthNotifier>().allows(Permission.manageCatalog))
        const PopupMenuItem(
          value: EntityAction.edit,
          child: Text('Редактировать'),
        ),
      if (!deleted)
        const PopupMenuItem(
          value: EntityAction.open,
          child: Text('Открыть карточку'),
        ),
      if (!deleted &&
          context.read<AuthNotifier>().allows(Permission.manageCatalog))
        const PopupMenuItem(
          value: EntityAction.softDelete,
          child: Text('Удалить'),
        ),
      if (deleted && context.read<AuthNotifier>().allows(Permission.restore))
        const PopupMenuItem(
          value: EntityAction.restore,
          child: Text('Восстановить'),
        ),
      if (context.read<AuthNotifier>().allows(Permission.hardDelete))
        const PopupMenuItem(
          value: EntityAction.hardDelete,
          child: Text('Удалить навсегда'),
        ),
    ],
    icon: const Icon(Icons.more_horiz),
  );
}
