import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'repositories/airline_repository.dart';
import 'state/airline_notifier.dart';

void main() {
  usePathUrlStrategy();
  final repository = InMemoryAirlineRepository();
  runApp(
    MultiProvider(
      providers: [
        Provider<AirlineRepository>.value(value: repository),
        ChangeNotifierProvider(create: (_) => FlightListNotifier(repository)),
        ChangeNotifierProvider(
          create: (_) => PassengerListNotifier(repository),
        ),
      ],
      child: const AirlineApp(),
    ),
  );
}
