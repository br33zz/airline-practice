import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ForbiddenScreen extends StatelessWidget {
  const ForbiddenScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock_outline, size: 72, color: Colors.redAccent),
          const SizedBox(height: 16),
          Text(
            'Доступ запрещён',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          const Text('У вашей роли нет прав для просмотра этого раздела.'),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => context.go('/flights'),
            child: const Text('На главную'),
          ),
        ],
      ),
    ),
  );
}
