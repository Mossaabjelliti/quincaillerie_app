import 'package:flutter_test/flutter_test.dart';
import 'package:quincaillerie_app/core/auth/authorization_service.dart';
import 'package:quincaillerie_app/core/auth/permission.dart';
import 'package:quincaillerie_app/core/auth/role_permissions.dart';
import 'package:quincaillerie_app/core/auth/user_role.dart';
import 'package:quincaillerie_app/core/auth/user_session.dart';
import 'package:quincaillerie_app/data/local/database.dart';

Store _store(String id) => Store(
      id: id,
      name: 'Store $id',
      address: '',
      phone: '',
      ownerId: 'owner-1',
      createdAt: DateTime(2026, 1, 1),
      synced: true,
    );

UserSession _session(UserRole role) => UserSession(
      userId: 'user-1',
      userEmail: 'u@example.com',
      fullName: 'User',
      phone: '',
      currentStoreId: 'store-a',
      currentStoreName: 'Store A',
      currentRole: role,
      stores: [_store('store-a')],
    );

void main() {
  group('AuthorizationService', () {
    test('can denies all permissions when unauthenticated', () {
      final authz = AuthorizationService.fromSession(null);

      expect(authz.can(Permission.salesCreate), isFalse);
      expect(authz.can(Permission.settingsManage), isFalse);
      expect(authz.permissions, isEmpty);
    });

    test('can uses authenticated user permissions for owner', () {
      final authz = AuthorizationService.fromSession(_session(UserRole.owner));

      expect(authz.permissions, RolePermissions.all);
      expect(authz.can(Permission.employeesManage), isTrue);
      expect(authz.can(Permission.reportsFinancial), isTrue);
    });

    test('can uses authenticated user permissions for employee', () {
      final authz = AuthorizationService.fromSession(_session(UserRole.employee));

      expect(authz.can(Permission.salesCreate), isTrue);
      expect(authz.can(Permission.customersManage), isTrue);
      expect(authz.can(Permission.reportsFinancial), isFalse);
      expect(authz.can(Permission.employeesManage), isFalse);
      expect(authz.can(Permission.settingsManage), isFalse);
    });

    test('can reflects role changes on session', () {
      final authz = AuthorizationService.fromSession(_session(UserRole.cashier));
      expect(authz.can(Permission.reportsFinancial), isFalse);

      final managerAuthz =
          AuthorizationService.fromSession(_session(UserRole.manager));
      expect(managerAuthz.can(Permission.reportsFinancial), isTrue);
    });

    test('legacy session getters align with authorization service', () {
      final session = _session(UserRole.stockManager);
      final authz = AuthorizationService.fromSession(session);

      expect(authz.can(Permission.inventoryUpdate), equals(session.canManageStock));
      expect(authz.can(Permission.reportsFinancial), equals(session.canViewFinancials));
      expect(authz.can(Permission.salesCreate), equals(session.canPerformSales));
    });
  });
}
