import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/passenger.dart';
import '../state/airline_notifier.dart';
import '../widgets/entity_table.dart';
import 'entity_list_screen.dart';

class PassengersScreen extends StatelessWidget {
  final Uri uri;
  const PassengersScreen({super.key, required this.uri});
  @override
  Widget build(BuildContext context) => EntityListScreen<Passenger>(
    title: 'Пассажиры',
    path: '/passengers',
    filterLabel: 'Страна',
    uri: uri,
    notifier: context.read<PassengerListNotifier>(),
    filters: const ['Россия', 'Беларусь', 'Казахстан'],
    isDeleted: (x) => x.isDeleted,
    columns: [
      TableColumnSpec('ФИО', 'name', (x) => x.fullName),
      TableColumnSpec('Паспорт', 'passport', (x) => x.passport),
      TableColumnSpec('Страна', 'country', (x) => x.country),
      TableColumnSpec('Рейс', 'flight', (x) => x.flightNumber),
    ],
  );
}
