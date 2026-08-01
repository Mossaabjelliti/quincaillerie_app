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

void main() {
  test('role resolution follows the selected store membership', () {
    final session = UserSession(
      userId: 'user-1',
      userEmail: 'u@example.com',
      fullName: 'User',
      phone: '',
      currentStoreId: 'store-a',
      currentStoreName: 'Store A',
      currentRole: 'cashier',
      stores: [_store('store-a'), _store('store-b')],
      storeRoles: {'store-a': 'cashier', 'store-b': 'manager'},
    );

    expect(session.isOwner, isFalse);
    expect(session.canManageStock, isFalse);
    expect(session.canViewFinancials, isFalse);
    expect(session.roleForStore('store-b'), equals('manager'));
  });

  test('store managers inherit stock and finance permissions', () {
    final session = UserSession(
      userId: 'user-1',
      userEmail: 'u@example.com',
      fullName: 'User',
      phone: '',
      currentStoreId: 'store-b',
      currentStoreName: 'Store B',
      currentRole: 'manager',
      stores: [_store('store-b')],
      storeRoles: {'store-b': 'manager'},
    );

    expect(session.canManageStock, isTrue);
    expect(session.canViewFinancials, isTrue);
    expect(session.hasActiveStore, isTrue);
  });
}
