import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/app_user.dart';
import '../models/json_values.dart';
import '../state/account_notifier.dart';
import '../state/auth_notifier.dart';
import '../widgets/confirmation_dialog.dart';
import '../widgets/feedback_panel.dart';
import '../widgets/library_scaffold.dart';
import '../widgets/adaptive_grid.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key, required this.section});
  final String section;
  String get title => switch (section) {
    'users' => 'Пользователи и роли',
    'stats' => 'Статистика библиотеки',
    'my-loans' => 'Мои выдачи',
    _ => 'Рабочее место библиотекаря',
  };
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AccountNotifier>();
    final auth = context.watch<AuthNotifier>();
    return LibraryScaffold(
      section: section,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  tooltip: 'Обновить',
                  onPressed: state.loading || state.busy
                      ? null
                      : () => state.load(),
                  icon: const Icon(Icons.refresh),
                ),
                if (section == 'loans')
                  FilledButton.icon(
                    onPressed: () => context.go('/books'),
                    icon: const Icon(Icons.add),
                    label: const Text('Оформить выдачу из каталога'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (state.message != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  state.message!,
                  key: const ValueKey('account-success'),
                ),
              ),
            if (state.error != null) ...[
              FeedbackPanel(
                icon: Icons.lock_outline,
                title: 'Не удалось выполнить действие',
                message: state.error!,
                isError: true,
                action: OutlinedButton(
                  onPressed: () => state.load(),
                  child: const Text('Повторить'),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (state.loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (section == 'stats')
              AdaptiveGrid(
                children: [
                  for (final entry in {
                    'books': 'Книги',
                    'readers': 'Читатели',
                    'users': 'Пользователи',
                    'activeLoans': 'Активные выдачи',
                    'overdueLoans': 'Просроченные выдачи',
                  }.entries)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(entry.value),
                            const SizedBox(height: 12),
                            Text(
                              '${state.statistics[entry.key] ?? '—'}',
                              style: Theme.of(context).textTheme.headlineLarge,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              )
            else ...[
              if (state.items.isEmpty && state.error == null)
                const FeedbackPanel(
                  icon: Icons.inbox_outlined,
                  title: 'Записей пока нет',
                  message: 'Здесь появятся доступные вам записи.',
                ),
              for (final item in state.items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: section == 'users'
                          ? _user(context, state, auth, AppUser.fromJson(item))
                          : _loan(context, state, item),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('Всего: ${state.total}'),
                  IconButton(
                    tooltip: 'Предыдущая страница',
                    onPressed: state.page > 1 && !state.busy
                        ? () => state.load(requestedPage: state.page - 1)
                        : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text('${state.page} / ${state.totalPages}'),
                  IconButton(
                    tooltip: 'Следующая страница',
                    onPressed: state.page < state.totalPages && !state.busy
                        ? () => state.load(requestedPage: state.page + 1)
                        : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _user(
    BuildContext context,
    AccountNotifier state,
    AuthNotifier auth,
    AppUser user,
  ) => Wrap(
    spacing: 24,
    runSpacing: 12,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      SizedBox(
        width: MediaQuery.sizeOf(context).width < 600 ? 240 : 300,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user.fullName, style: Theme.of(context).textTheme.titleMedium),
            Text('Логин: ${user.username}'),
          ],
        ),
      ),
      SizedBox(
        width: 240,
        child: DropdownButtonFormField<Role>(
          key: ValueKey('role-${user.id}-${user.role.value}'),
          initialValue: user.role,
          decoration: const InputDecoration(labelText: 'Роль'),
          isExpanded: true,
          items: [
            for (final role in Role.values)
              DropdownMenuItem(value: role, child: Text(role.label)),
          ],
          onChanged: state.busy || user.id == auth.user?.id
              ? null
              : (role) async {
                  if (role == null || role == user.role) return;
                  final confirmed = await confirmAction(
                    context,
                    title: 'Изменить роль?',
                    actionLabel: 'Изменить роль',
                    message:
                        '${user.username}: ${role.label}. Права изменятся на сервере.',
                  );
                  if (confirmed) {
                    await state.act(
                      () => state.repository.changeRole(user.id, role.value),
                      'Роль пользователя обновлена.',
                    );
                  } else {
                    await state.load();
                  }
                },
        ),
      ),
      if (user.id == auth.user?.id) const Text('Ваша учётная запись'),
    ],
  );
  Widget _loan(
    BuildContext context,
    AccountNotifier state,
    Map<String, dynamic> loan,
  ) {
    final book = JsonValues.map(loan['book']),
        reader = JsonValues.map(loan['reader']);
    final closed = loan['returnedAt'] != null;
    final status = switch (loan['status']) {
      'returned' => 'Возвращена',
      'overdue' => 'Просрочена',
      _ => 'На руках',
    };
    final due = JsonValues.string(loan['dueAt']);
    final id = JsonValues.integer(loan['id']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          JsonValues.string(book['title']),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text('Выдача №$id · $status'),
        if (section == 'loans') Text('Читатель: ${reader['fullName']}'),
        Text('Вернуть до: ${due.length >= 10 ? due.substring(0, 10) : due}'),
        if (!closed) ...[
          const SizedBox(height: 16),
          if (section == 'my-loans' && loan['renewedAt'] == null)
            FilledButton.tonalIcon(
              onPressed: state.busy
                  ? null
                  : () => state.act(
                      () => state.repository.renew(id),
                      'Выдача продлена на 14 дней.',
                    ),
              icon: const Icon(Icons.update),
              label: const Text('Продлить на 14 дней'),
            ),
          if (section == 'my-loans' && loan['renewedAt'] != null)
            const Text('Продление уже использовано'),
          if (section == 'loans')
            FilledButton.tonalIcon(
              onPressed: state.busy
                  ? null
                  : () async {
                      final confirmed = await confirmAction(
                        context,
                        title: 'Закрыть выдачу?',
                        actionLabel: 'Оформить возврат',
                        message: 'Книга возвращена читателем?',
                      );
                      if (confirmed) {
                        await state.act(
                          () => state.repository.close(id),
                          'Возврат книги оформлен.',
                        );
                      }
                    },
              icon: const Icon(Icons.assignment_turned_in_outlined),
              label: const Text('Закрыть выдачу'),
            ),
        ],
      ],
    );
  }
}
