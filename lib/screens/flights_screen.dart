import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/flight.dart';
import '../state/airline_notifier.dart';
import '../widgets/entity_table.dart';
import 'entity_list_screen.dart';

class FlightsScreen extends StatelessWidget {
  final Uri uri;
  const FlightsScreen({super.key, required this.uri});
  @override
  Widget build(BuildContext context) => EntityListScreen<Flight>(
    title: 'Рейсы',
    path: '/flights',
    filterLabel: 'Статус',
    uri: uri,
    notifier: context.read<FlightListNotifier>(),
    filters: const ['По расписанию', 'Посадка', 'Задержан'],
    isDeleted: (x) => x.isDeleted,
    columns: [
      TableColumnSpec('Рейс', 'number', (x) => x.number),
      TableColumnSpec('Направление', 'destination', (x) => x.destination),
      TableColumnSpec('Вылет', 'departure', (x) => x.departure),
      TableColumnSpec('Мест', 'seats', (x) => '${x.seats}'),
      TableColumnSpec('Статус', 'status', (x) => x.status),
    ],
  );
}
