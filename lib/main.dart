import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'repositories/entity_repository.dart';
import 'repositories/library_database.dart';
import 'repositories/library_repositories.dart';
import 'core/api_client.dart';
import 'repositories/api_reference_cache.dart';
import 'state/api_session.dart';
import 'router.dart';
import 'state/author_list_notifier.dart';
import 'state/book_list_notifier.dart';
import 'state/catalog_references.dart';
import 'state/reference_list_notifier.dart';
import 'state/unsaved_changes_guard.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'repositories/account_repository.dart';
import 'widgets/session_watcher.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  final session = ApiSession(
    preferences: await SharedPreferences.getInstance(),
  );
  final client = ApiClient(buildDio(tokenProvider: () => session.token));
  session.client = client;
  await session.restore();
  runApp(LibraryApp(apiClient: client, apiSession: session));
}

class LibraryApp extends StatefulWidget {
  const LibraryApp({
    super.key,
    this.initialLocation,
    this.books,
    this.authors,
    this.database,
    this.apiClient,
    this.apiSession,
  });
  final String? initialLocation;
  final BookRepository? books;
  final AuthorRepository? authors;
  final LibraryDatabase? database;
  final ApiClient? apiClient;
  final ApiSession? apiSession;
  @override
  State<LibraryApp> createState() => _LibraryAppState();
}

class _LibraryAppState extends State<LibraryApp> {
  late final GoRouter _router = createAppRouter(
    initialLocation: widget.initialLocation,
    auth: _session,
  );
  late final LibraryDatabase? _database = widget.apiClient == null
      ? widget.database ?? LibraryDatabase.memory()
      : null;
  late final ApiReferenceCache? _cache = widget.apiClient == null
      ? null
      : ApiReferenceCache(widget.apiClient!);
  late final ApiSession _session =
      widget.apiSession ?? ApiSession(enabled: false);
  late final LibraryRepositories _repositories = widget.apiClient == null
      ? LibraryRepositories(
          _database!,
          books: widget.books,
          authors: widget.authors,
        )
      : LibraryRepositories.remote(widget.apiClient!, _cache!);
  late final CatalogReferences _references = CatalogReferences(
    database: _database,
    remote: _cache,
  );
  @override
  void dispose() {
    _router.dispose();
    _references.dispose();
    _cache?.dispose();
    if (widget.apiSession == null) _session.dispose();
    if (widget.database == null) _database?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MultiProvider(
    providers: [
      if (_database != null)
        ChangeNotifierProvider<LibraryDatabase>.value(value: _database),
      ChangeNotifierProvider<ApiSession>.value(value: _session),
      Provider<LibraryRepositories>.value(value: _repositories),
      if (widget.apiClient != null)
        Provider(create: (_) => AccountRepository(widget.apiClient!)),
      Provider<BookRepository>.value(value: _repositories.books),
      Provider<AuthorRepository>.value(value: _repositories.authors),
      ChangeNotifierProvider<CatalogReferences>.value(value: _references),
      ChangeNotifierProvider(create: (_) => UnsavedChangesGuard()),
      ChangeNotifierProvider(
        create: (context) => BookListNotifier(
          context.read<BookRepository>(),
          beforeLoad: _references.ensure,
        ),
      ),
      ChangeNotifierProvider(
        create: (context) => AuthorListNotifier(
          context.read<AuthorRepository>(),
          beforeLoad: _references.ensure,
        ),
      ),
      ChangeNotifierProvider(
        create: (_) => GenreListNotifier(
          _repositories.genres,
          beforeLoad: _references.ensure,
        ),
      ),
      ChangeNotifierProvider(
        create: (_) => PublisherListNotifier(
          _repositories.publishers,
          beforeLoad: _references.ensure,
        ),
      ),
      ChangeNotifierProvider(
        create: (_) => ReaderListNotifier(
          _repositories.readers,
          beforeLoad: _references.ensure,
        ),
      ),
    ],
    child: MaterialApp.router(
      title: 'Библиотека · Каталог',
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      builder: (_, child) => SessionWatcher(
        auth: _session,
        child: child ?? const SizedBox.shrink(),
      ),
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff2563eb)),
        fontFamily: 'Roboto',
        tooltipTheme: const TooltipThemeData(
          waitDuration: Duration(milliseconds: 400),
        ),
        navigationBarTheme: const NavigationBarThemeData(height: 72),
        scaffoldBackgroundColor: const Color(0xfff6f8fc),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xffe2e8f0)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xfffafbfe),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xffcbd5e1)),
          ),
        ),
      ),
    ),
  );
}
