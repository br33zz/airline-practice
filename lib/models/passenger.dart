class Passenger {
  final int id;
  final String fullName, passport, country, flightNumber;
  final DateTime? deletedAt;
  const Passenger({
    required this.id,
    required this.fullName,
    required this.passport,
    required this.country,
    required this.flightNumber,
    this.deletedAt,
  });
  bool get isDeleted => deletedAt != null;
  Passenger copyWith({
    String? fullName,
    String? passport,
    String? country,
    String? flightNumber,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) => Passenger(
    id: id,
    fullName: fullName ?? this.fullName,
    passport: passport ?? this.passport,
    country: country ?? this.country,
    flightNumber: flightNumber ?? this.flightNumber,
    deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
  );
}
