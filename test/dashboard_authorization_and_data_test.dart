import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide Column, isNull;
import 'package:drift/native.dart';
import 'package:quincaillerie_app/core/auth/authorization_service.dart';
import 'package:quincaillerie_app/core/auth/user_role.dart';
import 'package:quincaillerie_app/core/auth/user_session.dart';
import 'package:quincaillerie_app/data/local/database.dart';
import 'package:quincaillerie_app/services/dashboard_service.dart';

UserSession _makeSession(UserRole role, String userId, {String storeId = 'store-A'}) => UserSession(
      userId: userId,
      userEmail: '$userId@stocki.app',
      fullName: 'Test User $userId',
      phone: '',
      currentStoreId: storeId,
      currentStoreName: 'Store $storeId',
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

  group('Dashboard Data & Authorization Deep Verification Tests', () {
    const storeA = 'store-A';
    const storeB = 'store-B';
    const ownerUserId = 'owner-uid-1';
    const empUserId1 = 'emp-uid-1';
    const empUserId2 = 'emp-uid-2';

    setUp(() async {
      final now = DateTime.now();

      // Store A Products
      await db.into(db.products).insert(
            ProductsCompanion.insert(
              id: 'p-1',
              storeId: storeA,
              name: 'Tournevis PH2',
              barcode: '1001',
              unit: ProductUnit.piece,
              quantity: const Value(2.0), // Low stock
              lowStockThreshold: const Value(5.0),
              sellPrice: const Value(25.0),
            ),
          );

      // Store B Product (for multi-tenant scoping test)
      await db.into(db.products).insert(
            ProductsCompanion.insert(
              id: 'p-2',
              storeId: storeB,
              name: 'Ciment 50kg',
              barcode: '1002',
              unit: ProductUnit.kg,
              quantity: const Value(1.0),
              lowStockThreshold: const Value(10.0),
              sellPrice: const Value(100.0),
            ),
          );

      // Store A Sales
      await db.into(db.sales).insert(
            SalesCompanion.insert(
              id: 's-1',
              storeId: storeA,
              userId: empUserId1,
              total: 200.0,
              paymentMethod: PaymentMethod.cash,
              createdAt: Value(now),
            ),
          );

      await db.into(db.sales).insert(
            SalesCompanion.insert(
              id: 's-2',
              storeId: storeA,
              userId: empUserId2,
              total: 350.0,
              paymentMethod: PaymentMethod.credit,
              createdAt: Value(now),
            ),
          );

      // Store B Sale (scoping test)
      await db.into(db.sales).insert(
            SalesCompanion.insert(
              id: 's-3',
              storeId: storeB,
              userId: empUserId1,
              total: 999.0,
              paymentMethod: PaymentMethod.cash,
              createdAt: Value(now),
            ),
          );

      // Store A Customer Debt
      await db.into(db.customers).insert(
            CustomersCompanion.insert(
              id: 'c-1',
              storeId: storeA,
              name: 'Client Alpha',
            ),
          );

      await db.into(db.customerDebts).insert(
            CustomerDebtsCompanion.insert(
              id: 'd-1',
              storeId: storeA,
              customerId: 'c-1',
              totalAmount: 400.0,
              paidAmount: const Value(100.0),
              remainingAmount: 300.0,
            ),
          );

      // Store A Activities
      await db.into(db.activityLogs).insert(
            ActivityLogsCompanion.insert(
              id: 'act-emp1',
              storeId: storeA,
              userId: empUserId1,
              action: 'SALE_COMPLETED',
              entityType: 'sale',
              entityId: 's-1',
              timestamp: Value(now),
            ),
          );

      await db.into(db.activityLogs).insert(
            ActivityLogsCompanion.insert(
              id: 'act-emp2',
              storeId: storeA,
              userId: empUserId2,
              action: 'STOCK_ADJUSTED',
              entityType: 'product',
              entityId: 'p-1',
              timestamp: Value(now.add(const Duration(minutes: 2))),
            ),
          );
    });

    test('OWNER receives complete sales, inventory, debt, and store-wide activity metrics', () async {
      final session = _makeSession(UserRole.owner, ownerUserId, storeId: storeA);
      final authService = AuthorizationService.fromSession(session);
      final service = DashboardService(db: db, authorizationService: authService);

      final summary = await service.getOwnerSummary();

      // Sales & Revenue
      expect(summary.todayRevenue, equals(550.0));
      expect(summary.weeklyRevenue, equals(550.0));
      expect(summary.monthlyRevenue, equals(550.0));
      expect(summary.todaySalesCount, equals(2));
      expect(summary.paymentMethodBreakdown[PaymentMethod.cash], equals(200.0));
      expect(summary.paymentMethodBreakdown[PaymentMethod.credit], equals(350.0));

      // Inventory
      expect(summary.productCount, equals(1)); // Only Store A product
      expect(summary.stockValuation, equals(50.0)); // 2 * 25.0
      expect(summary.lowStockCount, equals(1));
      expect(summary.lowStockProducts, hasLength(1));
      expect(summary.lowStockProducts.first.name, equals('Tournevis PH2'));

      // Debt
      expect(summary.outstandingCustomerDebt, equals(300.0));
      expect(summary.unpaidDebtCount, equals(1));

      // Store-wide Activity
      expect(summary.recentActivity, hasLength(2));
    });

    test('EMPLOYEE receives personal sales count, low stock data, own activity, and NO financial metrics', () async {
      final session = _makeSession(UserRole.cashier, empUserId1, storeId: storeA);
      final authService = AuthorizationService.fromSession(session);
      final service = DashboardService(db: db, authorizationService: authService);

      // Employee calls getEmployeeSummary
      final empSummary = await service.getEmployeeSummary();

      expect(empSummary.todayPersonalSalesCount, equals(1)); // Only empUserId1 sale s-1
      expect(empSummary.lowStockCount, equals(1));
      expect(empSummary.lowStockProducts, hasLength(1));
      expect(empSummary.recentPersonalActivity, hasLength(1)); // Only empUserId1 activity
      expect(empSummary.recentPersonalActivity.first.userId, equals(empUserId1));

      // Employee attempting to access getOwnerSummary is rejected safely
      final ownerSummaryAttempt = await service.getOwnerSummary();
      expect(ownerSummaryAttempt.todayRevenue, equals(0.0));
      expect(ownerSummaryAttempt.stockValuation, equals(0.0));
      expect(ownerSummaryAttempt.outstandingCustomerDebt, equals(0.0));
      expect(ownerSummaryAttempt.recentActivity, isEmpty);
    });

    test('verifies strict storeId and userId query scoping across stores and users', () async {
      // empUserId1 in Store B
      final sessionStoreB = _makeSession(UserRole.cashier, empUserId1, storeId: storeB);
      final authServiceB = AuthorizationService.fromSession(sessionStoreB);
      final serviceB = DashboardService(db: db, authorizationService: authServiceB);

      final summaryB = await serviceB.getEmployeeSummary();

      // Scoped to Store B: 1 sale in Store B, 1 product in Store B
      expect(summaryB.todayPersonalSalesCount, equals(1));
      expect(summaryB.lowStockProducts.first.name, equals('Ciment 50kg'));
      expect(summaryB.recentPersonalActivity, isEmpty); // No Store B activities logged
    });

    test('empty store datasets return safe zero and empty collection values', () async {
      final sessionEmpty = _makeSession(UserRole.owner, 'owner-empty', storeId: 'store-empty');
      final authServiceEmpty = AuthorizationService.fromSession(sessionEmpty);
      final serviceEmpty = DashboardService(db: db, authorizationService: authServiceEmpty);

      final summary = await serviceEmpty.getOwnerSummary();

      expect(summary.todayRevenue, equals(0.0));
      expect(summary.weeklyRevenue, equals(0.0));
      expect(summary.monthlyRevenue, equals(0.0));
      expect(summary.todaySalesCount, equals(0));
      expect(summary.paymentMethodBreakdown, isEmpty);
      expect(summary.productCount, equals(0));
      expect(summary.stockValuation, equals(0.0));
      expect(summary.lowStockCount, equals(0));
      expect(summary.lowStockProducts, isEmpty);
      expect(summary.outOfStockCount, equals(0));
      expect(summary.outstandingCustomerDebt, equals(0.0));
      expect(summary.unpaidDebtCount, equals(0));
      expect(summary.recentActivity, isEmpty);
    });

    test('unauthorized access attempts return empty summary safely', () async {
      final authServiceLoggedOut = AuthorizationService.fromSession(null);
      final serviceLoggedOut = DashboardService(db: db, authorizationService: authServiceLoggedOut);

      final ownerSummary = await serviceLoggedOut.getOwnerSummary();
      final empSummary = await serviceLoggedOut.getEmployeeSummary();

      expect(ownerSummary.todayRevenue, equals(0.0));
      expect(empSummary.todayPersonalSalesCount, equals(0));
    });
  });
}
