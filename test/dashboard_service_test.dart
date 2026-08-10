import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:drift/native.dart';
import 'package:quincaillerie_app/core/auth/authorization_service.dart';
import 'package:quincaillerie_app/core/auth/user_role.dart';
import 'package:quincaillerie_app/core/auth/user_session.dart';
import 'package:quincaillerie_app/data/local/database.dart';
import 'package:quincaillerie_app/services/dashboard_service.dart';

UserSession _makeSession(UserRole role, String userId, {String storeId = 'store-1'}) => UserSession(
      userId: userId,
      userEmail: '$userId@stocki.app',
      fullName: 'Test $userId',
      phone: '',
      currentStoreId: storeId,
      currentStoreName: 'Test Store',
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

  group('DashboardService RBAC & Security Unit Tests', () {
    const storeId = 'store-1';
    const ownerUserId = 'owner-uid-100';
    const employeeUserId = 'employee-uid-200';

    setUp(() async {
      await db.into(db.sales).insert(
            SalesCompanion.insert(
              id: 'sale-owner-1',
              storeId: storeId,
              userId: ownerUserId,
              total: 500.0,
              paymentMethod: PaymentMethod.cash,
            ),
          );

      await db.into(db.sales).insert(
            SalesCompanion.insert(
              id: 'sale-emp-1',
              storeId: storeId,
              userId: employeeUserId,
              total: 150.0,
              paymentMethod: PaymentMethod.cash,
            ),
          );

      await db.into(db.products).insert(
            ProductsCompanion.insert(
              id: 'prod-1',
              storeId: storeId,
              name: 'Clous',
              barcode: '123',
              unit: ProductUnit.piece,
              quantity: const Value(2.0),
              lowStockThreshold: const Value(5.0),
              sellPrice: const Value(10.0),
            ),
          );
    });

    test('owner with reportsFinancial permission receives complete owner metrics', () async {
      final session = _makeSession(UserRole.owner, ownerUserId);
      final authService = AuthorizationService.fromSession(session);
      final dashboardService = DashboardService(db: db, authorizationService: authService);

      final ownerSummary = await dashboardService.getOwnerSummary();

      expect(ownerSummary.todayRevenue, equals(650.0));
      expect(ownerSummary.todaySalesCount, equals(2));
      expect(ownerSummary.productCount, equals(1));
      expect(ownerSummary.lowStockCount, equals(1));
      expect(ownerSummary.lowStockProducts, hasLength(1));
    });

    test('employee without reportsFinancial permission receives empty owner summary', () async {
      final session = _makeSession(UserRole.cashier, employeeUserId);
      final authService = AuthorizationService.fromSession(session);
      final dashboardService = DashboardService(db: db, authorizationService: authService);

      final ownerSummary = await dashboardService.getOwnerSummary();

      // Denied access fails safely returning empty summary
      expect(ownerSummary.todayRevenue, equals(0.0));
      expect(ownerSummary.todaySalesCount, equals(0));
      expect(ownerSummary.productCount, equals(0));
      expect(ownerSummary.lowStockProducts, isEmpty);
    });

    test('employee receives personal employee summary without sensitive financial metrics', () async {
      final session = _makeSession(UserRole.cashier, employeeUserId);
      final authService = AuthorizationService.fromSession(session);
      final dashboardService = DashboardService(db: db, authorizationService: authService);

      final empSummary = await dashboardService.getEmployeeSummary();

      expect(empSummary.todayPersonalSalesCount, equals(1));
      expect(empSummary.lowStockCount, equals(1));
      expect(empSummary.lowStockProducts, hasLength(1));
    });

    test('unauthenticated session returns empty summaries safely', () async {
      final authService = AuthorizationService.fromSession(null);
      final dashboardService = DashboardService(db: db, authorizationService: authService);

      final ownerSummary = await dashboardService.getOwnerSummary();
      final empSummary = await dashboardService.getEmployeeSummary();

      expect(ownerSummary.todayRevenue, equals(0.0));
      expect(empSummary.todayPersonalSalesCount, equals(0));
    });
  });
}
