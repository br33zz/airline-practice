import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/flight.dart';
import '../models/list_query.dart';
import '../models/page_result.dart';
import '../models/passenger.dart';
import '../repositories/airline_repository.dart';

enum LoadStatus { idle, loading, success, error }

abstract class AirlineListNotifier<T> extends ChangeNotifier {
  final AirlineRepository repository;
  AirlineListNotifier(this.repository);
  ListQuery query = const ListQuery();
  PageResult<T> result = const PageResult(
    items: [],
    page: 1,
    size: 10,
    total: 0,
  );
  LoadStatus status = LoadStatus.idle;
  String? error;
  final Set<int> selected = {};
  Timer? _debounce;
  int idOf(T item);
  Future<PageResult<T>> find(ListQuery query);
  Future<int> deleteMany(List<int> ids);
  Future<void> deleteOne(int id, {bool hard = false});
  Future<void> restore(int id);

  Future<void> load() async {
    status = LoadStatus.loading;
    error = null;
    notifyListeners();
    try {
      result = await find(query);
      status = LoadStatus.success;
    } catch (e) {
      error = 'Не удалось загрузить данные: $e';
      status = LoadStatus.error;
    }
    notifyListeners();
  }

  Future<void> applyQuery(ListQuery next) async {
    query = next;
    selected.clear();
    await load();
  }

  void search(String value) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => applyQuery(query.copyWith(search: value)),
    );
  }

  void toggle(int id) {
    selected.contains(id) ? selected.remove(id) : selected.add(id);
    notifyListeners();
  }

  Future<void> removeSelected() async {
    await deleteMany(selected.toList());
    selected.clear();
    await load();
  }

  Future<void> remove(int id, {bool hard = false}) async {
    await deleteOne(id, hard: hard);
    await load();
  }

  Future<void> restoreOne(int id) async {
    await restore(id);
    await load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

class FlightListNotifier extends AirlineListNotifier<Flight> {
  FlightListNotifier(super.repository);
  @override
  int idOf(Flight item) => item.id;
  @override
  Future<PageResult<Flight>> find(ListQuery q) => repository.findFlights(q);
  @override
  Future<int> deleteMany(List<int> ids) => repository.deleteFlights(ids);
  @override
  Future<void> deleteOne(int id, {bool hard = false}) =>
      repository.deleteFlight(id, hard: hard);
  @override
  Future<void> restore(int id) => repository.restoreFlight(id);
}

class PassengerListNotifier extends AirlineListNotifier<Passenger> {
  PassengerListNotifier(super.repository);
  @override
  int idOf(Passenger item) => item.id;
  @override
  Future<PageResult<Passenger>> find(ListQuery q) =>
      repository.findPassengers(q);
  @override
  Future<int> deleteMany(List<int> ids) => repository.deletePassengers(ids);
  @override
  Future<void> deleteOne(int id, {bool hard = false}) =>
      repository.deletePassenger(id, hard: hard);
  @override
  Future<void> restore(int id) => repository.restorePassenger(id);
}
