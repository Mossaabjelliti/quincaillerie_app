import 'package:flutter_test/flutter_test.dart';
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

void main() {
  test('role resolution follows the selected store membership', () {
    final session = UserSession(
      userId: 'user-1',
      userEmail: 'u@example.com',
      fullName: 'User',
      phone: '',
      currentStoreId: 'store-a',
      currentStoreName: 'Store A',
      currentRole: UserRole.cashier,
      stores: [_store('store-a'), _store('store-b')],
      storeRoles: { 'store-a': UserRole.cashier, 'store-b': UserRole.manager },
    );

    expect(session.isOwner, isFalse);
    expect(session.canManageStock, isFalse);
    expect(session.canViewFinancials, isFalse);
    expect(session.roleForStore('store-b'), equals(UserRole.manager));
  });

  test('store managers inherit stock and finance permissions', () {
    final session = UserSession(
      userId: 'user-1',
      userEmail: 'u@example.com',
      fullName: 'User',
      phone: '',
      currentStoreId: 'store-b',
      currentStoreName: 'Store B',
      currentRole: UserRole.manager,
      stores: [_store('store-b')],
      storeRoles: {'store-b': UserRole.manager},
    );

    expect(session.canManageStock, isTrue);
    expect(session.canViewFinancials, isTrue);
    expect(session.hasActiveStore, isTrue);
  });
}
