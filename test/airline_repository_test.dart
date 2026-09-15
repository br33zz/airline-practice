import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:airline_practice/core/api_client.dart';
import 'package:airline_practice/core/api_exceptions.dart';
import 'package:airline_practice/models/airline_models.dart';
import 'package:airline_practice/models/list_query.dart';
import 'package:airline_practice/repositories/airline_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

typedef Reply = FutureOr<ResponseBody> Function(RequestOptions options);

class FakeAdapter implements HttpClientAdapter {
  Reply reply;
  FakeAdapter(this.reply);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => reply(options);

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonResponse(int status, Object data) => ResponseBody.fromString(
  jsonEncode(data),
  status,
  headers: {
    Headers.contentTypeHeader: ['application/json'],
  },
);

Map<String, Object?> fixture(String resource) => switch (resource) {
  'aircraft' => {
    'id': 1,
    'registrationNumber': 'RA-73101',
    'model': 'Airbus A320',
    'type': 'A320',
    'capacity': 180,
    'deletedAt': null,
  },
  'pilots' => {
    'id': 1,
    'fullName': 'Иванов Алексей',
    'licenseNumber': 'PL-4100',
    'qualification': 'A320',
    'experienceYears': 10,
    'deletedAt': null,
  },
  'services' => {
    'id': 1,
    'name': 'Питание',
    'description': 'Питание на борту',
    'price': 1200,
    'deletedAt': null,
  },
  'flights' => {
    'id': 1,
    'number': 'SU 310',
    'destination': 'Сочи',
    'departure': '2026-09-10T12:00:00Z',
    'status': 'По расписанию',
    'seats': 100,
    'aircraftId': 1,
    'pilotIds': [1],
    'serviceIds': [1],
    'deletedAt': null,
  },
  _ => {
    'id': 1,
    'fullName': 'Анна Петрова',
    'passport': '4500 123456',
    'country': 'Россия',
    'email': 'anna@example.ru',
    'ticket': {
      'number': 'TKT-1',
      'flightId': 1,
      'seat': '1A',
      'fareClass': 'Эконом',
      'issuedAt': '2026-09-01T00:00:00Z',
    },
    'deletedAt': null,
  },
};

ResponseBody normalReply(RequestOptions options) {
  if (options.path.endsWith('/auth/login')) {
    return jsonResponse(200, {'accessToken': 'test-token'});
  }
  final resource = options.path
      .split('/')
      .where((part) => part.isNotEmpty)
      .first;
  if (options.method == 'GET') {
    return jsonResponse(200, {
      'items': [fixture(resource)],
      'page': options.queryParameters['page'] ?? 1,
      'size': options.queryParameters['size'] ?? 10,
      'total': 1,
      'totalPages': 1,
    });
  }
  return jsonResponse(201, {...fixture(resource), 'id': 20});
}

AirlineRepository makeRepository(FakeAdapter adapter) {
  late AirlineRepository repository;
  final dio = buildDio(tokenProvider: () => repository.accessToken)
    ..httpClientAdapter = adapter;
  repository = AirlineRepository(dio);
  return repository;
}

void main() {
  test('модели устойчиво разбирают JSON', () {
    final flight = Flight.fromJson(fixture('flights'));
    final passenger = Passenger.fromJson(fixture('passengers'));
    expect(flight.number, 'SU 310');
    expect(flight.pilotIds, [1]);
    expect(passenger.ticket.flightId, 1);
  });

  test('поиск и пагинация отправляются на сервер', () async {
    RequestOptions? listRequest;
    final adapter = FakeAdapter((options) {
      if (options.path.endsWith('/flights') &&
          options.queryParameters['size'] == 5) {
        listRequest = options;
      }
      return normalReply(options);
    });
    final repository = makeRepository(adapter);
    final result = await repository.find(
      EntityKind.flights,
      const ListQuery(search: 'Сочи', page: 2, size: 5),
    );
    expect(result.items.single, isA<Flight>());
    expect(listRequest?.queryParameters['search'], 'Сочи');
    expect(listRequest?.queryParameters['page'], 2);
  });

  test('создание выполняется POST-запросом с токеном', () async {
    RequestOptions? createRequest;
    final adapter = FakeAdapter((options) {
      if (options.method == 'POST' && options.path.endsWith('/services')) {
        createRequest = options;
      }
      return normalReply(options);
    });
    final repository = makeRepository(adapter);
    final saved = await repository.save(
      EntityKind.services,
      const AirlineService(
        id: 0,
        name: 'Wi-Fi',
        description: 'Интернет на борту',
        price: 500,
      ),
    );
    expect(saved.id, 20);
    expect(createRequest?.headers['Authorization'], 'Bearer test-token');
    expect(createRequest?.data['name'], 'Wi-Fi');
  });

  test('ответ 422 превращается в ошибки полей', () async {
    final adapter = FakeAdapter((options) {
      if (options.method == 'POST' && options.path.endsWith('/flights')) {
        return jsonResponse(422, {
          'message': 'Ошибка валидации',
          'errors': {'number': 'Рейс с таким номером уже существует'},
        });
      }
      return normalReply(options);
    });
    final repository = makeRepository(adapter);
    final flight = Flight.fromJson({...fixture('flights'), 'id': 0});
    expect(
      () => repository.save(EntityKind.flights, flight),
      throwsA(
        isA<ValidationException>().having(
          (error) => error.errors['number'],
          'number',
          contains('существует'),
        ),
      ),
    );
  });

  test('конфликт 409 превращается в понятное исключение', () async {
    final adapter = FakeAdapter((options) {
      if (options.method == 'DELETE') {
        return jsonResponse(409, {'message': 'Самолёт используется рейсами'});
      }
      return normalReply(options);
    });
    final repository = makeRepository(adapter);
    expect(
      () => repository.delete(EntityKind.aircraft, 1),
      throwsA(
        isA<ConflictException>().having(
          (error) => error.message,
          'message',
          contains('используется'),
        ),
      ),
    );
  });

  test('чтение повторяется не более трёх раз при сбое сети', () async {
    final adapter = FakeAdapter(normalReply);
    final repository = makeRepository(adapter);
    await repository.initialize();
    var attempts = 0;
    adapter.reply = (options) {
      attempts++;
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );
    };
    await expectLater(
      repository.find(EntityKind.passengers, const ListQuery()),
      throwsA(isA<NetworkException>()),
    );
    expect(attempts, 3);
  });
}
