import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_models.dart';
import '../core/api_exceptions.dart';
import '../repositories/airline_repository.dart';
import '../widgets/airline_scaffold.dart';

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
              .map((value) => Map<String, dynamic>.from(value))
              .toList(),
        );
      }
    } on DioException catch (exception) {
      if (mounted) setState(() => error = mapDioError(exception).message);
    }
  }

  Future<void> _changeRole(int id, String role) async {
    try {
      await context.read<AirlineRepository>().dio.put(
        '/admin/users/$id/role',
        data: {'role': role},
      );
      await _load();
    } on DioException catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(mapDioError(exception).message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) => AirlineScaffold(
    title: 'Пользователи и роли',
    selected: AppDestinationId.users,
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
                      title: Text(
                        '${user['name']} (${user['username']})',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
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
    selected: AppDestinationId.statistics,
    body: Center(
      child: stats == null
          ? const CircularProgressIndicator()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Wrap(
                spacing: 16,
                runSpacing: 16,
                children: stats!.entries
                    .map(
                      (entry) => SizedBox(
                        width: 210,
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${entry.value}',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineMedium,
                                ),
                                Text(
                                  entry.key,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
    ),
  );
}
