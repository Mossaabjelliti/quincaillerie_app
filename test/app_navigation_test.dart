import 'package:flutter_test/flutter_test.dart';
import 'package:quincaillerie_app/core/auth/authorization_service.dart';
import 'package:quincaillerie_app/core/auth/user_role.dart';
import 'package:quincaillerie_app/core/auth/user_session.dart';
import 'package:quincaillerie_app/core/navigation/app_navigation.dart';
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

AuthorizationService _authz(UserRole role) =>
    AuthorizationService.fromSession(_session(role));

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
  group('AppNavigation', () {
    test('owner mobile navigation matches owner menu', () {
      final destinations = AppNavigation.visibleDestinations(
        _authz(UserRole.owner),
        platform: AppNavPlatform.mobile,
      );

      expect(
        destinations.map((d) => d.id).toList(),
        [
          'dashboard',
          'inventory',
          'sales',
          'customers',
          'suppliers',
          'invoices',
          'finance',
          'analytics',
          'employees',
          'activity',
          'settings',
        ],
      );
    });

    test('employee mobile navigation matches employee menu', () {
      final destinations = AppNavigation.visibleDestinations(
        _authz(UserRole.employee),
        platform: AppNavPlatform.mobile,
      );

      expect(
        destinations.map((d) => d.id).toList(),
        ['home', 'inventory', 'scanner', 'sales', 'customers', 'my_activity'],
      );
    });

    test('employee navigation excludes owner-only finance and settings', () {
      final destinations = AppNavigation.visibleDestinations(
        _authz(UserRole.employee),
        platform: AppNavPlatform.mobile,
      );

      final ids = destinations.map((d) => d.id).toSet();
      expect(ids, isNot(contains('finance')));
      expect(ids, isNot(contains('analytics')));
      expect(ids, isNot(contains('employees')));
      expect(ids, isNot(contains('settings')));
      expect(ids, isNot(contains('suppliers')));
    });

    test('cashier keeps operational employee items without customers', () {
      final destinations = AppNavigation.visibleDestinations(
        _authz(UserRole.cashier),
        platform: AppNavPlatform.mobile,
      );

      expect(destinations.map((d) => d.id).toList(), [
        'home',
        'inventory',
        'scanner',
        'sales',
        'my_activity',
      ]);
    });

    test('desktop owner navigation includes POS instead of scanner', () {
      final destinations = AppNavigation.visibleDestinations(
        _authz(UserRole.owner),
        platform: AppNavPlatform.desktop,
      );

      expect(destinations.map((d) => d.id), contains('pos'));
      expect(destinations.map((d) => d.id), isNot(contains('scanner')));
    });

    test('unauthenticated user sees no destinations', () {
      final destinations = AppNavigation.visibleDestinations(
        AuthorizationService.fromSession(null),
        platform: AppNavPlatform.mobile,
      );

      expect(destinations, isEmpty);
    });

    test('uses settings permission to select owner navigation shell', () {
      expect(AppNavigation.usesOwnerNavigation(_authz(UserRole.owner)), isTrue);
      expect(AppNavigation.usesOwnerNavigation(_authz(UserRole.manager)), isTrue);
      expect(AppNavigation.usesOwnerNavigation(_authz(UserRole.employee)), isFalse);
      expect(AppNavigation.usesOwnerNavigation(_authz(UserRole.cashier)), isFalse);
    });

    test('clampIndex keeps selection in range', () {
      expect(AppNavigation.clampIndex(3, 0), 0);
      expect(AppNavigation.clampIndex(5, 3), 2);
      expect(AppNavigation.clampIndex(1, 5), 1);
    });
  });
}
