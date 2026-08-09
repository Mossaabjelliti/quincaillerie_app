import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quincaillerie_app/core/auth/authorization_service.dart';
import 'package:quincaillerie_app/core/auth/permission.dart';
import 'package:quincaillerie_app/core/auth/user_role.dart';
import 'package:quincaillerie_app/core/auth/user_session.dart';
import 'package:quincaillerie_app/core/navigation/app_navigation.dart';
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
  group('RouteProtection', () {
    test('maps restricted destinations to required permissions', () {
      expect(
        RouteProtection.permissionForDestination('dashboard', Permission.reportsFinancial),
        Permission.reportsFinancial,
      );
      expect(
        RouteProtection.permissionForDestination('analytics', Permission.reportsAnalytics),
        Permission.reportsAnalytics,
      );
      expect(
        RouteProtection.permissionForDestination('employees', Permission.employeesView),
        Permission.employeesManage,
      );
      expect(
        RouteProtection.permissionForDestination('settings', Permission.settingsManage),
        Permission.settingsManage,
      );
      expect(
        RouteProtection.permissionForDestination('activity', Permission.activityView),
        Permission.activityView,
      );
      expect(
        RouteProtection.permissionForDestination('my_activity', Permission.activityViewOwn),
        Permission.activityViewOwn,
      );
    });

    test('maps named routes to required permissions', () {
      expect(RouteProtection.permissionForRoute('/sync-logs'), Permission.activityView);
      expect(RouteProtection.permissionForRoute('/cart'), Permission.salesCreate);
      expect(RouteProtection.permissionForRoute('/add-product'), Permission.inventoryCreate);
      expect(RouteProtection.permissionForRoute('/unknown'), isNull);
    });
  });

  group('RouteGuard', () {
    test('allows authorized access to protected content', () {
      final widget = RouteGuard.guardScreen(
        authz: _authz(UserRole.owner),
        permission: Permission.settingsManage,
        title: 'Paramètres',
        child: const Text('allowed'),
      );

      expect(widget, isA<Text>());
    });

    test('blocks unauthorized access with access denied screen', () {
      final widget = RouteGuard.guardScreen(
        authz: _authz(UserRole.employee),
        permission: Permission.settingsManage,
        title: 'Paramètres',
        child: const Text('allowed'),
      );

      expect(widget, isA<AccessDeniedScreen>());
    });

    test('employee can access own activity but not global activity routes', () {
      final employee = _authz(UserRole.employee);

      expect(
        RouteGuard.guardScreen(
          authz: employee,
          permission: Permission.activityViewOwn,
          child: const Text('mine'),
        ),
        isA<Text>(),
      );
      expect(
        RouteGuard.guardScreen(
          authz: employee,
          permission: Permission.activityView,
          child: const Text('global'),
        ),
        isA<AccessDeniedScreen>(),
      );
    });
  });

  group('AppNavigation.buildDestination', () {
    test('blocks employee from employee management screen even if navigated directly', () {
      const employeesDestination = AppNavDestination(
        id: 'employees',
        label: 'Employés',
        icon: Icons.group_outlined,
        permission: Permission.employeesView,
        ownerNav: true,
        employeeNav: false,
        platforms: {AppNavPlatform.mobile},
        builder: _stubScreen,
      );

      final widget = AppNavigation.buildDestination(
        employeesDestination,
        NavScreenContext(
          storeId: 'store-a',
          userId: 'user-1',
          authz: _authz(UserRole.employee),
        ),
      );

      expect(widget, isA<AccessDeniedScreen>());
    });
  });
}

Widget _stubScreen(NavScreenContext context) => const Text('screen');
