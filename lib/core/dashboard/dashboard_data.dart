import 'package:flutter/foundation.dart';
import 'package:quincaillerie_app/data/local/database.dart';

/// Summary of a top-performing product by volume and revenue.
@immutable
class TopProductSummary {
  final String productId;
  final String productName;
  final double totalQuantitySold;
  final double totalRevenue;

  const TopProductSummary({
    required this.productId,
    required this.productName,
    this.totalQuantitySold = 0.0,
    this.totalRevenue = 0.0,
  });

  static const empty = TopProductSummary(
    productId: '',
    productName: '',
  );
}

/// Comprehensive dashboard summary for store owners and managers.
@immutable
class OwnerDashboardSummary {
  final double todayRevenue;
  final double weeklyRevenue;
  final double monthlyRevenue;
  final int todaySalesCount;
  final Map<PaymentMethod, double> paymentMethodBreakdown;
  final int productCount;
  final double stockValuation;
  final int lowStockCount;
  final List<Product> lowStockProducts;
  final int outOfStockCount;
  final double outstandingCustomerDebt;
  final int unpaidDebtCount;
  final List<TopProductSummary> topSellingProducts;
  final List<ActivityLog> recentActivity;

  const OwnerDashboardSummary({
    this.todayRevenue = 0.0,
    this.weeklyRevenue = 0.0,
    this.monthlyRevenue = 0.0,
    this.todaySalesCount = 0,
    this.paymentMethodBreakdown = const {},
    this.productCount = 0,
    this.stockValuation = 0.0,
    this.lowStockCount = 0,
    this.lowStockProducts = const [],
    this.outOfStockCount = 0,
    this.outstandingCustomerDebt = 0.0,
    this.unpaidDebtCount = 0,
    this.topSellingProducts = const [],
    this.recentActivity = const [],
  });

  static const empty = OwnerDashboardSummary();
}

/// Operational dashboard summary for cashiers and employees.
@immutable
class EmployeeDashboardSummary {
  final int todayPersonalSalesCount;
  final int lowStockCount;
  final List<Product> lowStockProducts;
  final List<ActivityLog> recentPersonalActivity;

  const EmployeeDashboardSummary({
    this.todayPersonalSalesCount = 0,
    this.lowStockCount = 0,
    this.lowStockProducts = const [],
    this.recentPersonalActivity = const [],
  });

  static const empty = EmployeeDashboardSummary();
}
