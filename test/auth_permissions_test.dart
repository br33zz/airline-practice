import 'package:airline_practice/auth/auth_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Разграничение прав', () {
    test('пассажир видит каталог', () {
      expect(roleHas(UserRole.reader, AppPermission.viewCatalog), isTrue);
    });

    test('пассажир видит только собственный билет', () {
      expect(roleHas(UserRole.reader, AppPermission.viewOwnBooking), isTrue);
      expect(roleHas(UserRole.operator, AppPermission.viewOwnBooking), isFalse);
    });

    test('пассажир не управляет рейсами', () {
      expect(roleHas(UserRole.reader, AppPermission.manageOperations), isFalse);
    });

    test('диспетчер управляет рейсами', () {
      expect(
        roleHas(UserRole.operator, AppPermission.manageOperations),
        isTrue,
      );
    });

    test('диспетчер работает с пассажирами', () {
      expect(
        roleHas(UserRole.operator, AppPermission.managePassengers),
        isTrue,
      );
    });

    test('диспетчер не управляет ролями', () {
      expect(roleHas(UserRole.operator, AppPermission.manageUsers), isFalse);
    });

    test('администратор управляет пользователями', () {
      expect(roleHas(UserRole.admin, AppPermission.manageUsers), isTrue);
    });

    test('только администратор физически удаляет записи', () {
      expect(roleHas(UserRole.admin, AppPermission.hardDelete), isTrue);
      expect(roleHas(UserRole.operator, AppPermission.hardDelete), isFalse);
      expect(roleHas(UserRole.reader, AppPermission.hardDelete), isFalse);
    });

    test('администратор восстанавливает записи', () {
      expect(roleHas(UserRole.admin, AppPermission.restoreRecords), isTrue);
    });

    test('администратор видит статистику', () {
      expect(roleHas(UserRole.admin, AppPermission.viewStatistics), isTrue);
    });
  });
}
