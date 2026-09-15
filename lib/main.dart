import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/api_client.dart';
import 'repositories/airline_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  late final AirlineRepository repository;
  final dio = buildDio(tokenProvider: () => repository.accessToken);
  repository = AirlineRepository(dio);
  repository.initialize();
  runApp(
    ChangeNotifierProvider(
      create: (_) => repository,
      child: const AirlineApp(),
    ),
  );
}
