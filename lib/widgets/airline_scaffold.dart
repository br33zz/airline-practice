import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../auth/auth_models.dart';
import '../models/airline_models.dart';
import '../state/auth_notifier.dart';

class AirlineScaffold extends StatelessWidget {
  final String title;
  final EntityKind? selected;
  final Widget body;
  final List<Widget> actions;
  const AirlineScaffold({
    super.key,
    required this.title,
    this.selected,
    required this.body,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final user = auth.user!;
    final visibleKinds = EntityKind.values.where((kind) {
      if (kind == EntityKind.flights || kind == EntityKind.services) {
        return true;
      }
      return auth.has(AppPermission.manageOperations) ||
          auth.has(AppPermission.restoreRecords);
    });
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          ...actions,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(child: Text('${user.name} · ${user.role.title}')),
          ),
          IconButton(
            tooltip: 'Выйти',
            onPressed: () => auth.logout(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              const ListTile(
                leading: Icon(Icons.flight_takeoff),
                title: Text(
                  'Авиакомпания',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('Система управления'),
              ),
              const Divider(),
              ...visibleKinds.map(
                (kind) => ListTile(
                  selected: kind == selected,
                  leading: Icon(switch (kind) {
                    EntityKind.flights => Icons.flight,
                    EntityKind.aircraft => Icons.airplanemode_active,
                    EntityKind.pilots => Icons.badge,
                    EntityKind.services => Icons.room_service,
                    EntityKind.passengers => Icons.people,
                  }),
                  title: Text(kind.title),
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/${kind.name}');
                  },
                ),
              ),
              if (auth.has(AppPermission.viewOwnBooking))
                ListTile(
                  leading: const Icon(Icons.confirmation_number_outlined),
                  title: const Text('Мой билет'),
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/my-booking');
                  },
                ),
              if (auth.has(AppPermission.manageOperations))
                ListTile(
                  leading: const Icon(Icons.dashboard_customize_outlined),
                  title: const Text('Оперативная работа'),
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/operations');
                  },
                ),
              if (auth.has(AppPermission.manageUsers))
                ListTile(
                  leading: const Icon(Icons.manage_accounts_outlined),
                  title: const Text('Пользователи и роли'),
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/admin/users');
                  },
                ),
              if (auth.has(AppPermission.viewStatistics))
                ListTile(
                  leading: const Icon(Icons.bar_chart),
                  title: const Text('Статистика'),
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/admin/statistics');
                  },
                ),
            ],
          ),
        ),
      ),
      body: body,
    );
  }
}
