import 'package:flutter_test/flutter_test.dart';
import 'package:quincaillerie_app/core/auth/user_role.dart';

void main() {
  group('UserRole wire codec', () {
    test('round-trips all known roles', () {
      for (final role in UserRole.values) {
        expect(UserRole.fromWire(role.wireValue), equals(role));
      }
    });

    test('maps legacy wire values correctly', () {
      expect(UserRole.fromWire('owner'), UserRole.owner);
      expect(UserRole.fromWire('manager'), UserRole.manager);
      expect(UserRole.fromWire('cashier'), UserRole.cashier);
      expect(UserRole.fromWire('stock_manager'), UserRole.stockManager);
    });

    test('supports primary Stocki roles', () {
      expect(UserRole.owner.wireValue, 'owner');
      expect(UserRole.employee.wireValue, 'employee');
      expect(UserRole.primaryRoles, contains(UserRole.owner));
      expect(UserRole.primaryRoles, contains(UserRole.employee));
    });

    test('falls back to default role for unknown values', () {
      expect(UserRole.fromWire(null), UserRole.defaultRole);
      expect(UserRole.fromWire(''), UserRole.defaultRole);
      expect(UserRole.fromWire('unknown'), UserRole.defaultRole);
    });

    test('reserved future role parses correctly', () {
      expect(UserRole.fromWire('accountant'), UserRole.accountant);
      expect(UserRole.accountant.wireValue, 'accountant');
    });
  });
}
