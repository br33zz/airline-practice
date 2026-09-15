import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/api_exceptions.dart';
import '../core/config.dart';
import '../models/airline_models.dart';
import '../models/list_query.dart';
import '../models/page_result.dart';

class DuplicateValueException extends ValidationException {
  final String field;
  DuplicateValueException(this.field, String message)
    : super(message, {field: message});
}

class LinkedRecordsException extends ConflictException {
  final int count;
  LinkedRecordsException(this.count)
    : super('Запись используется связанными объектами: $count');
}

class AirlineRepository extends ChangeNotifier {
  final Dio dio;
  String? _accessToken;
  Future<void>? _loginFuture;
  Future<void>? _referenceFuture;
  bool _referencesLoaded = false;
  CancelToken? _activeSearch;

  List<Flight> flights = [];
  List<Aircraft> aircraft = [];
  List<Pilot> pilots = [];
  List<AirlineService> services = [];
  List<Passenger> passengers = [];

  AirlineRepository(this.dio);

  String? get accessToken => _accessToken;

  Future<void> initialize() async {
    try {
      await _ensureReferences();
    } on ApiException {
      // Экран списка покажет ошибку и позволит повторить запрос.
    }
  }

  Future<void> _ensureLogin() => _loginFuture ??= guard(() async {
    final response = await dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: const {'username': 'admin', 'password': 'admin123'},
    );
    _accessToken = response.data?['accessToken']?.toString();
    if (_accessToken == null) {
      throw const ServerException('Сервер не вернул токен доступа.');
    }
  }).whenComplete(() => _loginFuture = null);

  Future<void> _ensureReferences() {
    if (_referencesLoaded) return Future.value();
    return _referenceFuture ??= (() async {
      final values = await Future.wait([
        _readAll(EntityKind.aircraft),
        _readAll(EntityKind.pilots),
        _readAll(EntityKind.services),
        _readAll(EntityKind.flights),
      ]);
      aircraft = values[0].cast<Aircraft>();
      pilots = values[1].cast<Pilot>();
      services = values[2].cast<AirlineService>();
      flights = values[3].cast<Flight>();
      _referencesLoaded = true;
      notifyListeners();
    })().whenComplete(() => _referenceFuture = null);
  }

  Future<List<AirlineModel>> _readAll(EntityKind kind) async {
    final response = await _readWithRetry<Map<String, dynamic>>(
      '/${kind.name}',
      queryParameters: {'page': 1, 'size': 100, 'includeDeleted': true},
    );
    final data = response.data ?? const {};
    return (data['items'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => _fromJson(kind, Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<Response<T>> _readWithRetry<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) async {
    final parameters = <String, dynamic>{
      ...?queryParameters,
      if (apiDemoDelay > 0) '__delay': apiDemoDelay,
      if (apiDemoFail > 0) '__fail': apiDemoFail,
    };
    for (var attempt = 1; ; attempt++) {
      try {
        return await guard(
          () => dio.get<T>(
            path,
            queryParameters: parameters,
            cancelToken: cancelToken,
          ),
        );
      } on NetworkException {
        if (cancelToken?.isCancelled == true || attempt >= 3) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 250 * attempt));
      }
    }
  }

  Future<PageResult<AirlineModel>> find(
    EntityKind kind,
    ListQuery query,
  ) async {
    if (aircraft.isEmpty ||
        pilots.isEmpty ||
        services.isEmpty ||
        flights.isEmpty) {
      await _ensureReferences();
    }
    _activeSearch?.cancel('Выполнен новый запрос');
    final cancelToken = CancelToken();
    _activeSearch = cancelToken;
    final response = await _readWithRetry<Map<String, dynamic>>(
      '/${kind.name}',
      cancelToken: cancelToken,
      queryParameters: {
        if (query.search.trim().isNotEmpty) 'search': query.search.trim(),
        if (query.filter.isNotEmpty) 'filter': query.filter,
        'sort': '${query.sortField},${query.sortAscending ? 'asc' : 'desc'}',
        'page': query.page,
        'size': query.size,
        if (query.includeDeleted) 'includeDeleted': true,
      },
    );
    if (identical(_activeSearch, cancelToken)) _activeSearch = null;
    final data = response.data ?? const {};
    final items = (data['items'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => _fromJson(kind, Map<String, dynamic>.from(item)))
        .toList();
    for (final item in items) {
      _upsertCache(kind, item);
    }
    return PageResult(
      items: items,
      page: _int(data['page'], query.page),
      size: _int(data['size'], query.size),
      total: _int(data['total']),
    );
  }

  Future<AirlineModel> findById(EntityKind kind, int id) async {
    final response = await _readWithRetry<Map<String, dynamic>>(
      '/${kind.name}/$id',
      queryParameters: const {'includeDeleted': true},
    );
    final item = _fromJson(kind, response.data ?? const {});
    _upsertCache(kind, item);
    notifyListeners();
    return item;
  }

  Future<AirlineModel> save(EntityKind kind, AirlineModel item) async {
    await _ensureLogin();
    final creating = item.id <= 0 || byId(kind, item.id) == null;
    final response = await guard(
      () => creating
          ? dio.post<Map<String, dynamic>>(
              '/${kind.name}',
              data: _writeJson(item),
            )
          : dio.put<Map<String, dynamic>>(
              '/${kind.name}/${item.id}',
              data: _writeJson(item),
            ),
    );
    final saved = _fromJson(kind, response.data ?? const {});
    _upsertCache(kind, saved);
    notifyListeners();
    return saved;
  }

  Future<void> delete(EntityKind kind, int id, {bool hard = false}) async {
    await _ensureLogin();
    await guard(
      () => dio.delete<void>(
        '/${kind.name}/$id',
        queryParameters: {if (hard) 'hard': true},
      ),
    );
    if (hard) {
      all(kind).removeWhere((item) => item.id == id);
    } else {
      await findById(kind, id);
    }
    notifyListeners();
  }

  Future<void> restore(EntityKind kind, int id) async {
    await _ensureLogin();
    final response = await guard(
      () => dio.post<Map<String, dynamic>>('/${kind.name}/$id/restore'),
    );
    _upsertCache(kind, _fromJson(kind, response.data ?? const {}));
    notifyListeners();
  }

  Future<int> deleteMany(EntityKind kind, List<int> ids) async {
    await _ensureLogin();
    final response = await guard(
      () => dio.post<Map<String, dynamic>>(
        '/${kind.name}/bulk-delete',
        data: {'ids': ids},
      ),
    );
    return _int(response.data?['deleted']);
  }

  Map<String, dynamic> _writeJson(AirlineModel item) =>
      Map<String, dynamic>.from(item.toJson())
        ..remove('id')
        ..remove('deletedAt');

  AirlineModel _fromJson(EntityKind kind, Map<String, dynamic> json) =>
      switch (kind) {
        EntityKind.flights => Flight.fromJson(json),
        EntityKind.aircraft => Aircraft.fromJson(json),
        EntityKind.pilots => Pilot.fromJson(json),
        EntityKind.services => AirlineService.fromJson(json),
        EntityKind.passengers => Passenger.fromJson(json),
      };

  int _int(Object? value, [int fallback = 0]) => switch (value) {
    int number => number,
    num number => number.toInt(),
    String text => int.tryParse(text) ?? fallback,
    _ => fallback,
  };

  List<AirlineModel> all(EntityKind kind) => switch (kind) {
    EntityKind.flights => flights,
    EntityKind.aircraft => aircraft,
    EntityKind.pilots => pilots,
    EntityKind.services => services,
    EntityKind.passengers => passengers,
  };

  AirlineModel? byId(EntityKind kind, int id) =>
      all(kind).where((item) => item.id == id).firstOrNull;
  int nextId(EntityKind kind) => 0;

  void _upsertCache(EntityKind kind, AirlineModel item) {
    final rows = all(kind);
    final index = rows.indexWhere((value) => value.id == item.id);
    if (index < 0) {
      rows.add(item);
    } else {
      rows[index] = item;
    }
  }

  Aircraft? aircraftById(int id) =>
      aircraft.where((item) => item.id == id).firstOrNull;
  Flight? flightById(int id) =>
      flights.where((item) => item.id == id).firstOrNull;
  String aircraftName(int id) {
    final item = aircraftById(id);
    return item == null
        ? 'Не указан'
        : '${item.registrationNumber} · ${item.model}';
  }

  String pilotNames(List<int> ids) => pilots
      .where((item) => ids.contains(item.id))
      .map((item) => item.fullName)
      .join(', ');
  String serviceNames(List<int> ids) => services
      .where((item) => ids.contains(item.id))
      .map((item) => item.name)
      .join(', ');
  String flightName(int id) {
    final item = flightById(id);
    return item == null
        ? 'Рейс не найден'
        : '${item.number} · ${item.destination}';
  }

  List<Pilot> compatiblePilots(int? aircraftId) {
    final type = aircraftById(aircraftId ?? -1)?.type;
    return pilots
        .where((item) => item.deletedAt == null && item.qualification == type)
        .toList();
  }

  @override
  void dispose() {
    _activeSearch?.cancel();
    dio.close(force: true);
    super.dispose();
  }
}
