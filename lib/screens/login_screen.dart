import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/api_exceptions.dart';
import '../state/auth_notifier.dart';

class LoginScreen extends StatefulWidget {
  final String? from;
  const LoginScreen({super.key, this.from});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final key = GlobalKey<FormState>();
  final username = TextEditingController();
  final password = TextEditingController();
  bool loading = false;
  String? error;

  Future<void> _submit() async {
    if (!(key.currentState?.validate() ?? false)) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await context.read<AuthNotifier>().login(username.text, password.text);
      if (mounted) {
        context.go(
          widget.from?.startsWith('/') == true ? widget.from! : '/flights',
        );
      }
    } on ApiException catch (exception) {
      if (mounted) setState(() => error = exception.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notice = context.read<AuthNotifier>().takeNotice();
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Form(
                  key: key,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.flight_takeoff, size: 52),
                      const SizedBox(height: 12),
                      Text(
                        'Вход в систему',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 20),
                      if (notice != null) _message(notice, Colors.orange),
                      if (error != null) _message(error!, Colors.red),
                      TextFormField(
                        controller: username,
                        decoration: const InputDecoration(labelText: 'Логин'),
                        validator: (value) => (value ?? '').trim().isEmpty
                            ? 'Введите логин'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: password,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'Пароль'),
                        validator: (value) =>
                            (value ?? '').isEmpty ? 'Введите пароль' : null,
                        onFieldSubmitted: (_) => _submit(),
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: loading ? null : _submit,
                        child: Text(loading ? 'Вход...' : 'Войти'),
                      ),
                      TextButton(
                        onPressed: () => context.go('/register'),
                        child: const Text('Создать учётную запись'),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'reader / reader123!   operator / operator123!   admin / admin123!',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _message(String text, Color color) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Text(
      text,
      style: TextStyle(color: color),
      textAlign: TextAlign.center,
    ),
  );

  @override
  void dispose() {
    username.dispose();
    password.dispose();
    super.dispose();
  }
}
