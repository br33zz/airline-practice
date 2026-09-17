import 'dart:async';

import 'package:airline_practice/auth/auth_api.dart';
import 'package:airline_practice/auth/auth_models.dart';
import 'package:airline_practice/core/api_exceptions.dart';
import 'package:airline_practice/models/airline_models.dart';
import 'package:airline_practice/models/list_query.dart';
import 'package:airline_practice/models/page_result.dart';
import 'package:airline_practice/repositories/airline_repository.dart';
import 'package:airline_practice/screens/entity_form_screen.dart';
import 'package:airline_practice/screens/entity_list_screen.dart';
import 'package:airline_practice/state/auth_notifier.dart';
import 'package:airline_practice/widgets/airline_scaffold.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum _RepositoryMode { loading, empty, errorThenEmpty }

class _FakeRepository extends AirlineRepository {
  final _RepositoryMode mode;
  final loadingCompleter = Completer<PageResult<AirlineModel>>();
  int calls = 0;

  _FakeRepository(this.mode) : super(Dio());

  @override
  Future<PageResult<AirlineModel>> find(
    EntityKind kind,
    ListQuery query,
  ) async {
    calls++;
    if (mode == _RepositoryMode.loading) {
      return loadingCompleter.future;
    }
    if (mode == _RepositoryMode.errorThenEmpty && calls == 1) {
      throw const NetworkException();
    }
    return PageResult(items: const [], page: 1, size: 5, total: 0);
  }
}

Future<AuthNotifier> _auth(UserRole role) async {
  final user = AppUser(
    id: 1,
    username: role.name,
    name: 'Тестовый пользователь',
    role: role,
  );
  SharedPreferences.setMockInitialValues({
    AuthNotifier.accessKey: 'access-token',
  });
  final prefs = await SharedPreferences.getInstance();
  final auth = AuthNotifier(prefs, AuthApi(Dio()));
  auth.setTestSession(user);
  return auth;
}

Widget _app({
  required AuthNotifier auth,
  required AirlineRepository repository,
  required Widget child,
}) => MultiProvider(
  providers: [
    ChangeNotifierProvider.value(value: auth),
    ChangeNotifierProvider.value(value: repository),
  ],
  child: MaterialApp(theme: ThemeData(useMaterial3: true), home: child),
);

void main() {
  testWidgets('список отображает состояние загрузки', (tester) async {
    final auth = await _auth(UserRole.reader);
    final repository = _FakeRepository(_RepositoryMode.loading);
    await tester.pumpWidget(
      _app(
        auth: auth,
        repository: repository,
        child: EntityListScreen(
          kind: EntityKind.services,
          uri: Uri(path: '/services'),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    repository.loadingCompleter.complete(
      PageResult(items: const [], page: 1, size: 5, total: 0),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('список показывает пустой результат', (tester) async {
    final auth = await _auth(UserRole.reader);
    final repository = _FakeRepository(_RepositoryMode.empty);
    await tester.pumpWidget(
      _app(
        auth: auth,
        repository: repository,
        child: EntityListScreen(
          kind: EntityKind.services,
          uri: Uri(path: '/services'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ничего не найдено'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('после ошибки повторный запрос восстанавливает список', (
    tester,
  ) async {
    final auth = await _auth(UserRole.reader);
    final repository = _FakeRepository(_RepositoryMode.errorThenEmpty);
    await tester.pumpWidget(
      _app(
        auth: auth,
        repository: repository,
        child: EntityListScreen(
          kind: EntityKind.services,
          uri: Uri(path: '/services'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Повторить загрузку'), findsOneWidget);

    await tester.tap(find.text('Повторить загрузку'));
    await tester.pumpAndSettle();

    expect(repository.calls, 2);
    expect(find.text('Ничего не найдено'), findsOneWidget);
  });

  testWidgets('форма не отправляет пустые обязательные поля', (tester) async {
    final auth = await _auth(UserRole.operator);
    final repository = _FakeRepository(_RepositoryMode.empty);
    await tester.pumpWidget(
      _app(
        auth: auth,
        repository: repository,
        child: const EntityFormScreen(kind: EntityKind.services),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Создать'));
    await tester.pump();

    expect(find.text('Обязательное поле'), findsNWidgets(2));
    expect(repository.calls, 0);
  });

  testWidgets('пассажиру скрыты административные разделы', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final auth = await _auth(UserRole.reader);
    final repository = _FakeRepository(_RepositoryMode.empty);
    await tester.pumpWidget(
      _app(
        auth: auth,
        repository: repository,
        child: const AirlineScaffold(
          title: 'Проверка прав',
          selected: AppDestinationId.flights,
          body: SizedBox.shrink(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Рейсы'), findsOneWidget);
    expect(find.text('Пользователи'), findsNothing);
    expect(find.text('Статистика'), findsNothing);
    expect(find.text('Самолёты'), findsNothing);
  });
}
