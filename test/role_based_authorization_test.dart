import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:quincaillerie_app/core/auth/authorization_service.dart';
import 'package:quincaillerie_app/core/auth/permission.dart';
import 'package:quincaillerie_app/core/auth/user_role.dart';
import 'package:quincaillerie_app/core/auth/user_session.dart';
import 'package:quincaillerie_app/core/navigation/route_guard.dart';
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
      userEmail: 'user@stocki.app',
      fullName: 'Test User',
      phone: '',
      currentStoreId: 'store-a',
      currentStoreName: 'Store A',
      currentRole: role,
      stores: [_store('store-a')],
    );

AuthorizationService _authz(UserRole role) =>
    AuthorizationService.fromSession(_session(role));

void main() {
  group('Owner Authorization Unit Tests', () {
    final ownerAuthz = _authz(UserRole.owner);

    test('owner has full inventory access', () {
      expect(ownerAuthz.can(Permission.inventoryView), isTrue);
      expect(ownerAuthz.can(Permission.inventoryCreate), isTrue);
      expect(ownerAuthz.can(Permission.inventoryUpdate), isTrue);
      expect(ownerAuthz.can(Permission.inventoryDelete), isTrue);
    });

    test('owner has full sales permissions', () {
      expect(ownerAuthz.can(Permission.salesView), isTrue);
      expect(ownerAuthz.can(Permission.salesCreate), isTrue);
      expect(ownerAuthz.can(Permission.salesCancel), isTrue);
    });

    test('owner has full invoices access', () {
      expect(ownerAuthz.can(Permission.invoicesView), isTrue);
      expect(ownerAuthz.can(Permission.invoicesCreate), isTrue);
      expect(ownerAuthz.can(Permission.invoicesManage), isTrue);
    });

    test('owner has access to financial reports', () {
      expect(ownerAuthz.can(Permission.reportsFinancial), isTrue);
    });

    test('owner has access to analytics', () {
      expect(ownerAuthz.can(Permission.reportsAnalytics), isTrue);
    });

    test('owner has employee management permissions', () {
      expect(ownerAuthz.can(Permission.employeesView), isTrue);
      expect(ownerAuthz.can(Permission.employeesManage), isTrue);
    });

    test('owner has settings management permissions', () {
      expect(ownerAuthz.can(Permission.settingsManage), isTrue);
    });

    test('owner has all-activity inspection permissions', () {
      expect(ownerAuthz.can(Permission.activityView), isTrue);
      expect(ownerAuthz.can(Permission.activityViewOwn), isTrue);
    });
  });

  group('Employee Authorization Unit Tests', () {
    final employeeAuthz = _authz(UserRole.employee);

    test('employee has inventory view access', () {
      expect(employeeAuthz.can(Permission.inventoryView), isTrue);
      expect(employeeAuthz.can(Permission.inventoryCreate), isFalse);
      expect(employeeAuthz.can(Permission.inventoryUpdate), isFalse);
      expect(employeeAuthz.can(Permission.inventoryDelete), isFalse);
    });

    test('employee scanner and sales creation access', () {
      expect(employeeAuthz.can(Permission.salesCreate), isTrue);
      expect(employeeAuthz.can(Permission.salesView), isTrue);
      expect(employeeAuthz.can(Permission.salesCancel), isTrue);
    });

    test('employee customer management permissions', () {
      expect(employeeAuthz.can(Permission.customersView), isTrue);
      expect(employeeAuthz.can(Permission.customersManage), isTrue);
    });

    test('employee cannot access financial reports', () {
      expect(employeeAuthz.can(Permission.reportsFinancial), isFalse);
    });

    test('employee cannot access analytics', () {
      expect(employeeAuthz.can(Permission.reportsAnalytics), isFalse);
    });

    test('employee cannot view or manage employees', () {
      expect(employeeAuthz.can(Permission.employeesView), isFalse);
      expect(employeeAuthz.can(Permission.employeesManage), isFalse);
    });

    test('employee cannot access sensitive settings', () {
      expect(employeeAuthz.can(Permission.settingsManage), isFalse);
    });

    test('employee cannot access owner-wide activity log exports', () {
      expect(employeeAuthz.can(Permission.activityView), isFalse);
    });

    test('employee can access own activity log', () {
      expect(employeeAuthz.can(Permission.activityViewOwn), isTrue);
    });
  });

  group('Direct Route & Screen Protection Tests', () {
    testWidgets('allows owner direct access to protected named route', (tester) async {
      final ownerAuthz = _authz(UserRole.owner);

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthorizationService>.value(
          value: ownerAuthz,
          child: MaterialApp(
            initialRoute: '/add-product',
            routes: {
              '/add-product': (context) => RouteGuard.guardedRoute(
                    context,
                    routeName: '/add-product',
                    child: const Text('Add Product Content'),
                  ),
            },
          ),
        ),
      );

      expect(find.text('Add Product Content'), findsOneWidget);
      expect(find.byType(AccessDeniedScreen), findsNothing);
    });

    testWidgets('blocks employee from restricted route (/sync-logs)', (tester) async {
      final employeeAuthz = _authz(UserRole.employee);

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthorizationService>.value(
          value: employeeAuthz,
          child: MaterialApp(
            initialRoute: '/sync-logs',
            routes: {
              '/sync-logs': (context) => RouteGuard.guardedRoute(
                    context,
                    routeName: '/sync-logs',
                    child: const Text('Sync Logs Content'),
                  ),
            },
          ),
        ),
      );

      expect(find.byType(AccessDeniedScreen), findsOneWidget);
      expect(find.text('Sync Logs Content'), findsNothing);
    });

    testWidgets('blocks cashier from supplier management route (/suppliers)', (tester) async {
      final cashierAuthz = _authz(UserRole.cashier);

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthorizationService>.value(
          value: cashierAuthz,
          child: MaterialApp(
            initialRoute: '/suppliers',
            routes: {
              '/suppliers': (context) => RouteGuard.guardedRoute(
                    context,
                    routeName: '/suppliers',
                    child: const Text('Suppliers Content'),
                  ),
            },
          ),
        ),
      );

      expect(find.byType(AccessDeniedScreen), findsOneWidget);
      expect(find.text('Suppliers Content'), findsNothing);
    });

    testWidgets('blocks unauthenticated user from direct route access', (tester) async {
      final unauthAuthz = AuthorizationService.fromSession(null);

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthorizationService>.value(
          value: unauthAuthz,
          child: MaterialApp(
            initialRoute: '/add-product',
            routes: {
              '/add-product': (context) => RouteGuard.guardedRoute(
                    context,
                    routeName: '/add-product',
                    child: const Text('Add Product Content'),
                  ),
            },
          ),
        ),
      );

      expect(find.byType(AccessDeniedScreen), findsOneWidget);
      expect(find.text('Add Product Content'), findsNothing);
    });
  });

  group('Session Logout & User Switching State Validation', () {
    test('logout revokes all permissions immediately', () {
      final authz = AuthorizationService.fromSession(_session(UserRole.owner));
      expect(authz.can(Permission.settingsManage), isTrue);

      // Simulate logout
      final loggedOutAuthz = AuthorizationService.fromSession(null);
      expect(loggedOutAuthz.can(Permission.settingsManage), isFalse);
      expect(loggedOutAuthz.permissions, isEmpty);
    });

    test('switching user session updates permissions cleanly without stale role state', () {
      // User 1 (Owner)
      final user1Authz = AuthorizationService.fromSession(_session(UserRole.owner));
      expect(user1Authz.can(Permission.employeesManage), isTrue);

      // User 2 (Employee) signs in on same device
      final user2Authz = AuthorizationService.fromSession(_session(UserRole.employee));
      expect(user2Authz.can(Permission.employeesManage), isFalse);
      expect(user2Authz.can(Permission.salesCreate), isTrue);

      // User 1 signs back in
      final user1ReAuthz = AuthorizationService.fromSession(_session(UserRole.owner));
      expect(user1ReAuthz.can(Permission.employeesManage), isTrue);
    });
  });
}
