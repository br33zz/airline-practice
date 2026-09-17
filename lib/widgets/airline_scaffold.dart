import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../auth/auth_models.dart';
import '../models/airline_models.dart';
import '../state/auth_notifier.dart';

enum AppDestinationId {
  flights,
  aircraft,
  pilots,
  services,
  passengers,
  myBooking,
  operations,
  users,
  statistics,
}

AppDestinationId destinationForEntity(EntityKind kind) => switch (kind) {
  EntityKind.flights => AppDestinationId.flights,
  EntityKind.aircraft => AppDestinationId.aircraft,
  EntityKind.pilots => AppDestinationId.pilots,
  EntityKind.services => AppDestinationId.services,
  EntityKind.passengers => AppDestinationId.passengers,
};

class _AppDestination {
  final AppDestinationId id;
  final String label;
  final String path;
  final IconData icon;

  const _AppDestination(this.id, this.label, this.path, this.icon);
}

const _entityDestinations = <_AppDestination>[
  _AppDestination(AppDestinationId.flights, 'Рейсы', '/flights', Icons.flight),
  _AppDestination(
    AppDestinationId.aircraft,
    'Самолёты',
    '/aircraft',
    Icons.airplanemode_active,
  ),
  _AppDestination(AppDestinationId.pilots, 'Пилоты', '/pilots', Icons.badge),
  _AppDestination(
    AppDestinationId.services,
    'Услуги',
    '/services',
    Icons.room_service,
  ),
  _AppDestination(
    AppDestinationId.passengers,
    'Пассажиры',
    '/passengers',
    Icons.people,
  ),
];

class AirlineScaffold extends StatelessWidget {
  final String title;
  final AppDestinationId selected;
  final Widget body;
  final List<Widget> actions;

  const AirlineScaffold({
    super.key,
    required this.title,
    required this.selected,
    required this.body,
    this.actions = const [],
  });

  List<_AppDestination> _destinations(AuthNotifier auth) {
    final values = <_AppDestination>[
      ..._entityDestinations.where((destination) {
        if (destination.id == AppDestinationId.flights ||
            destination.id == AppDestinationId.services) {
          return true;
        }
        return auth.has(AppPermission.manageOperations) ||
            auth.has(AppPermission.restoreRecords);
      }),
    ];
    if (auth.has(AppPermission.viewOwnBooking)) {
      values.add(
        const _AppDestination(
          AppDestinationId.myBooking,
          'Мой билет',
          '/my-booking',
          Icons.confirmation_number_outlined,
        ),
      );
    }
    if (auth.has(AppPermission.manageOperations)) {
      values.add(
        const _AppDestination(
          AppDestinationId.operations,
          'Операции',
          '/operations',
          Icons.dashboard_customize_outlined,
        ),
      );
    }
    if (auth.has(AppPermission.manageUsers)) {
      values.add(
        const _AppDestination(
          AppDestinationId.users,
          'Пользователи',
          '/admin/users',
          Icons.manage_accounts_outlined,
        ),
      );
    }
    if (auth.has(AppPermission.viewStatistics)) {
      values.add(
        const _AppDestination(
          AppDestinationId.statistics,
          'Статистика',
          '/admin/statistics',
          Icons.bar_chart,
        ),
      );
    }
    return values;
  }

  PreferredSizeWidget _appBar(
    BuildContext context,
    AuthNotifier auth,
    double width,
  ) => AppBar(
    title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
    actions: [
      ...actions,
      if (width >= 720)
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              child: Text(
                '${auth.user!.name} · ${auth.user!.role.title}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      IconButton(
        tooltip: 'Выйти из учётной записи',
        onPressed: auth.logout,
        icon: const Icon(Icons.logout),
      ),
    ],
  );

  void _open(BuildContext context, _AppDestination destination) {
    if (destination.id != selected) context.go(destination.path);
  }

  Widget _mobileNavigation(
    BuildContext context,
    List<_AppDestination> destinations,
  ) {
    final direct = destinations.length <= 5
        ? destinations
        : [...destinations.take(4)];
    final extra = destinations.skip(direct.length).toList();
    final selectedDirect = direct.indexWhere((item) => item.id == selected);
    final selectedIndex = selectedDirect >= 0
        ? selectedDirect
        : extra.isEmpty
        ? 0
        : direct.length;
    return NavigationBar(
      selectedIndex: selectedIndex,
      labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
      onDestinationSelected: (index) async {
        if (index < direct.length) {
          _open(context, direct[index]);
          return;
        }
        final chosen = await showModalBottomSheet<_AppDestination>(
          context: context,
          showDragHandle: true,
          constraints: const BoxConstraints(maxWidth: 520),
          builder: (sheetContext) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 12),
              children: [
                const ListTile(
                  title: Text(
                    'Другие разделы',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                ...extra.map(
                  (item) => ListTile(
                    selected: item.id == selected,
                    leading: Icon(item.icon),
                    title: Text(item.label),
                    onTap: () => Navigator.pop(sheetContext, item),
                  ),
                ),
              ],
            ),
          ),
        );
        if (chosen != null && context.mounted) _open(context, chosen);
      },
      destinations: [
        ...direct.map(
          (item) => NavigationDestination(
            icon: Icon(item.icon),
            label: item.label,
            tooltip: item.label,
          ),
        ),
        if (extra.isNotEmpty)
          const NavigationDestination(
            icon: Icon(Icons.more_horiz),
            label: 'Ещё',
            tooltip: 'Другие разделы',
          ),
      ],
    );
  }

  Widget _wideBody(
    BuildContext context,
    List<_AppDestination> destinations,
    double width,
  ) {
    final selectedIndex = destinations.indexWhere(
      (item) => item.id == selected,
    );
    return Row(
      children: [
        NavigationRail(
          extended: width >= 1000,
          selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
          labelType: width >= 1000 ? NavigationRailLabelType.none : null,
          onDestinationSelected: (index) => _open(context, destinations[index]),
          leading: const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Tooltip(
              message: 'Система управления авиакомпанией',
              child: Icon(Icons.flight_takeoff, size: 30),
            ),
          ),
          destinations: destinations
              .map(
                (item) => NavigationRailDestination(
                  icon: Tooltip(message: item.label, child: Icon(item.icon)),
                  label: Text(item.label),
                ),
              )
              .toList(),
        ),
        const VerticalDivider(width: 1),
        Expanded(child: body),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final width = MediaQuery.sizeOf(context).width;
    final destinations = _destinations(auth);
    final mobile = width < 600;
    return Scaffold(
      appBar: _appBar(context, auth, width),
      body: mobile ? body : _wideBody(context, destinations, width),
      bottomNavigationBar: mobile
          ? _mobileNavigation(context, destinations)
          : null,
    );
  }
}
