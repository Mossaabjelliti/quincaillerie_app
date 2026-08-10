import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:quincaillerie_app/core/auth/authorization_service.dart';
import 'package:quincaillerie_app/core/auth/user_role.dart';
import 'package:quincaillerie_app/core/auth/user_session.dart';
import 'package:quincaillerie_app/data/local/database.dart';
import 'package:quincaillerie_app/features/dashboard/dashboard_provider.dart';
import 'package:quincaillerie_app/services/dashboard_service.dart';

UserSession _makeSession(UserRole role, String userId, {String storeId = 'store-1'}) => UserSession(
      userId: userId,
      userEmail: '$userId@stocki.app',
      fullName: 'Test $userId',
      phone: '',
      currentStoreId: storeId,
      currentStoreName: 'Test Store $storeId',
      currentRole: role,
      stores: const [],
      storeRoles: {storeId: role},
    );

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('DashboardProvider Unit Tests', () {
    const storeId = 'store-1';
    const ownerUserId = 'owner-uid-1';
    const cashierUserId = 'cashier-uid-2';

    setUp(() async {
      await db.into(db.sales).insert(
            SalesCompanion.insert(
              id: 's-1',
              storeId: storeId,
              userId: cashierUserId,
              total: 300.0,
              paymentMethod: PaymentMethod.cash,
            ),
          );
    });

    test('owner role populates owner summary and keeps employee summary empty', () async {
      final session = _makeSession(UserRole.owner, ownerUserId);
      final authService = AuthorizationService.fromSession(session);
      final dashboardService = DashboardService(db: db, authorizationService: authService);

      final provider = DashboardProvider(
        dashboardService: dashboardService,
        authorizationService: authService,
      );

      // Wait for async refresh()
      await Future.delayed(const Duration(milliseconds: 100));

      expect(provider.isLoading, isFalse);
      expect(provider.error,isNull);
      expect(provider.ownerSummary.todayRevenue, equals(300.0));
      expect(provider.employeeSummary.todayPersonalSalesCount, equals(0));
    });

    test('cashier role populates employee summary and keeps owner summary empty', () async {
      final session = _makeSession(UserRole.cashier, cashierUserId);
      final authService = AuthorizationService.fromSession(session);
      final dashboardService = DashboardService(db: db, authorizationService: authService);

      final provider = DashboardProvider(
        dashboardService: dashboardService,
        authorizationService: authService,
      );

      await Future.delayed(const Duration(milliseconds: 100));

      expect(provider.isLoading, isFalse);
      expect(provider.error, isNull);
      expect(provider.ownerSummary.todayRevenue, equals(0.0));
      expect(provider.employeeSummary.todayPersonalSalesCount, equals(1));
    });

    test('unauthenticated session keeps both summaries empty safely', () async {
      final authService = AuthorizationService.fromSession(null);
      final dashboardService = DashboardService(db: db, authorizationService: authService);

      final provider = DashboardProvider(
        dashboardService: dashboardService,
        authorizationService: authService,
      );

      await Future.delayed(const Duration(milliseconds: 100));

      expect(provider.isLoading, isFalse);
      expect(provider.error, isNull);
      expect(provider.ownerSummary.todayRevenue, equals(0.0));
      expect(provider.employeeSummary.todayPersonalSalesCount, equals(0));
    });
  });
}
