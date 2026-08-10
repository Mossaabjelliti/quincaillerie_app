import 'package:flutter/foundation.dart';
import 'package:quincaillerie_app/core/auth/authorization_service.dart';
import 'package:quincaillerie_app/core/auth/permission.dart';
import 'package:quincaillerie_app/core/dashboard/dashboard_data.dart';
import 'package:quincaillerie_app/services/dashboard_service.dart';

/// Reactive state management provider for Stocki dashboard summaries.
///
/// Listens to [AuthorizationService] changes to refresh metrics automatically
/// when active store, role, or authentication session context changes.
class DashboardProvider extends ChangeNotifier {
  final DashboardService dashboardService;
  final AuthorizationService authorizationService;

  bool _isLoading = false;
  String? _error;
  OwnerDashboardSummary _ownerSummary = OwnerDashboardSummary.empty;
  EmployeeDashboardSummary _employeeSummary = EmployeeDashboardSummary.empty;
  String? _lastStoreId;

  DashboardProvider({
    required this.dashboardService,
    required this.authorizationService,
  }) {
    authorizationService.addListener(_onAuthzChanged);
    _lastStoreId = authorizationService.session?.currentStoreId;
    refresh();
  }

  bool get isLoading => _isLoading;
  String? get error => _error;
  OwnerDashboardSummary get ownerSummary => _ownerSummary;
  EmployeeDashboardSummary get employeeSummary => _employeeSummary;

  void _onAuthzChanged() {
    final currentStoreId = authorizationService.session?.currentStoreId;
    if (currentStoreId != _lastStoreId) {
      _lastStoreId = currentStoreId;
      refresh();
    }
  }

  /// Refreshes dashboard metrics based on current permission level and store context.
  Future<void> refresh() async {
    final session = authorizationService.session;
    if (session == null || session.currentStoreId == null || session.currentStoreId!.isEmpty) {
      _isLoading = false;
      _error = null;
      _ownerSummary = OwnerDashboardSummary.empty;
      _employeeSummary = EmployeeDashboardSummary.empty;
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (authorizationService.can(Permission.reportsFinancial)) {
        _ownerSummary = await dashboardService.getOwnerSummary();
        _employeeSummary = EmployeeDashboardSummary.empty;
      } else {
        _ownerSummary = OwnerDashboardSummary.empty;
        _employeeSummary = await dashboardService.getEmployeeSummary();
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    authorizationService.removeListener(_onAuthzChanged);
    super.dispose();
  }
}
