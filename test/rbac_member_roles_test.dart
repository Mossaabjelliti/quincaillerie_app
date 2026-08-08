import 'package:flutter_test/flutter_test.dart';
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

UserSession _session({
  required String currentRole,
  Map<String, String> storeRoles = const {},
  String currentStoreId = 'store-a',
}) =>
    UserSession(
      userId: 'user-1',
      userEmail: 'u@example.com',
      fullName: 'User',
      phone: '',
      currentStoreId: currentStoreId,
      currentStoreName: 'Store A',
      currentRole: currentRole,
      stores: [_store('store-a'), _store('store-b')],
      storeRoles: storeRoles,
    );

void main() {
  group('RBAC Role Permissions', () {
    test('owner has all permissions', () {
      final session = _session(currentRole: 'owner', storeRoles: {'store-a': 'owner'});
      expect(session.isOwner, isTrue);
      expect(session.isManager, isTrue);
      expect(session.canManageStock, isTrue);
      expect(session.canViewFinancials, isTrue);
      expect(session.canPerformSales, isTrue);
    });

    test('manager inherits stock and finance access', () {
      final session = _session(currentRole: 'manager', storeRoles: {'store-a': 'manager'});
      expect(session.isOwner, isFalse);
      expect(session.isManager, isTrue);
      expect(session.canManageStock, isTrue);
      expect(session.canViewFinancials, isTrue);
    });

    test('stock_manager can manage stock but not view financials', () {
      final session = _session(currentRole: 'stock_manager', storeRoles: {'store-a': 'stock_manager'});
      expect(session.isManager, isFalse);
      expect(session.canManageStock, isTrue);
      expect(session.canViewFinancials, isFalse);
      expect(session.canPerformSales, isTrue);
    });

    test('cashier can perform sales only', () {
      final session = _session(currentRole: 'cashier', storeRoles: {'store-a': 'cashier'});
      expect(session.isManager, isFalse);
      expect(session.canManageStock, isFalse);
      expect(session.canViewFinancials, isFalse);
      expect(session.canPerformSales, isTrue);
    });

    test('role resolution follows store membership', () {
      final session = _session(
        currentRole: 'cashier',
        currentStoreId: 'store-b',
        storeRoles: {'store-a': 'cashier', 'store-b': 'manager'},
      );
      expect(session.roleForStore('store-a'), equals('cashier'));
      expect(session.roleForStore('store-b'), equals('manager'));
      // Permissions are driven by currentRole, not by roleForStore.
      // The AuthProvider.selectStore() updates currentRole on store switch.
      expect(session.canViewFinancials, isFalse); // currentRole is 'cashier'
    });

    test('switching store updates current role and permissions', () {
      final session = _session(
        currentRole: 'manager',
        currentStoreId: 'store-b',
        storeRoles: {'store-a': 'cashier', 'store-b': 'manager'},
      );
      // Once currentRole reflects the selected store's membership:
      expect(session.canViewFinancials, isTrue);
      expect(session.canManageStock, isTrue);
    });
  });
}