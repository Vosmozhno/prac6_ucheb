import '../models/app_user.dart';
import '../state/auth_notifier.dart';

String safeReturnPath(String? value) {
  final uri = Uri.tryParse(value ?? '');
  if (uri == null ||
      uri.hasScheme ||
      uri.hasAuthority ||
      !uri.path.startsWith('/') ||
      uri.path.startsWith('//') ||
      (value ?? '').contains('\\') ||
      ['/login', '/register'].contains(uri.path)) {
    return '/';
  }
  return uri.toString();
}

bool roleCanVisit(Role role, String path) {
  if (path == '/my-loans') return role == Role.reader;
  if (path == '/loans') return role == Role.librarian;
  if (path.startsWith('/admin/')) return role == Role.admin;
  if (path == '/readers' || path.startsWith('/readers/')) {
    return roleAllows(role, Permission.readers);
  }
  if (RegExp(
    r'^/(books|authors|genres|publishers)/(new|\d+/edit|\d+/issue)$',
  ).hasMatch(path)) {
    return roleAllows(role, Permission.manageCatalog);
  }
  return true;
}

String? authRedirect(AuthNotifier auth, Uri uri) {
  if (!auth.enabled) return null;
  final public = ['/login', '/register'].contains(uri.path);
  if (!auth.loggedIn && !public) {
    return Uri(
      path: '/login',
      queryParameters: {'from': uri.toString()},
    ).toString();
  }
  if (auth.loggedIn && public) {
    return safeReturnPath(uri.queryParameters['from']);
  }
  if (auth.loggedIn &&
      uri.path != '/forbidden' &&
      !roleCanVisit(auth.user!.role, uri.path)) {
    return '/forbidden';
  }
  return null;
}
