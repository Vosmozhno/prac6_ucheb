import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/app_user.dart';
import '../models/catalog_entity.dart';
import '../repositories/library_database.dart';
import '../state/auth_notifier.dart';
import '../state/author_list_notifier.dart';
import '../state/book_list_notifier.dart';
import '../state/reference_list_notifier.dart';
import 'api_session_button.dart';

class LibraryScaffold extends StatelessWidget {
  const LibraryScaffold({
    super.key,
    required this.child,
    this.section = 'books',
  });
  final Widget child;
  final String section;
  static const _icons = {
    '/': Icons.home_outlined,
    'books': Icons.menu_book_outlined,
    'authors': Icons.people_outline,
    'genres': Icons.category_outlined,
    'publishers': Icons.business_outlined,
    'readers': Icons.badge_outlined,
    '/my-loans': Icons.auto_stories_outlined,
    '/loans': Icons.assignment_outlined,
    '/admin/users': Icons.manage_accounts_outlined,
    '/admin/stats': Icons.bar_chart_outlined,
  };

  void _navigate(BuildContext context, String target) {
    if (!catalogSections.contains(target)) {
      context.go(target);
      return;
    }
    final query = switch (target) {
      'books' => context.read<BookListNotifier>().query,
      'authors' => context.read<AuthorListNotifier>().query,
      'genres' => context.read<GenreListNotifier>().query,
      'publishers' => context.read<PublisherListNotifier>().query,
      _ => context.read<ReaderListNotifier>().query,
    };
    context.go(query.toUri('/$target').toString());
  }

  Future<void> _more(BuildContext context, Map<String, String> entries) async {
    final target = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .7,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            children: [
              const ListTile(title: Text('Разделы библиотеки')),
              for (final entry in entries.entries)
                ListTile(
                  leading: Icon(_icons[entry.key]),
                  title: Text(entry.value),
                  onTap: () => Navigator.pop(context, entry.key),
                ),
            ],
          ),
        ),
      ),
    );
    if (context.mounted && target != null) _navigate(context, target);
  }

  bool _selected(String target) => switch (target) {
    '/' => section == 'home',
    '/admin/users' => section == 'users',
    '/admin/stats' => section == 'stats',
    _ => target.replaceFirst('/', '') == section,
  };

  @override
  Widget build(BuildContext context) {
    final database = context.watch<LibraryDatabase?>();
    final auth = context.watch<AuthNotifier>();
    final sections = {
      for (final target in catalogSections)
        if (target != 'readers' || auth.allows(Permission.readers))
          target: sectionTitles[target]!,
    };
    final primary = auth.enabled
        ? {
            '/': 'Главная',
            'books': 'Книги',
            if (auth.isRole(Role.reader)) '/my-loans': 'Мои выдачи',
            if (auth.isRole(Role.librarian)) '/loans': 'Выдачи',
            if (auth.isRole(Role.admin)) ...{
              '/admin/users': 'Пользователи',
              '/admin/stats': 'Статистика',
            },
          }
        : {'books': 'Книги', 'authors': 'Авторы', 'readers': 'Читатели'};
    final entries = {...primary, ...sections};
    final all = entries.entries.toList();
    final compact = primary.entries.toList();
    return LayoutBuilder(
      builder: (context, constraints) {
        final phone = constraints.maxWidth < 600;
        final extended = constraints.maxWidth >= 1100;
        final selected = all.indexWhere((e) => _selected(e.key));
        final selectedCompact = compact.indexWhere((e) => _selected(e.key));
        return Scaffold(
          appBar: AppBar(
            toolbarHeight: phone ? 64 : 72,
            titleSpacing: phone ? 16 : 24,
            title: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.local_library_outlined, size: 28),
                SizedBox(width: 10),
                Flexible(
                  child: Text(
                    'Библиотека',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            actions: const [ApiSessionButton(), SizedBox(width: 8)],
          ),
          bottomNavigationBar: phone
              ? NavigationBar(
                  key: const ValueKey('bottom-navigation'),
                  selectedIndex: selectedCompact < 0
                      ? compact.length
                      : selectedCompact,
                  labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                  onDestinationSelected: (index) => index == compact.length
                      ? _more(context, entries)
                      : _navigate(context, compact[index].key),
                  destinations: [
                    for (final entry in compact)
                      NavigationDestination(
                        icon: Icon(_icons[entry.key]),
                        label: entry.key == '/admin/users'
                            ? 'Роли'
                            : entry.value,
                        tooltip: entry.value,
                      ),
                    const NavigationDestination(
                      icon: Icon(Icons.more_horiz),
                      label: 'Ещё',
                      tooltip: 'Все разделы',
                    ),
                  ],
                )
              : null,
          body: SafeArea(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!phone) ...[
                  LayoutBuilder(
                    builder: (context, size) => SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: size.maxHeight),
                        child: IntrinsicHeight(
                          child: NavigationRail(
                            key: const ValueKey('side-navigation'),
                            extended: extended,
                            minWidth: 72,
                            minExtendedWidth: 216,
                            backgroundColor: Colors.white,
                            selectedIndex: selected < 0 ? null : selected,
                            onDestinationSelected: (i) =>
                                _navigate(context, all[i].key),
                            destinations: [
                              for (final entry in all)
                                NavigationRailDestination(
                                  icon: Tooltip(
                                    message: entry.value,
                                    excludeFromSemantics: true,
                                    child: Icon(_icons[entry.key]),
                                  ),
                                  label: Text(entry.value),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const VerticalDivider(width: 1),
                ],
                Expanded(
                  child: Column(
                    children: [
                      if (auth.warningSeconds != null)
                        _notice(
                          context,
                          'Сессия завершится через ${auth.warningSeconds} сек. из-за бездействия.',
                          'Продолжить работу',
                          auth.recordActivity,
                        ),
                      if (auth.notice != null && auth.loggedIn)
                        _notice(
                          context,
                          auth.notice!,
                          'Понятно',
                          auth.dismissNotice,
                        ),
                      if (auth.demoOverride)
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text(
                            'Учебная демонстрация: роль интерфейса изменена локально. Права API не изменены.',
                          ),
                        ),
                      if (database?.notice != null)
                        _notice(
                          context,
                          database!.notice!,
                          'Понятно',
                          database.dismissNotice,
                        ),
                      Expanded(
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            key: const ValueKey('content-width-limit'),
                            constraints: const BoxConstraints(maxWidth: 1320),
                            child: FocusTraversalGroup(child: child),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _notice(
    BuildContext context,
    String text,
    String action,
    VoidCallback onTap,
  ) => Material(
    color: Theme.of(context).colorScheme.secondaryContainer,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SizedBox(
        width: double.infinity,
        child: Wrap(
          spacing: 12,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(text),
            TextButton(onPressed: onTap, child: Text(action)),
          ],
        ),
      ),
    ),
  );
}
