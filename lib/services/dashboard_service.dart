import 'package:quincaillerie_app/core/auth/authorization_service.dart';
import 'package:quincaillerie_app/core/auth/permission.dart';
import 'package:quincaillerie_app/core/dashboard/dashboard_data.dart';
import 'package:quincaillerie_app/data/local/database.dart';

/// Service responsible for compiling dashboard summaries for the active store and
/// user context with strict RBAC permission enforcement.
class DashboardService {
  final AppDatabase db;
  final AuthorizationService authorizationService;

  DashboardService({
    required this.db,
    required this.authorizationService,
  });

  /// Compiles the full [OwnerDashboardSummary] if authorized with [Permission.reportsFinancial].
  ///
  /// Returns [OwnerDashboardSummary.empty] safely if unauthenticated or unauthorized.
  Future<OwnerDashboardSummary> getOwnerSummary() async {
    final session = authorizationService.session;
    if (session == null || !authorizationService.can(Permission.reportsFinancial)) {
      return OwnerDashboardSummary.empty;
    }

    final storeId = session.currentStoreId;
    if (storeId == null || storeId.isEmpty) {
      return OwnerDashboardSummary.empty;
    }

    final results = await Future.wait([
      db.getTodaySalesRevenue(storeId),
      db.getWeeklySalesRevenue(storeId),
      db.getMonthlySalesRevenue(storeId),
      db.getSalesTransactionCount(storeId),
      db.getPaymentMethodBreakdown(storeId),
      db.getProductCount(storeId),
      db.getStockValuation(storeId),
      db.getLowStockCount(storeId),
      db.lowStockProducts(storeId),
      db.getOutOfStockCount(storeId),
      db.getTotalOutstandingDebt(storeId),
      db.getUnpaidDebtCount(storeId),
      authorizationService.can(Permission.activityView)
          ? db.getActivitiesForStore(storeId, limit: 20)
          : Future.value(<ActivityLog>[]),
    ]);

    return OwnerDashboardSummary(
      todayRevenue: results[0] as double,
      weeklyRevenue: results[1] as double,
      monthlyRevenue: results[2] as double,
      todaySalesCount: results[3] as int,
      paymentMethodBreakdown: results[4] as Map<PaymentMethod, double>,
      productCount: results[5] as int,
      stockValuation: results[6] as double,
      lowStockCount: results[7] as int,
      lowStockProducts: results[8] as List<Product>,
      outOfStockCount: results[9] as int,
      outstandingCustomerDebt: results[10] as double,
      unpaidDebtCount: results[11] as int,
      recentActivity: results[12] as List<ActivityLog>,
    );
  }

  /// Compiles the operational [EmployeeDashboardSummary] for employees.
  ///
  /// Returns [EmployeeDashboardSummary.empty] safely when unauthenticated.
  Future<EmployeeDashboardSummary> getEmployeeSummary() async {
    final session = authorizationService.session;
    if (session == null) {
      return EmployeeDashboardSummary.empty;
    }

    final storeId = session.currentStoreId;
    if (storeId == null || storeId.isEmpty) {
      return EmployeeDashboardSummary.empty;
    }
    final userId = session.userId;

    final results = await Future.wait([
      authorizationService.can(Permission.salesView)
          ? db.getEmployeeSalesCount(storeId, userId)
          : Future.value(0),
      authorizationService.can(Permission.inventoryView)
          ? db.getLowStockCount(storeId)
          : Future.value(0),
      authorizationService.can(Permission.inventoryView)
          ? db.lowStockProducts(storeId)
          : Future.value(<Product>[]),
      authorizationService.can(Permission.activityViewOwn)
          ? db.getActivitiesForUser(storeId, userId, limit: 15)
          : Future.value(<ActivityLog>[]),
    ]);

    return EmployeeDashboardSummary(
      todayPersonalSalesCount: results[0] as int,
      lowStockCount: results[1] as int,
      lowStockProducts: results[2] as List<Product>,
      recentPersonalActivity: results[3] as List<ActivityLog>,
    );
  }
}
