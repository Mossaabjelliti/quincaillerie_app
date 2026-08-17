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
    test('owner mobile navigation matches clean 5-item menu', () {
      final destinations = AppNavigation.visibleDestinations(
        _authz(UserRole.owner),
        platform: AppNavPlatform.mobile,
      );

      expect(
        destinations.map((d) => d.id).toList(),
        [
          'dashboard',
          'sales',
          'scanner',
          'inventory',
          'more',
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
        ['sales', 'scanner', 'inventory', 'customers', 'more'],
      );
    });

    test('cashier keeps operational employee items without customers', () {
      final destinations = AppNavigation.visibleDestinations(
        _authz(UserRole.cashier),
        platform: AppNavPlatform.mobile,
      );

      expect(destinations.map((d) => d.id).toList(), [
        'sales',
        'scanner',
        'inventory',
        'more',
      ]);
    });

    test('unfinished features are hidden from primary navigation', () {
      final ownerMobile = AppNavigation.visibleDestinations(
        _authz(UserRole.owner),
        platform: AppNavPlatform.mobile,
      ).map((d) => d.id).toSet();

      final ownerDesktop = AppNavigation.visibleDestinations(
        _authz(UserRole.owner),
        platform: AppNavPlatform.desktop,
      ).map((d) => d.id).toSet();

      expect(ownerMobile, isNot(contains('invoices')));
      expect(ownerMobile, isNot(contains('finance')));
      expect(ownerMobile, isNot(contains('analytics')));

      expect(ownerDesktop, isNot(contains('invoices')));
      expect(ownerDesktop, isNot(contains('finance')));
      expect(ownerDesktop, isNot(contains('analytics')));
    });

    test('employee navigation excludes owner-only areas on desktop', () {
      final destinations = AppNavigation.visibleDestinations(
        _authz(UserRole.employee),
        platform: AppNavPlatform.desktop,
      );

      final ids = destinations.map((d) => d.id).toSet();
      expect(ids, isNot(contains('dashboard')));
      expect(ids, isNot(contains('suppliers')));
      expect(ids, isNot(contains('employees')));
      expect(ids, isNot(contains('activity')));
      expect(ids, contains('pos'));
      expect(ids, contains('inventory'));
      expect(ids, contains('sales'));
      expect(ids, contains('customers'));
      expect(ids, contains('my_activity'));
      expect(ids, contains('settings'));
    });

    test('desktop owner navigation includes POS, inventory, sales, customers, suppliers, dashboard, employees, activity, settings', () {
      final destinations = AppNavigation.visibleDestinations(
        _authz(UserRole.owner),
        platform: AppNavPlatform.desktop,
      );

      expect(destinations.map((d) => d.id).toList(), [
        'dashboard',
        'pos',
        'sales',
        'inventory',
        'customers',
        'suppliers',
        'employees',
        'activity',
        'settings',
      ]);
      expect(destinations.map((d) => d.id), isNot(contains('scanner')));
    });

    test('scanner is visible on mobile for both owner and employee', () {
      final ownerMobile = AppNavigation.visibleDestinations(
        _authz(UserRole.owner),
        platform: AppNavPlatform.mobile,
      ).map((d) => d.id).toSet();

      final empMobile = AppNavigation.visibleDestinations(
        _authz(UserRole.employee),
        platform: AppNavPlatform.mobile,
      ).map((d) => d.id).toSet();

      expect(ownerMobile, contains('scanner'));
      expect(empMobile, contains('scanner'));
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
