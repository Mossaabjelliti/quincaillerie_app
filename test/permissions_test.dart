import 'package:flutter_test/flutter_test.dart';
import 'package:quincaillerie_app/core/auth/auth_access.dart';
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
  group('Permission keys', () {
    test('every permission has a unique wire key', () {
      final keys = Permission.values.map((p) => p.key).toList();
      expect(keys.toSet().length, equals(Permission.values.length));
    });

    test('fromKey round-trips permission keys', () {
      for (final permission in Permission.values) {
        expect(Permission.fromKey(permission.key), permission);
      }
    });
  });

  group('RolePermissions', () {
    test('owner has all permissions', () {
      expect(RolePermissions.forRole(UserRole.owner), equals(RolePermissions.all));
      for (final permission in Permission.values) {
        expect(RolePermissions.has(UserRole.owner, permission), isTrue);
      }
    });

    test('manager has all permissions', () {
      expect(RolePermissions.forRole(UserRole.manager), equals(RolePermissions.all));
    });

    test('employee has operational permissions only', () {
      final grants = RolePermissions.forRole(UserRole.employee);

      expect(grants, contains(Permission.salesCreate));
      expect(grants, contains(Permission.customersManage));
      expect(grants, contains(Permission.activityViewOwn));

      expect(grants, isNot(contains(Permission.reportsFinancial)));
      expect(grants, isNot(contains(Permission.reportsAnalytics)));
      expect(grants, isNot(contains(Permission.employeesView)));
      expect(grants, isNot(contains(Permission.employeesManage)));
      expect(grants, isNot(contains(Permission.settingsManage)));
      expect(grants, isNot(contains(Permission.activityView)));
      expect(grants, isNot(contains(Permission.invoicesManage)));
    });

    test('cashier has sales-focused permissions only', () {
      final grants = RolePermissions.forRole(UserRole.cashier);

      expect(grants, contains(Permission.salesCreate));
      expect(grants, isNot(contains(Permission.customersManage)));
      expect(grants, isNot(contains(Permission.reportsFinancial)));
    });

    test('stock manager can mutate inventory but not view financial reports', () {
      expect(RolePermissions.has(UserRole.stockManager, Permission.inventoryUpdate), isTrue);
      expect(RolePermissions.has(UserRole.stockManager, Permission.reportsFinancial), isFalse);
      expect(RolePermissions.has(UserRole.stockManager, Permission.salesCreate), isTrue);
      expect(RolePermissions.has(UserRole.stockManager, Permission.salesView), isFalse);
    });

    test('accountant can access finance without employee management', () {
      final grants = RolePermissions.forRole(UserRole.accountant);

      expect(grants, contains(Permission.reportsFinancial));
      expect(grants, contains(Permission.invoicesManage));
      expect(grants, isNot(contains(Permission.employeesManage)));
      expect(grants, isNot(contains(Permission.settingsManage)));
    });
  });

  group('UserSession permission bridge', () {
    test('legacy getters derive from centralized permissions', () {
      final owner = _session(UserRole.owner);
      final employee = _session(UserRole.employee);
      final stockManager = _session(UserRole.stockManager);

      expect(owner.canManageStock, isTrue);
      expect(owner.canViewFinancials, isTrue);
      expect(owner.canPerformSales, isTrue);

      expect(employee.canManageStock, isFalse);
      expect(employee.canViewFinancials, isFalse);
      expect(employee.canPerformSales, isTrue);

      expect(stockManager.canManageStock, isTrue);
      expect(stockManager.canViewFinancials, isFalse);
    });

    test('hasPermission exposes role grants on session', () {
      final session = _session(UserRole.employee);
      expect(session.hasPermission(Permission.salesCreate), isTrue);
      expect(session.hasPermission(Permission.settingsManage), isFalse);
      expect(session.permissions, equals(RolePermissions.forRole(UserRole.employee)));
    });
  });

  group('AuthAccess auth bridge', () {
    test('null session yields no role and no permissions', () {
      expect(AuthAccess.currentUser(null), isNull);
      expect(AuthAccess.currentRole(null), isNull);
      expect(AuthAccess.permissions(null), isEmpty);
      expect(AuthAccess.hasPermission(null, Permission.salesCreate), isFalse);
    });

    test('authenticated session resolves user role and permissions', () {
      final session = _session(UserRole.owner);

      expect(AuthAccess.currentUser(session), same(session));
      expect(AuthAccess.currentRole(session), UserRole.owner);
      expect(AuthAccess.permissions(session), RolePermissions.all);
      expect(AuthAccess.hasPermission(session, Permission.settingsManage), isTrue);
    });

    test('invalid wire roles fall back to employee permissions', () {
      final session = UserSession(
        userId: 'user-1',
        userEmail: 'u@example.com',
        fullName: 'User',
        phone: '',
        currentStoreId: 'store-a',
        currentStoreName: 'Store A',
        currentRole: UserRole.fromWire('not-a-real-role'),
        stores: [_store('store-a')],
      );

      expect(session.currentRole, UserRole.employee);
      expect(AuthAccess.hasPermission(session, Permission.salesCreate), isTrue);
      expect(AuthAccess.hasPermission(session, Permission.settingsManage), isFalse);
    });

    test('store role change updates resolved permissions', () {
      final cashier = _session(UserRole.cashier);
      final manager = cashier.copyWith(currentRole: UserRole.manager);

      expect(AuthAccess.hasPermission(cashier, Permission.reportsFinancial), isFalse);
      expect(AuthAccess.hasPermission(manager, Permission.reportsFinancial), isTrue);
    });
  });
}
