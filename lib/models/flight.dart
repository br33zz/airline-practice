class Flight {
  final int id;
  final String number, destination, departure, status;
  final int seats;
  final DateTime? deletedAt;
  const Flight({
    required this.id,
    required this.number,
    required this.destination,
    required this.departure,
    required this.status,
    required this.seats,
    this.deletedAt,
  });
  bool get isDeleted => deletedAt != null;
  Flight copyWith({
    String? number,
    String? destination,
    String? departure,
    String? status,
    int? seats,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) => Flight(
    id: id,
    number: number ?? this.number,
    destination: destination ?? this.destination,
    departure: departure ?? this.departure,
    status: status ?? this.status,
    seats: seats ?? this.seats,
    deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
  );
}
