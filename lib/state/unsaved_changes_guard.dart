import 'package:flutter/material.dart';
import 'entity_form_notifier.dart';

class UnsavedChangesGuard extends ChangeNotifier {
  EntityFormNotifier? _form;
  bool _approved = false;
  Future<bool>? _pending;
  bool get canLeave =>
      _approved || _form == null || (!_form!.dirty && !_form!.saving);

  void attach(EntityFormNotifier form) {
    _form?.removeListener(_changed);
    _form = form;
    _approved = false;
    form.addListener(_changed);
  }

  void detach(EntityFormNotifier form) {
    if (!identical(_form, form)) return;
    _form?.removeListener(_changed);
    _form = null;
    _approved = false;
  }

  void _changed() {
    _approved = false;
    notifyListeners();
  }

  Future<bool> confirm(BuildContext context) async {
    if (_form?.saving ?? false) return false;
    if (canLeave) return true;
    if (_pending != null) return _pending!;
    final owner = _form;
    _pending = showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Есть несохранённые изменения'),
        content: const Text(
          'Если уйти со страницы, изменения в форме будут потеряны.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Остаться'),
          ),
          FilledButton(
            key: const ValueKey('discard-changes'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Уйти без сохранения'),
          ),
        ],
      ),
    ).then((value) => value ?? false);
    final confirmed = await _pending!;
    _pending = null;
    if (confirmed && identical(owner, _form)) {
      _approved = true;
      notifyListeners();
    }
    return confirmed;
  }
}
