import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'screens/flights_screen.dart';
import 'screens/passengers_screen.dart';

final _router = GoRouter(
  initialLocation: '/flights',
  routes: [
    GoRoute(
      path: '/flights',
      builder: (_, state) => FlightsScreen(uri: state.uri),
    ),
    GoRoute(
      path: '/passengers',
      builder: (_, state) => PassengersScreen(uri: state.uri),
    ),
  ],
);

class AirlineApp extends StatelessWidget {
  const AirlineApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp.router(
    debugShowCheckedModeBanner: false,
    title: 'Авиакомпания',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff155eef)),
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xfff5f7fb),
    ),
    routerConfig: _router,
  );
}
