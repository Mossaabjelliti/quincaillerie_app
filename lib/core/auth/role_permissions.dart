import 'permission.dart';
import 'user_role.dart';

/// Maps [UserRole] values to granted [Permission]s.
class RolePermissions {
  RolePermissions._();

  static const Set<Permission> all = {
    Permission.inventoryView,
    Permission.inventoryCreate,
    Permission.inventoryUpdate,
    Permission.inventoryDelete,
    Permission.salesView,
    Permission.salesCreate,
    Permission.salesCancel,
    Permission.customersView,
    Permission.customersManage,
    Permission.suppliersView,
    Permission.suppliersManage,
    Permission.invoicesView,
    Permission.invoicesCreate,
    Permission.invoicesManage,
    Permission.reportsFinancial,
    Permission.reportsAnalytics,
    Permission.employeesView,
    Permission.employeesManage,
    Permission.settingsManage,
    Permission.activityView,
    Permission.activityViewOwn,
  };

  /// Day-to-day store operations without sensitive admin/finance access.
  static const Set<Permission> employeeOperational = {
    Permission.inventoryView,
    Permission.salesView,
    Permission.salesCreate,
    Permission.salesCancel,
    Permission.customersView,
    Permission.customersManage,
    Permission.suppliersView,
    Permission.suppliersManage,
    Permission.invoicesView,
    Permission.invoicesCreate,
    Permission.activityViewOwn,
  };

  static const Set<Permission> _cashier = {
    Permission.inventoryView,
    Permission.salesView,
    Permission.salesCreate,
    Permission.salesCancel,
    Permission.activityViewOwn,
  };

  static const Set<Permission> _stockManager = {
    Permission.inventoryView,
    Permission.inventoryCreate,
    Permission.inventoryUpdate,
    Permission.inventoryDelete,
    Permission.salesCreate,
    Permission.suppliersView,
    Permission.suppliersManage,
    Permission.activityViewOwn,
  };

  static const Set<Permission> _accountant = {
    Permission.salesView,
    Permission.customersView,
    Permission.suppliersView,
    Permission.invoicesView,
    Permission.invoicesCreate,
    Permission.invoicesManage,
    Permission.reportsFinancial,
    Permission.reportsAnalytics,
    Permission.activityView,
  };

  static Set<Permission> forRole(UserRole role) => switch (role) {
        UserRole.owner => all,
        UserRole.manager => all,
        UserRole.employee => employeeOperational,
        UserRole.cashier => _cashier,
        UserRole.stockManager => _stockManager,
        UserRole.accountant => _accountant,
      };

  static bool has(UserRole role, Permission permission) =>
      forRole(role).contains(permission);

  static bool hasAny(UserRole role, Iterable<Permission> permissions) =>
      permissions.any((permission) => has(role, permission));

  static bool hasAll(UserRole role, Iterable<Permission> permissions) =>
      permissions.every((permission) => has(role, permission));
}
