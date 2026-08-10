import 'package:flutter_test/flutter_test.dart';
import 'package:quincaillerie_app/core/dashboard/dashboard_data.dart';
import 'package:quincaillerie_app/data/local/database.dart';

void main() {
  group('Dashboard Data Models Tests', () {
    test('TopProductSummary default and empty values behave correctly', () {
      const emptyTop = TopProductSummary.empty;
      expect(emptyTop.productId, isEmpty);
      expect(emptyTop.productName, isEmpty);
      expect(emptyTop.totalQuantitySold, equals(0.0));
      expect(emptyTop.totalRevenue, equals(0.0));

      const customTop = TopProductSummary(
        productId: 'p-10',
        productName: 'Ciment',
        totalQuantitySold: 50.0,
        totalRevenue: 750.0,
      );
      expect(customTop.productId, equals('p-10'));
      expect(customTop.productName, equals('Ciment'));
      expect(customTop.totalQuantitySold, equals(50.0));
      expect(customTop.totalRevenue, equals(750.0));
    });

    test('OwnerDashboardSummary default empty instance handles zero values safely', () {
      const summary = OwnerDashboardSummary.empty;

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
      expect(summary.topSellingProducts, isEmpty);
      expect(summary.recentActivity, isEmpty);
    });

    test('OwnerDashboardSummary initializes custom properties correctly', () {
      final summary = OwnerDashboardSummary(
        todayRevenue: 1250.0,
        weeklyRevenue: 8500.0,
        monthlyRevenue: 34000.0,
        todaySalesCount: 15,
        paymentMethodBreakdown: const {
          PaymentMethod.cash: 800.0,
          PaymentMethod.credit: 450.0,
        },
        productCount: 120,
        stockValuation: 45000.0,
        lowStockCount: 4,
        outOfStockCount: 1,
        outstandingCustomerDebt: 1200.0,
        unpaidDebtCount: 3,
      );

      expect(summary.todayRevenue, equals(1250.0));
      expect(summary.weeklyRevenue, equals(8500.0));
      expect(summary.monthlyRevenue, equals(34000.0));
      expect(summary.todaySalesCount, equals(15));
      expect(summary.paymentMethodBreakdown[PaymentMethod.cash], equals(800.0));
      expect(summary.productCount, equals(120));
      expect(summary.stockValuation, equals(45000.0));
      expect(summary.lowStockCount, equals(4));
      expect(summary.outOfStockCount, equals(1));
      expect(summary.outstandingCustomerDebt, equals(1200.0));
      expect(summary.unpaidDebtCount, equals(3));
    });

    test('EmployeeDashboardSummary default empty instance handles zero values safely', () {
      const summary = EmployeeDashboardSummary.empty;

      expect(summary.todayPersonalSalesCount, equals(0));
      expect(summary.lowStockCount, equals(0));
      expect(summary.lowStockProducts, isEmpty);
      expect(summary.recentPersonalActivity, isEmpty);
    });

    test('EmployeeDashboardSummary initializes custom properties correctly', () {
      const summary = EmployeeDashboardSummary(
        todayPersonalSalesCount: 8,
        lowStockCount: 3,
      );

      expect(summary.todayPersonalSalesCount, equals(8));
      expect(summary.lowStockCount, equals(3));
      expect(summary.lowStockProducts, isEmpty);
      expect(summary.recentPersonalActivity, isEmpty);
    });
  });
}
