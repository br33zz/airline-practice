import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/api_exceptions.dart';
import '../state/auth_notifier.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final key = GlobalKey<FormState>();
  final name = TextEditingController();
  final username = TextEditingController();
  final password = TextEditingController();
  bool loading = false;
  String? error;

  bool get lengthOk => password.text.length >= 8;
  bool get digitOk => RegExp(r'\d').hasMatch(password.text);
  bool get specialOk => RegExp(r'[^A-Za-zА-Яа-я0-9]').hasMatch(password.text);

  Future<void> _submit() async {
    if (!(key.currentState?.validate() ?? false)) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await context.read<AuthNotifier>().register(
        name.text,
        username.text,
        password.text,
      );
      if (mounted) context.go('/my-booking');
    } on ApiException catch (exception) {
      if (mounted) setState(() => error = exception.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Form(
                key: key,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Регистрация пассажира',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 20),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          error!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    TextFormField(
                      controller: name,
                      decoration: const InputDecoration(labelText: 'Имя'),
                      validator: (v) =>
                          (v ?? '').trim().isEmpty ? 'Введите имя' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: username,
                      decoration: const InputDecoration(labelText: 'Логин'),
                      validator: (v) =>
                          (v ?? '').trim().isEmpty ? 'Введите логин' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: password,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Пароль'),
                      onChanged: (_) => setState(() {}),
                      validator: (_) => lengthOk && digitOk && specialOk
                          ? null
                          : 'Пароль не соответствует требованиям',
                    ),
                    const SizedBox(height: 10),
                    _rule('Не менее 8 символов', lengthOk),
                    _rule('Есть цифра', digitOk),
                    _rule('Есть специальный символ', specialOk),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: loading ? null : _submit,
                      child: Text(
                        loading ? 'Регистрация...' : 'Зарегистрироваться',
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: const Text('Вернуться ко входу'),
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

  Widget _rule(String text, bool ok) => Row(
    children: [
      Icon(
        ok ? Icons.check_circle : Icons.radio_button_unchecked,
        size: 18,
        color: ok ? Colors.green : Colors.grey,
      ),
      const SizedBox(width: 8),
      Text(text),
    ],
  );
  @override
  void dispose() {
    name.dispose();
    username.dispose();
    password.dispose();
    super.dispose();
  }
}
