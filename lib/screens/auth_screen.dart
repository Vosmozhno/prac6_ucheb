import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../state/auth_notifier.dart';

List<bool> passwordChecks(String value) => [
  value.length >= 8,
  RegExp(r'\d').hasMatch(value),
  RegExp(r'[^\p{L}\p{N}\s]', unicode: true).hasMatch(value),
];
String? validatePassword(String? value) =>
    passwordChecks(value ?? '').every((v) => v)
    ? null
    : 'Нужно 8 символов, цифра и специальный символ.';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.register = false, this.from});
  final bool register;
  final String? from;
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _username = TextEditingController(),
      _password = TextEditingController();
  final _name = TextEditingController(),
      _email = TextEditingController(),
      _confirm = TextEditingController();
  bool _obscure = true;
  String _location(bool register) => Uri(
    path: register ? '/register' : '/login',
    queryParameters: widget.from == null ? null : {'from': widget.from!},
  ).toString();
  @override
  void dispose() {
    for (final value in [_username, _password, _name, _email, _confirm]) {
      value.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final auth = context.read<AuthNotifier>();
    FocusScope.of(context).unfocus();
    if (widget.register) {
      final success = await auth.register({
        'username': _username.text.trim(),
        'password': _password.text,
        'fullName': _name.text.trim(),
        'email': _email.text.trim(),
      });
      if (success && mounted) context.go(_location(false));
    } else {
      await auth.login(_username.text, _password.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    Widget field(
      String key,
      TextEditingController controller,
      String label, {
      String? Function(String?)? validator,
      bool secret = false,
      Iterable<String>? hints,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        key: ValueKey('auth-$key'),
        controller: controller,
        enabled: !auth.busy,
        obscureText: secret && _obscure,
        autofillHints: hints,
        keyboardType: key == 'email'
            ? TextInputType.emailAddress
            : TextInputType.text,
        textInputAction: key == 'password' && !widget.register
            ? TextInputAction.done
            : TextInputAction.next,
        onFieldSubmitted: (_) {
          if (!widget.register && key == 'password') _submit();
        },
        autovalidateMode: AutovalidateMode.onUserInteraction,
        onChanged: (_) => setState(() {
          auth.fieldErrors.remove(key);
        }),
        validator: (value) => validator?.call(value) ?? auth.fieldErrors[key],
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: secret && key == 'password'
              ? IconButton(
                  tooltip: _obscure ? 'Показать пароль' : 'Скрыть пароль',
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                )
              : null,
        ),
      ),
    );
    String? required(String? v) =>
        (v ?? '').trim().isEmpty ? 'Заполните поле.' : null;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: AutofillGroup(
                child: Form(
                  key: _form,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.local_library_outlined, size: 40),
                          const SizedBox(height: 16),
                          Text(
                            widget.register
                                ? 'Регистрация'
                                : 'Вход в библиотеку',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.register
                                ? 'Создайте учётную запись читателя.'
                                : 'Войдите, чтобы продолжить работу.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          if (auth.notice != null) ...[
                            Text(
                              auth.notice!,
                              key: const ValueKey('session-message'),
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (widget.register)
                            field(
                              'fullName',
                              _name,
                              'Имя и фамилия',
                              validator: required,
                              hints: [AutofillHints.name],
                            ),
                          field(
                            'username',
                            _username,
                            'Логин',
                            validator: widget.register
                                ? (v) =>
                                      RegExp(
                                        r'^[a-zA-Z0-9_.-]{3,40}$',
                                      ).hasMatch(v ?? '')
                                      ? null
                                      : 'От 3 до 40 латинских букв, цифр, точек, дефисов.'
                                : required,
                            hints: [AutofillHints.username],
                          ),
                          if (widget.register)
                            field(
                              'email',
                              _email,
                              'Электронная почта',
                              validator: (v) =>
                                  RegExp(
                                    r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                                  ).hasMatch(v ?? '')
                                  ? null
                                  : 'Укажите корректную почту.',
                              hints: [AutofillHints.email],
                            ),
                          field(
                            'password',
                            _password,
                            'Пароль',
                            secret: true,
                            validator: widget.register
                                ? validatePassword
                                : required,
                            hints: [
                              widget.register
                                  ? AutofillHints.newPassword
                                  : AutofillHints.password,
                            ],
                          ),
                          if (widget.register) ...[
                            for (final (index, label) in [
                              'Не менее 8 символов',
                              'Есть цифра',
                              'Есть специальный символ',
                            ].indexed)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    Icon(
                                      passwordChecks(_password.text)[index]
                                          ? Icons.check_circle_outline
                                          : Icons.radio_button_unchecked,
                                      size: 20,
                                      color:
                                          passwordChecks(_password.text)[index]
                                          ? Colors.green.shade800
                                          : null,
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(child: Text(label)),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 8),
                            field(
                              'confirm',
                              _confirm,
                              'Повторите пароль',
                              secret: true,
                              validator: (v) =>
                                  v != _password.text || (v ?? '').isEmpty
                                  ? 'Пароли должны совпадать.'
                                  : null,
                            ),
                          ],
                          if (auth.error != null) ...[
                            Text(
                              auth.error!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          FilledButton(
                            onPressed: auth.busy ? null : _submit,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(
                                auth.busy
                                    ? 'Подождите…'
                                    : widget.register
                                    ? 'Зарегистрироваться'
                                    : 'Войти',
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: auth.busy
                                ? null
                                : () {
                                    auth.error = null;
                                    auth.fieldErrors = {};
                                    auth.notice = null;
                                    context.go(_location(!widget.register));
                                  },
                            child: Text(
                              widget.register
                                  ? 'Уже есть аккаунт? Войти'
                                  : 'Создать аккаунт',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
