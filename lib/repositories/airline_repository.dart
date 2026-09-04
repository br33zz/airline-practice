import '../models/flight.dart';
import '../models/list_query.dart';
import '../models/page_result.dart';
import '../models/passenger.dart';

abstract interface class AirlineRepository {
  Future<PageResult<Flight>> findFlights(ListQuery query);
  Future<PageResult<Passenger>> findPassengers(ListQuery query);
  Future<int> deleteFlights(List<int> ids);
  Future<int> deletePassengers(List<int> ids);
  Future<void> deleteFlight(int id, {bool hard = false});
  Future<void> deletePassenger(int id, {bool hard = false});
  Future<void> restoreFlight(int id);
  Future<void> restorePassenger(int id);
}

class InMemoryAirlineRepository implements AirlineRepository {
  final List<Flight> _flights = List.generate(
    36,
    (i) => Flight(
      id: i + 1,
      number: 'SU ${100 + i}',
      destination: const [
        'Москва',
        'Сочи',
        'Казань',
        'Санкт-Петербург',
        'Екатеринбург',
      ][i % 5],
      departure:
          '${(6 + i % 17).toString().padLeft(2, '0')}:${(i * 5 % 60).toString().padLeft(2, '0')}',
      status: const ['По расписанию', 'Посадка', 'Задержан'][i % 3],
      seats: 120 + i * 2,
    ),
  );
  final List<Passenger> _passengers = List.generate(
    30,
    (i) => Passenger(
      id: i + 1,
      fullName:
          '${const ['Иванов', 'Петрова', 'Сидоров', 'Смирнова', 'Кузнецов'][i % 5]} ${const ['Иван', 'Анна', 'Максим', 'Ольга', 'Алексей'][i % 5]}',
      passport: '${4500 + i} ${100000 + i}',
      country: const ['Россия', 'Беларусь', 'Казахстан'][i % 3],
      flightNumber: 'SU ${100 + i % 18}',
    ),
  );

  PageResult<T> _page<T>(List<T> rows, ListQuery q) {
    final total = rows.length;
    final safePage = q.page.clamp(1, total == 0 ? 1 : (total / q.size).ceil());
    final from = (safePage - 1) * q.size;
    final to = (from + q.size).clamp(0, total);
    return PageResult(
      items: from >= total ? <T>[] : rows.sublist(from, to),
      page: safePage,
      size: q.size,
      total: total,
    );
  }

  @override
  Future<PageResult<Flight>> findFlights(ListQuery q) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final needle = q.search.trim().toLowerCase();
    var rows = _flights
        .where(
          (x) =>
              (q.includeDeleted || !x.isDeleted) &&
              (needle.isEmpty ||
                  x.number.toLowerCase().contains(needle) ||
                  x.destination.toLowerCase().contains(needle)) &&
              (q.filter.isEmpty || x.status == q.filter),
        )
        .toList();
    rows.sort((a, b) {
      final n = switch (q.sortField) {
        'number' => a.number.compareTo(b.number),
        'destination' => a.destination.compareTo(b.destination),
        'departure' => a.departure.compareTo(b.departure),
        'seats' => a.seats.compareTo(b.seats),
        _ => a.id.compareTo(b.id),
      };
      return q.sortAscending ? n : -n;
    });
    return _page(rows, q);
  }

  @override
  Future<PageResult<Passenger>> findPassengers(ListQuery q) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final needle = q.search.trim().toLowerCase();
    var rows = _passengers
        .where(
          (x) =>
              (q.includeDeleted || !x.isDeleted) &&
              (needle.isEmpty ||
                  x.fullName.toLowerCase().contains(needle) ||
                  x.passport.toLowerCase().contains(needle)) &&
              (q.filter.isEmpty || x.country == q.filter),
        )
        .toList();
    rows.sort((a, b) {
      final n = switch (q.sortField) {
        'name' => a.fullName.compareTo(b.fullName),
        'passport' => a.passport.compareTo(b.passport),
        'country' => a.country.compareTo(b.country),
        _ => a.id.compareTo(b.id),
      };
      return q.sortAscending ? n : -n;
    });
    return _page(rows, q);
  }

  @override
  Future<int> deleteFlights(List<int> ids) async {
    var count = 0;
    for (final id in ids) {
      final i = _flights.indexWhere((x) => x.id == id && !x.isDeleted);
      if (i >= 0) {
        _flights[i] = _flights[i].copyWith(deletedAt: DateTime.now());
        count++;
      }
    }
    return count;
  }

  @override
  Future<int> deletePassengers(List<int> ids) async {
    var count = 0;
    for (final id in ids) {
      final i = _passengers.indexWhere((x) => x.id == id && !x.isDeleted);
      if (i >= 0) {
        _passengers[i] = _passengers[i].copyWith(deletedAt: DateTime.now());
        count++;
      }
    }
    return count;
  }

  @override
  Future<void> deleteFlight(int id, {bool hard = false}) async {
    if (hard) {
      _flights.removeWhere((x) => x.id == id);
    } else {
      await deleteFlights([id]);
    }
  }

  @override
  Future<void> deletePassenger(int id, {bool hard = false}) async {
    if (hard) {
      _passengers.removeWhere((x) => x.id == id);
    } else {
      await deletePassengers([id]);
    }
  }

  @override
  Future<void> restoreFlight(int id) async {
    final i = _flights.indexWhere((x) => x.id == id);
    if (i >= 0) _flights[i] = _flights[i].copyWith(clearDeletedAt: true);
  }

  @override
  Future<void> restorePassenger(int id) async {
    final i = _passengers.indexWhere((x) => x.id == id);
    if (i >= 0) _passengers[i] = _passengers[i].copyWith(clearDeletedAt: true);
  }
}
