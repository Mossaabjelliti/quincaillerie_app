import 'package:flutter/material.dart';
import '../auth/authorization_service.dart';
import '../auth/permission.dart';
import '../licensing/entitlement.dart';
import '../../features/activity/activity_screen.dart';
import '../../features/admin/member_management_screen.dart';
import '../../features/customers/customer_debt_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/desktop/desktop_pos_screen.dart';
import '../../features/inventory/inventory_screen.dart';
import '../../features/navigation/more_menu_screen.dart';
import '../../features/sales/sales_screen.dart';
import '../../features/scan/scan_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/suppliers/supplier_management_screen.dart';
import 'route_guard.dart';

enum AppNavPlatform { mobile, desktop }

/// Build context passed to navigation destination screen builders.
class NavScreenContext {
  final String storeId;
  final String userId;
  final AuthorizationService authz;

  const NavScreenContext({
    required this.storeId,
    required this.userId,
    required this.authz,
  });

  bool get canManageStock => authz.can(Permission.inventoryUpdate);
  bool get canViewFinancials => authz.can(Permission.reportsFinancial);
}

typedef NavScreenBuilder = Widget Function(NavScreenContext context);

/// Declarative app navigation item gated by [Permission].
class AppNavDestination {
  final String id;
  final String label;
  final IconData icon;
  final Permission permission;
  final bool ownerNav;
  final bool employeeNav;
  final Set<AppNavPlatform> platforms;
  final Feature? licenseFeature;
  final NavScreenBuilder builder;

  const AppNavDestination({
    required this.id,
    required this.label,
    required this.icon,
    required this.permission,
    required this.ownerNav,
    required this.employeeNav,
    required this.platforms,
    required this.builder,
    this.licenseFeature,
  });

  bool supports(AppNavPlatform platform) => platforms.contains(platform);
}

/// Central registry for permission-aware Stocki navigation.
class AppNavigation {
  AppNavigation._();

  static bool usesOwnerNavigation(AuthorizationService authz) =>
      authz.can(Permission.settingsManage);

  static List<AppNavDestination> visibleDestinations(
    AuthorizationService authz, {
    required AppNavPlatform platform,
  }) {
    final ownerMode = usesOwnerNavigation(authz);
    return _destinations
        .where((destination) => destination.supports(platform))
        .where((destination) => ownerMode ? destination.ownerNav : destination.employeeNav)
        .where((destination) => authz.can(destination.permission))
        .toList(growable: false);
  }

  static int clampIndex(int index, int destinationCount) {
    if (destinationCount <= 0) return 0;
    return index.clamp(0, destinationCount - 1);
  }

  /// Builds a destination screen with route-level permission enforcement.
  static Widget buildDestination(
    AppNavDestination destination,
    NavScreenContext context,
  ) {
    final permission = RouteProtection.permissionForDestination(
      destination.id,
      destination.permission,
    );
    return RouteGuard.guardScreen(
      authz: context.authz,
      permission: permission,
      title: destination.label,
      child: destination.builder(context),
    );
  }

  static const List<AppNavDestination> _destinations = [
    // --- Mobile & Desktop Primary Destinations ---
    AppNavDestination(
      id: 'dashboard',
      label: 'Tableau de bord',
      icon: Icons.dashboard_outlined,
      permission: Permission.reportsFinancial,
      ownerNav: true,
      employeeNav: false,
      platforms: {AppNavPlatform.mobile, AppNavPlatform.desktop},
      licenseFeature: Feature.dashboard,
      builder: _dashboardScreen,
    ),
    AppNavDestination(
      id: 'pos',
      label: 'POS',
      icon: Icons.point_of_sale_outlined,
      permission: Permission.salesCreate,
      ownerNav: true,
      employeeNav: true,
      platforms: {AppNavPlatform.desktop},
      licenseFeature: Feature.pos,
      builder: _posScreen,
    ),
    AppNavDestination(
      id: 'sales',
      label: 'Ventes',
      icon: Icons.receipt_long_outlined,
      permission: Permission.salesView,
      ownerNav: true,
      employeeNav: true,
      platforms: {AppNavPlatform.mobile, AppNavPlatform.desktop},
      licenseFeature: Feature.sales,
      builder: _salesScreen,
    ),
    AppNavDestination(
      id: 'scanner',
      label: 'Scanner',
      icon: Icons.qr_code_scanner,
      permission: Permission.salesCreate,
      ownerNav: true,
      employeeNav: true,
      platforms: {AppNavPlatform.mobile},
      licenseFeature: Feature.pos,
      builder: _scannerScreen,
    ),
    AppNavDestination(
      id: 'inventory',
      label: 'Stock',
      icon: Icons.inventory_2_outlined,
      permission: Permission.inventoryView,
      ownerNav: true,
      employeeNav: true,
      platforms: {AppNavPlatform.mobile, AppNavPlatform.desktop},
      licenseFeature: Feature.inventory,
      builder: _inventoryScreen,
    ),
    AppNavDestination(
      id: 'customers',
      label: 'Clients',
      icon: Icons.people_outline,
      permission: Permission.customersView,
      ownerNav: false,
      employeeNav: true,
      platforms: {AppNavPlatform.mobile},
      licenseFeature: Feature.customers,
      builder: _customersScreen,
    ),
    AppNavDestination(
      id: 'customers',
      label: 'Clients',
      icon: Icons.people_outline,
      permission: Permission.customersView,
      ownerNav: true,
      employeeNav: true,
      platforms: {AppNavPlatform.desktop},
      licenseFeature: Feature.customers,
      builder: _customersScreen,
    ),
    AppNavDestination(
      id: 'suppliers',
      label: 'Fournisseurs',
      icon: Icons.local_shipping_outlined,
      permission: Permission.suppliersView,
      ownerNav: true,
      employeeNav: false,
      platforms: {AppNavPlatform.desktop},
      licenseFeature: Feature.suppliers,
      builder: _suppliersScreen,
    ),
    AppNavDestination(
      id: 'employees',
      label: 'Employés',
      icon: Icons.group_outlined,
      permission: Permission.employeesView,
      ownerNav: true,
      employeeNav: false,
      platforms: {AppNavPlatform.desktop},
      licenseFeature: Feature.settings,
      builder: _employeesScreen,
    ),
    AppNavDestination(
      id: 'activity',
      label: 'Activité',
      icon: Icons.history,
      permission: Permission.activityView,
      ownerNav: true,
      employeeNav: false,
      platforms: {AppNavPlatform.desktop},
      builder: _activityOwnerScreen,
    ),
    AppNavDestination(
      id: 'my_activity',
      label: 'Mon activité',
      icon: Icons.history_toggle_off,
      permission: Permission.activityViewOwn,
      ownerNav: false,
      employeeNav: true,
      platforms: {AppNavPlatform.desktop},
      builder: _activityEmployeeScreen,
    ),
    AppNavDestination(
      id: 'settings',
      label: 'Paramètres',
      icon: Icons.settings_outlined,
      permission: Permission.salesView,
      ownerNav: true,
      employeeNav: true,
      platforms: {AppNavPlatform.desktop},
      licenseFeature: Feature.settings,
      builder: _settingsScreen,
    ),
    AppNavDestination(
      id: 'more',
      label: 'Plus',
      icon: Icons.more_horiz_rounded,
      permission: Permission.salesView,
      ownerNav: true,
      employeeNav: true,
      platforms: {AppNavPlatform.mobile},
      builder: _moreMenuScreen,
    ),

    // --- Unfinished Features (Hidden from primary navigation; architecture/routes preserved) ---
    AppNavDestination(
      id: 'invoices',
      label: 'Factures',
      icon: Icons.description_outlined,
      permission: Permission.invoicesView,
      ownerNav: false,
      employeeNav: false,
      platforms: {AppNavPlatform.mobile, AppNavPlatform.desktop},
      builder: _invoicesPlaceholder,
    ),
    AppNavDestination(
      id: 'finance',
      label: 'Finance',
      icon: Icons.account_balance_wallet_outlined,
      permission: Permission.reportsFinancial,
      ownerNav: false,
      employeeNav: false,
      platforms: {AppNavPlatform.mobile, AppNavPlatform.desktop},
      licenseFeature: Feature.reports,
      builder: _financePlaceholder,
    ),
    AppNavDestination(
      id: 'analytics',
      label: 'Analytique',
      icon: Icons.bar_chart_outlined,
      permission: Permission.reportsAnalytics,
      ownerNav: false,
      employeeNav: false,
      platforms: {AppNavPlatform.mobile, AppNavPlatform.desktop},
      licenseFeature: Feature.reports,
      builder: _analyticsPlaceholder,
    ),
  ];

  static Widget _dashboardScreen(NavScreenContext ctx) =>
      DashboardScreen(storeId: ctx.storeId);

  static Widget _inventoryScreen(NavScreenContext ctx) => InventoryScreen(
        storeId: ctx.storeId,
        canManageStock: ctx.canManageStock,
      );

  static Widget _scannerScreen(NavScreenContext ctx) => ScanScreen(
        storeId: ctx.storeId,
        userId: ctx.userId,
        canManageStock: ctx.canManageStock,
      );

  static Widget _posScreen(NavScreenContext ctx) => DesktopPosScreen(
        storeId: ctx.storeId,
        userId: ctx.userId,
      );

  static Widget _salesScreen(NavScreenContext ctx) => SalesScreen(
        storeId: ctx.storeId,
        canViewFinancials: ctx.canViewFinancials,
      );

  static Widget _customersScreen(NavScreenContext ctx) => const CustomerDebtScreen();

  static Widget _suppliersScreen(NavScreenContext ctx) => const SupplierManagementScreen();

  static Widget _employeesScreen(NavScreenContext ctx) => const MemberManagementScreen();

  static Widget _activityOwnerScreen(NavScreenContext ctx) => ActivityScreen(
        storeId: ctx.storeId,
        userId: ctx.userId,
        isOwnerView: true,
      );

  static Widget _activityEmployeeScreen(NavScreenContext ctx) => ActivityScreen(
        storeId: ctx.storeId,
        userId: ctx.userId,
        isOwnerView: false,
      );

  static Widget _settingsScreen(NavScreenContext ctx) => const SettingsScreen();

  static Widget _moreMenuScreen(NavScreenContext ctx) => MoreMenuScreen(
        storeId: ctx.storeId,
        userId: ctx.userId,
      );

  static Widget _invoicesPlaceholder(NavScreenContext ctx) =>
      const NavPlaceholderScreen(title: 'Factures', icon: Icons.description_outlined);

  static Widget _financePlaceholder(NavScreenContext ctx) =>
      const NavPlaceholderScreen(title: 'Finance', icon: Icons.account_balance_wallet_outlined);

  static Widget _analyticsPlaceholder(NavScreenContext ctx) =>
      const NavPlaceholderScreen(title: 'Analytique', icon: Icons.bar_chart_outlined);
}

class NavPlaceholderScreen extends StatelessWidget {
  final String title;
  final IconData icon;

  const NavPlaceholderScreen({
    super.key,
    required this.title,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text('$title bientôt disponible'),
        ],
      ),
    );
  }
}
