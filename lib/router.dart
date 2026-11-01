import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'models/catalog_entity.dart';
import 'models/genre.dart';
import 'models/publisher.dart';
import 'models/reader.dart';
import 'repositories/entity_repository.dart';
import 'repositories/library_repositories.dart';
import 'screens/author_detail_screen.dart';
import 'screens/author_list_screen.dart';
import 'screens/book_detail_screen.dart';
import 'screens/book_list_screen.dart';
import 'screens/entity_form_screen.dart';
import 'screens/not_found_screen.dart';
import 'screens/reference_detail_screen.dart';
import 'screens/reference_list_screen.dart';
import 'state/catalog_references.dart';
import 'state/entity_detail_notifier.dart';
import 'state/entity_form_notifier.dart';
import 'state/unsaved_changes_guard.dart';
import 'screens/loan_issue_screen.dart';
import 'state/loan_issue_notifier.dart';
import 'core/auth_policy.dart';
import 'state/auth_notifier.dart';
import 'state/account_notifier.dart';
import 'repositories/account_repository.dart';
import 'screens/auth_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/account_screen.dart' deferred as account;
import 'widgets/deferred_screen.dart';

GoRouter createAppRouter({
  String? initialLocation,
  AuthNotifier? auth,
}) => GoRouter(
  initialLocation: initialLocation,
  refreshListenable: auth,
  redirect: (_, state) => auth == null ? null : authRedirect(auth, state.uri),
  routes: [
    GoRoute(
      path: '/login',
      builder: (_, state) =>
          AuthScreen(from: state.uri.queryParameters['from']),
    ),
    GoRoute(
      path: '/register',
      builder: (_, state) =>
          AuthScreen(register: true, from: state.uri.queryParameters['from']),
    ),
    GoRoute(
      path: '/',
      redirect: (_, _) => auth?.enabled == true ? null : '/books',
      builder: (_, _) => const DashboardScreen(),
    ),
    GoRoute(path: '/forbidden', builder: (_, _) => const ForbiddenScreen()),
    for (final entry in {
      '/my-loans': 'my-loans',
      '/loans': 'loans',
      '/admin/users': 'users',
      '/admin/stats': 'stats',
    }.entries)
      GoRoute(
        path: entry.key,
        builder: (context, _) => ChangeNotifierProvider(
          create: (_) =>
              AccountNotifier(context.read<AccountRepository>(), entry.value)
                ..load(),
          child: DeferredScreen(
            load: account.loadLibrary,
            builder: (_) => account.AccountScreen(section: entry.value),
          ),
        ),
      ),
    for (final section in catalogSections)
      GoRoute(
        path: '/$section',
        builder: (_, state) => switch (section) {
          'books' => BookListScreen(uri: _listUri(state, section)),
          'authors' => AuthorListScreen(uri: _listUri(state, section)),
          _ => ReferenceListScreen(
            section: section,
            uri: _listUri(state, section),
          ),
        },
        routes: [
          if (section == 'books')
            GoRoute(
              path: ':id/issue',
              builder: (context, state) {
                final repositories = context.read<LibraryRepositories>();
                final id = int.tryParse(state.pathParameters['id'] ?? '') ?? -1;
                if (repositories.loans == null) {
                  return NotFoundScreen(location: state.uri.path);
                }
                return ChangeNotifierProvider(
                  create: (_) => LoanIssueNotifier(
                    repositories.loans!,
                    repositories.books,
                    id,
                  )..load(),
                  child: LoanIssueScreen(bookId: id),
                );
              },
            ),
          GoRoute(
            path: 'new',
            onExit: (context, _) => auth?.enabled == true && !auth!.loggedIn
                ? true
                : context.read<UnsavedChangesGuard>().confirm(context),
            builder: (context, state) => _form(context, state, section, null),
          ),
          GoRoute(
            path: ':id/edit',
            onExit: (context, _) => auth?.enabled == true && !auth!.loggedIn
                ? true
                : context.read<UnsavedChangesGuard>().confirm(context),
            builder: (context, state) => _form(
              context,
              state,
              section,
              int.tryParse(state.pathParameters['id'] ?? '') ?? -1,
            ),
          ),
          GoRoute(
            path: ':id',
            builder: (context, state) => _detail(context, state, section),
          ),
        ],
      ),
  ],
  errorBuilder: (_, state) => NotFoundScreen(location: state.uri.path),
);

Uri _listUri(GoRouterState state, String section) {
  if (state.uri.path == '/$section') return state.uri;
  final back = Uri.tryParse(state.uri.queryParameters['back'] ?? '');
  return back != null &&
          !back.hasScheme &&
          !back.hasAuthority &&
          back.path == '/$section'
      ? back
      : Uri(path: '/$section');
}

Widget _form(
  BuildContext context,
  GoRouterState state,
  String section,
  int? id,
) => ChangeNotifierProvider(
  key: ValueKey('form-$section-$id'),
  create: (context) => EntityFormNotifier(
    context.read<LibraryRepositories>(),
    context.read<CatalogReferences>(),
    section,
    id,
  )..load(),
  child: EntityFormScreen(
    section: section,
    back: state.uri.queryParameters['back'],
  ),
);

Widget _detail(BuildContext context, GoRouterState state, String section) {
  final id = int.tryParse(state.pathParameters['id'] ?? '') ?? -1;
  final back = state.uri.queryParameters['back'];
  final repositories = context.read<LibraryRepositories>();
  return switch (section) {
    'books' => ChangeNotifierProvider(
      key: ValueKey('book-$id'),
      create: (context) => BookDetailNotifier(
        context.read<BookRepository>(),
        beforeLoad: context.read<CatalogReferences>().ensure,
      )..load(id),
      child: BookDetailScreen(id: id, back: back),
    ),
    'authors' => ChangeNotifierProvider(
      key: ValueKey('author-$id'),
      create: (context) =>
          AuthorDetailNotifier(context.read<AuthorRepository>())..load(id),
      child: AuthorDetailScreen(id: id, back: back),
    ),
    'genres' => ChangeNotifierProvider(
      key: ValueKey('genre-$id'),
      create: (_) =>
          EntityDetailNotifier<Genre>(repositories.genres.findById)..load(id),
      child: ReferenceDetailScreen(section: section, id: id, back: back),
    ),
    'publishers' => ChangeNotifierProvider(
      key: ValueKey('publisher-$id'),
      create: (_) =>
          EntityDetailNotifier<Publisher>(repositories.publishers.findById)
            ..load(id),
      child: ReferenceDetailScreen(section: section, id: id, back: back),
    ),
    _ => ChangeNotifierProvider(
      key: ValueKey('reader-$id'),
      create: (_) =>
          EntityDetailNotifier<Reader>(repositories.readers.findById)..load(id),
      child: ReferenceDetailScreen(section: section, id: id, back: back),
    ),
  };
}
