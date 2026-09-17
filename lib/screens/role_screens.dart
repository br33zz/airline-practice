import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_models.dart';
import '../core/api_exceptions.dart';
import '../repositories/airline_repository.dart';
import '../widgets/airline_scaffold.dart';

class MyBookingScreen extends StatefulWidget {
  const MyBookingScreen({super.key});
  @override
  State<MyBookingScreen> createState() => _MyBookingScreenState();
}

class _MyBookingScreenState extends State<MyBookingScreen> {
  Map<String, dynamic>? booking;
  Object? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final response = await context
          .read<AirlineRepository>()
          .dio
          .get<Map<String, dynamic>>('/my-booking');
      if (mounted) setState(() => booking = response.data ?? const {});
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  Future<void> _renew() async {
    try {
      final response = await context
          .read<AirlineRepository>()
          .dio
          .post<Map<String, dynamic>>('/my-booking/renew');
      if (mounted) {
        setState(() => booking = response.data ?? booking);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Срок действия билета продлён.')),
        );
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(mapDioError(e).message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) => AirlineScaffold(
    title: 'Мой билет',
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: error != null
            ? const Text('Не удалось загрузить билет.')
            : booking == null
            ? const CircularProgressIndicator()
            : Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Билет ${booking!['number']}',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 12),
                      Text('Рейс: ${booking!['flight']}'),
                      Text('Место: ${booking!['seat']}'),
                      Text('Действует до: ${booking!['validUntil']}'),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: _renew,
                        icon: const Icon(Icons.update),
                        label: const Text('Продлить срок'),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    ),
  );
}

class OperationsScreen extends StatelessWidget {
  const OperationsScreen({super.key});
  @override
  Widget build(BuildContext context) => AirlineScaffold(
    title: 'Оперативная работа',
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: const Padding(
          padding: EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Функции диспетчера',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),
                  ListTile(
                    leading: Icon(Icons.flight),
                    title: Text('Управление рейсами'),
                  ),
                  ListTile(
                    leading: Icon(Icons.airplanemode_active),
                    title: Text('Самолёты, пилоты и услуги'),
                  ),
                  ListTile(
                    leading: Icon(Icons.people),
                    title: Text('Оформление пассажиров'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});
  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  List<Map<String, dynamic>>? users;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final response = await context
          .read<AirlineRepository>()
          .dio
          .get<List<dynamic>>('/admin/users');
      if (mounted) {
        setState(
          () => users = (response.data ?? const [])
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList(),
        );
      }
    } on DioException catch (e) {
      if (mounted) setState(() => error = mapDioError(e).message);
    }
  }

  Future<void> _changeRole(int id, String role) async {
    try {
      await context.read<AirlineRepository>().dio.put(
        '/admin/users/$id/role',
        data: {'role': role},
      );
      await _load();
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(mapDioError(e).message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) => AirlineScaffold(
    title: 'Пользователи и роли',
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: error != null
              ? Text(error!)
              : users == null
              ? const Center(child: CircularProgressIndicator())
              : ListView.separated(
                  itemCount: users!.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (_, index) {
                    final user = users![index];
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: Text('${user['name']} (${user['username']})'),
                      trailing: DropdownButton<String>(
                        value: user['role']?.toString(),
                        items: UserRole.values
                            .map(
                              (role) => DropdownMenuItem(
                                value: role.name,
                                child: Text(role.title),
                              ),
                            )
                            .toList(),
                        onChanged: (role) {
                          if (role != null) {
                            _changeRole((user['id'] as num).toInt(), role);
                          }
                        },
                      ),
                    );
                  },
                ),
        ),
      ),
    ),
  );
}

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});
  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  Map<String, dynamic>? stats;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final response = await context
        .read<AirlineRepository>()
        .dio
        .get<Map<String, dynamic>>('/admin/statistics');
    if (mounted) setState(() => stats = response.data ?? const {});
  }

  @override
  Widget build(BuildContext context) => AirlineScaffold(
    title: 'Статистика',
    body: Center(
      child: stats == null
          ? const CircularProgressIndicator()
          : Wrap(
              spacing: 16,
              runSpacing: 16,
              children: stats!.entries
                  .map(
                    (e) => SizedBox(
                      width: 210,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${e.value}',
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineMedium,
                              ),
                              Text(e.key),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
    ),
  );
}
