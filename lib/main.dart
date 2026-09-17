import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'auth/auth_api.dart';
import 'core/api_client.dart';
import 'repositories/airline_repository.dart';
import 'state/auth_notifier.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  final prefs = await SharedPreferences.getInstance();
  late final AuthNotifier auth;
  late final AirlineRepository repository;
  final dio = buildDio(
    tokenProvider: () => auth.accessToken,
    refreshAccessToken: () => auth.refreshTokens(),
    onRefreshFailed: () =>
        auth.logout(reason: 'Сессия завершена: войдите снова.'),
  );
  auth = AuthNotifier(prefs, AuthApi(dio));
  repository = AirlineRepository(dio);
  await auth.restore();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider.value(value: repository),
      ],
      child: AirlineApp(auth: auth),
    ),
  );
}
