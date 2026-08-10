import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:drift/native.dart';
import 'package:quincaillerie_app/data/local/database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('Dashboard Aggregate Database Queries Tests', () {
    const storeId = 'store-test-1';
    const userId1 = 'user-emp-1';
    const userId2 = 'user-emp-2';

    test('calculates sales summary metrics correctly', () async {
      final now = DateTime.now();

      await db.into(db.sales).insert(
            SalesCompanion.insert(
              id: 'sale-1',
              storeId: storeId,
              userId: userId1,
              total: 150.0,
              paymentMethod: PaymentMethod.cash,
              createdAt: Value(now),
            ),
          );

      await db.into(db.sales).insert(
            SalesCompanion.insert(
              id: 'sale-2',
              storeId: storeId,
              userId: userId2,
              total: 250.0,
              paymentMethod: PaymentMethod.credit,
              createdAt: Value(now),
            ),
          );

      final todayRev = await db.getTodaySalesRevenue(storeId);
      final weeklyRev = await db.getWeeklySalesRevenue(storeId);
      final monthlyRev = await db.getMonthlySalesRevenue(storeId);
      final count = await db.getSalesTransactionCount(storeId);
      final breakdown = await db.getPaymentMethodBreakdown(storeId);
      final user1Count = await db.getEmployeeSalesCount(storeId, userId1);
      final user2Count = await db.getEmployeeSalesCount(storeId, userId2);

      expect(todayRev, equals(400.0));
      expect(weeklyRev, equals(400.0));
      expect(monthlyRev, equals(400.0));
      expect(count, equals(2));
      expect(breakdown[PaymentMethod.cash], equals(150.0));
      expect(breakdown[PaymentMethod.credit], equals(250.0));
      expect(user1Count, equals(1));
      expect(user2Count, equals(1));
    });

    test('calculates inventory product count, low stock, out of stock, and valuation correctly', () async {
      await db.into(db.products).insert(
            ProductsCompanion.insert(
              id: 'p-1',
              storeId: storeId,
              name: 'Marteau',
              barcode: '111',
              unit: ProductUnit.piece,
              buyPrice: const Value(10.0),
              sellPrice: const Value(15.0),
              quantity: const Value(20.0),
              lowStockThreshold: const Value(5.0),
            ),
          );

      await db.into(db.products).insert(
            ProductsCompanion.insert(
              id: 'p-2',
              storeId: storeId,
              name: 'Vis 4x40',
              barcode: '222',
              unit: ProductUnit.piece,
              buyPrice: const Value(2.0),
              sellPrice: const Value(5.0),
              quantity: const Value(3.0), // Low stock
              lowStockThreshold: const Value(10.0),
            ),
          );

      await db.into(db.products).insert(
            ProductsCompanion.insert(
              id: 'p-3',
              storeId: storeId,
              name: 'Peinture',
              barcode: '333',
              unit: ProductUnit.liter,
              buyPrice: const Value(30.0),
              sellPrice: const Value(50.0),
              quantity: const Value(0.0), // Out of stock
              lowStockThreshold: const Value(2.0),
            ),
          );

      final totalProducts = await db.getProductCount(storeId);
      final valuation = await db.getStockValuation(storeId);
      final lowStockCount = await db.getLowStockCount(storeId);
      final outOfStockCount = await db.getOutOfStockCount(storeId);
      final lowStockList = await db.lowStockProducts(storeId);

      expect(totalProducts, equals(3));
      // Valuation = (20 * 15) + (3 * 5) + (0 * 50) = 300 + 15 + 0 = 315.0
      expect(valuation, equals(315.0));
      expect(lowStockCount, equals(2)); // p-2 (quantity 3 <= 10) and p-3 (quantity 0 <= 2)
      expect(outOfStockCount, equals(1)); // p-3
      expect(lowStockList, hasLength(2));
    });

    test('calculates customer debt totals and unpaid debt count correctly', () async {
      await db.into(db.customers).insert(
            CustomersCompanion.insert(
              id: 'cust-1',
              storeId: storeId,
              name: 'Client A',
            ),
          );

      await db.into(db.customerDebts).insert(
            CustomerDebtsCompanion.insert(
              id: 'debt-1',
              storeId: storeId,
              customerId: 'cust-1',
              totalAmount: 500.0,
              paidAmount: const Value(200.0),
              remainingAmount: 300.0,
            ),
          );

      await db.into(db.customerDebts).insert(
            CustomerDebtsCompanion.insert(
              id: 'debt-2',
              storeId: storeId,
              customerId: 'cust-1',
              totalAmount: 150.0,
              paidAmount: const Value(150.0),
              remainingAmount: 0.0, // Fully paid
            ),
          );

      final totalDebt = await db.getTotalOutstandingDebt(storeId);
      final unpaidCount = await db.getUnpaidDebtCount(storeId);

      expect(totalDebt, equals(300.0));
      expect(unpaidCount, equals(1));
    });

    test('filters store-wide and user-specific activity log queries', () async {
      final now = DateTime.now();

      await db.into(db.activityLogs).insert(
            ActivityLogsCompanion.insert(
              id: 'act-1',
              storeId: storeId,
              userId: userId1,
              action: 'PRODUCT_CREATED',
              entityType: 'product',
              entityId: 'p-1',
              timestamp: Value(now),
            ),
          );

      await db.into(db.activityLogs).insert(
            ActivityLogsCompanion.insert(
              id: 'act-2',
              storeId: storeId,
              userId: userId2,
              action: 'SALE_COMPLETED',
              entityType: 'sale',
              entityId: 's-1',
              timestamp: Value(now.add(const Duration(minutes: 5))),
            ),
          );

      final storeActivities = await db.getActivitiesForStore(storeId);
      final user1Activities = await db.getActivitiesForUser(storeId, userId1);
      final user2Activities = await db.getActivitiesForUser(storeId, userId2);

      expect(storeActivities, hasLength(2));
      expect(user1Activities, hasLength(1));
      expect(user1Activities.first.userId, equals(userId1));
      expect(user2Activities, hasLength(1));
      expect(user2Activities.first.userId, equals(userId2));
    });
  });
}
