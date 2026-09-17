import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'auth/auth_models.dart';
import 'models/airline_models.dart';
import 'screens/entity_detail_screen.dart' deferred as detail_screen;
import 'screens/entity_form_screen.dart' deferred as form_screen;
import 'screens/entity_list_screen.dart';
import 'screens/forbidden_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/role_screens.dart' deferred as roles;
import 'screens/admin_screens.dart' deferred as admin;
import 'state/auth_notifier.dart';
import 'widgets/session_watcher.dart';

EntityKind _kind(GoRouterState state) =>
    EntityKindUi.tryParse(state.pathParameters['entity']) ?? EntityKind.flights;

class DeferredScreen extends StatefulWidget {
  final Future<void> Function() loadLibrary;
  final Widget Function() builder;

  const DeferredScreen({
    super.key,
    required this.loadLibrary,
    required this.builder,
  });

  @override
  State<DeferredScreen> createState() => _DeferredScreenState();
}

class _DeferredScreenState extends State<DeferredScreen> {
  late final Future<void> loading = widget.loadLibrary();

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: loading,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Scaffold(
          body: Center(child: Text('Не удалось загрузить раздел.')),
        );
      }
      if (snapshot.connectionState != ConnectionState.done) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      return widget.builder();
    },
  );
}

GoRouter buildRouter(AuthNotifier auth) => GoRouter(
  initialLocation: '/flights',
  refreshListenable: auth,
  redirect: (_, state) {
    final path = state.matchedLocation;
    final isPublic = path == '/login' || path == '/register';
    if (!auth.isAuthenticated && !isPublic) {
      return '/login?from=${Uri.encodeComponent(state.uri.toString())}';
    }
    if (auth.isAuthenticated && isPublic) return '/flights';
    if (!auth.isAuthenticated) return null;
    if (path == '/my-booking' && !auth.has(AppPermission.viewOwnBooking)) {
      return '/forbidden';
    }
    if (path == '/operations' && !auth.has(AppPermission.manageOperations)) {
      return '/forbidden';
    }
    if (path.startsWith('/admin/') && !auth.has(AppPermission.manageUsers)) {
      return '/forbidden';
    }
    final kind = EntityKindUi.tryParse(state.pathParameters['entity']);
    if (kind != null) {
      final restricted =
          kind == EntityKind.aircraft ||
          kind == EntityKind.pilots ||
          kind == EntityKind.passengers;
      if (restricted &&
          !auth.has(AppPermission.manageOperations) &&
          !auth.has(AppPermission.restoreRecords)) {
        return '/forbidden';
      }
      final writeRoute = path.endsWith('/new') || path.endsWith('/edit');
      if (writeRoute &&
          !auth.has(AppPermission.manageOperations) &&
          !auth.has(AppPermission.manageDirectories) &&
          !auth.has(AppPermission.managePassengers)) {
        return '/forbidden';
      }
    }
    return null;
  },
  routes: [
    GoRoute(
      path: '/login',
      builder: (_, state) =>
          LoginScreen(from: state.uri.queryParameters['from']),
    ),
    GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
    GoRoute(path: '/forbidden', builder: (_, __) => const ForbiddenScreen()),
    GoRoute(
      path: '/my-booking',
      builder: (_, __) => DeferredScreen(
        loadLibrary: roles.loadLibrary,
        builder: () => roles.MyBookingScreen(),
      ),
    ),
    GoRoute(
      path: '/operations',
      builder: (_, __) => DeferredScreen(
        loadLibrary: roles.loadLibrary,
        builder: () => roles.OperationsScreen(),
      ),
    ),
    GoRoute(
      path: '/admin/users',
      builder: (_, __) => DeferredScreen(
        loadLibrary: admin.loadLibrary,
        builder: () => admin.AdminUsersScreen(),
      ),
    ),
    GoRoute(
      path: '/admin/statistics',
      builder: (_, __) => DeferredScreen(
        loadLibrary: admin.loadLibrary,
        builder: () => admin.StatisticsScreen(),
      ),
    ),
    GoRoute(path: '/', redirect: (_, __) => '/flights'),
    GoRoute(
      path: '/:entity/new',
      builder: (_, state) => DeferredScreen(
        loadLibrary: form_screen.loadLibrary,
        builder: () => form_screen.EntityFormScreen(kind: _kind(state)),
      ),
    ),
    GoRoute(
      path: '/:entity/:id/edit',
      builder: (_, state) => DeferredScreen(
        loadLibrary: form_screen.loadLibrary,
        builder: () => form_screen.EntityFormScreen(
          kind: _kind(state),
          id: int.tryParse(state.pathParameters['id'] ?? ''),
        ),
      ),
    ),
    GoRoute(
      path: '/:entity/:id',
      builder: (_, state) => DeferredScreen(
        loadLibrary: detail_screen.loadLibrary,
        builder: () => detail_screen.EntityDetailScreen(
          kind: _kind(state),
          id: int.tryParse(state.pathParameters['id'] ?? '') ?? -1,
        ),
      ),
    ),
    GoRoute(
      path: '/:entity',
      builder: (_, state) =>
          EntityListScreen(kind: _kind(state), uri: state.uri),
    ),
  ],
  errorBuilder: (_, state) => Scaffold(
    body: Center(child: Text('Страница не найдена: ${state.uri.path}')),
  ),
);

class AirlineApp extends StatefulWidget {
  final AuthNotifier auth;
  const AirlineApp({super.key, required this.auth});
  @override
  State<AirlineApp> createState() => _AirlineAppState();
}

class _AirlineAppState extends State<AirlineApp> {
  late final GoRouter router = buildRouter(widget.auth);
  @override
  Widget build(BuildContext context) => MaterialApp.router(
    debugShowCheckedModeBanner: false,
    title: 'Авиакомпания',
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff155eef)),
      scaffoldBackgroundColor: const Color(0xfff5f7fb),
      cardTheme: const CardThemeData(elevation: 0),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white,
      ),
      dialogTheme: const DialogThemeData(
        constraints: BoxConstraints(maxWidth: 480),
      ),
      focusColor: const Color(0x33155eef),
    ),
    builder: (context, child) => widget.auth.isAuthenticated
        ? SessionWatcher(child: child ?? const SizedBox.shrink())
        : child ?? const SizedBox.shrink(),
    routerConfig: router,
  );
  @override
  void dispose() {
    router.dispose();
    super.dispose();
  }
}
