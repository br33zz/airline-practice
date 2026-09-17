enum UserRole { reader, operator, admin }

extension UserRoleUi on UserRole {
  String get title => switch (this) {
    UserRole.reader => 'Пассажир',
    UserRole.operator => 'Диспетчер',
    UserRole.admin => 'Администратор',
  };

  static UserRole parse(String? value) => UserRole.values.firstWhere(
    (role) => role.name == value,
    orElse: () => UserRole.reader,
  );
}

enum AppPermission {
  viewCatalog,
  viewOwnBooking,
  renewBooking,
  manageOperations,
  manageDirectories,
  managePassengers,
  manageUsers,
  hardDelete,
  restoreRecords,
  viewStatistics,
}

const rolePermissions = <UserRole, Set<AppPermission>>{
  UserRole.reader: {
    AppPermission.viewCatalog,
    AppPermission.viewOwnBooking,
    AppPermission.renewBooking,
  },
  UserRole.operator: {
    AppPermission.viewCatalog,
    AppPermission.manageOperations,
    AppPermission.manageDirectories,
    AppPermission.managePassengers,
  },
  UserRole.admin: {
    AppPermission.viewCatalog,
    AppPermission.manageUsers,
    AppPermission.hardDelete,
    AppPermission.restoreRecords,
    AppPermission.viewStatistics,
  },
};

bool roleHas(UserRole role, AppPermission permission) =>
    rolePermissions[role]?.contains(permission) ?? false;

class AppUser {
  final int id;
  final String username;
  final String name;
  final UserRole role;

  const AppUser({
    required this.id,
    required this.username,
    required this.name,
    required this.role,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: (json['id'] as num?)?.toInt() ?? 0,
    username: json['username']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    role: UserRoleUi.parse(json['role']?.toString()),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'name': name,
    'role': role.name,
  };
}

class AuthResult {
  final String accessToken;
  final String refreshToken;
  final AppUser user;

  const AuthResult({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  factory AuthResult.fromJson(Map<String, dynamic> json) => AuthResult(
    accessToken: json['accessToken']?.toString() ?? '',
    refreshToken: json['refreshToken']?.toString() ?? '',
    user: AppUser.fromJson(
      Map<String, dynamic>.from(json['user'] as Map? ?? const {}),
    ),
  );
}
