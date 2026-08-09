/// Centralized permission identifiers for Stocki RBAC.
enum Permission {
  inventoryView('inventory.view'),
  inventoryCreate('inventory.create'),
  inventoryUpdate('inventory.update'),
  inventoryDelete('inventory.delete'),

  salesView('sales.view'),
  salesCreate('sales.create'),
  salesCancel('sales.cancel'),

  customersView('customers.view'),
  customersManage('customers.manage'),

  suppliersView('suppliers.view'),
  suppliersManage('suppliers.manage'),

  invoicesView('invoices.view'),
  invoicesCreate('invoices.create'),
  invoicesManage('invoices.manage'),

  reportsFinancial('reports.financial'),
  reportsAnalytics('reports.analytics'),

  employeesView('employees.view'),
  employeesManage('employees.manage'),

  settingsManage('settings.manage'),

  activityView('activity.view'),
  activityViewOwn('activity.view_own');

  const Permission(this.key);

  /// Stable wire key (e.g. `inventory.view`).
  final String key;

  static Permission? fromKey(String? value) {
    if (value == null || value.isEmpty) return null;
    for (final permission in Permission.values) {
      if (permission.key == value) return permission;
    }
    return null;
  }
}
