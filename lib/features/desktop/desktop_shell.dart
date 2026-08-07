import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/licensing/entitlement.dart';
import '../../core/licensing/license_service.dart';
import '../../core/licensing/license_state.dart';
import '../../features/cart/cart_screen.dart';
import '../../features/desktop/desktop_pos_screen.dart';
import '../../features/customers/customer_debt_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/inventory/inventory_screen.dart';
import '../../features/sales/sales_screen.dart';
import '../../features/suppliers/supplier_management_screen.dart';
import '../../services/sync_service.dart';

class DesktopShell extends StatefulWidget {
  final String storeId;
  final String userId;
  const DesktopShell({super.key, required this.storeId, required this.userId});
  @override State<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends State<DesktopShell> {
  int _index = 0;
  static const _items = <({String label, IconData icon, Feature feature})>[
    (label: 'Dashboard', icon: Icons.dashboard_outlined, feature: Feature.dashboard),
    (label: 'POS', icon: Icons.point_of_sale_outlined, feature: Feature.pos),
    (label: 'Inventaire', icon: Icons.inventory_2_outlined, feature: Feature.inventory),
    (label: 'Ventes', icon: Icons.receipt_long_outlined, feature: Feature.sales),
    (label: 'Clients', icon: Icons.people_outline, feature: Feature.customers),
    (label: 'Fournisseurs', icon: Icons.local_shipping_outlined, feature: Feature.suppliers),
    (label: 'Rapports', icon: Icons.bar_chart_outlined, feature: Feature.reports),
    (label: 'Paramètres', icon: Icons.settings_outlined, feature: Feature.settings),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final license = context.watch<LicenseService>().state;
    final canManageStock = auth.session?.canManageStock ?? false;
    final canViewFinancials = auth.session?.canViewFinancials ?? false;
    final screens = <Widget>[
      DashboardScreen(storeId: widget.storeId),
      DesktopPosScreen(storeId: widget.storeId, userId: widget.userId),
      InventoryScreen(storeId: widget.storeId, canManageStock: canManageStock),
      SalesScreen(storeId: widget.storeId, canViewFinancials: canViewFinancials),
      const CustomerDebtScreen(), const SupplierManagementScreen(),
      const _DesktopPlaceholder(title: 'Rapports', icon: Icons.bar_chart_outlined),
      const _DesktopPlaceholder(title: 'Paramètres', icon: Icons.settings_outlined),
    ];
    final enabled = license.entitlements.canUse(_items[_index].feature);
    return Shortcuts(
      shortcuts: const {SingleActivator(LogicalKeyboardKey.escape): _DismissIntent()},
      child: Actions(
        actions: {_DismissIntent: CallbackAction<_DismissIntent>(onInvoke: (_) { Navigator.of(context).maybePop(); return null; })},
        child: Focus(
          autofocus: true,
          child: Scaffold(
            body: Row(children: [
              NavigationRail(
                selectedIndex: _index,
                extended: true,
                minExtendedWidth: 210,
                leading: Padding(padding: const EdgeInsets.all(16), child: Text('QUINCAILLERIE', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold))),
                destinations: [for (final item in _items) NavigationRailDestination(icon: Icon(item.icon), label: Text(item.label))],
                onDestinationSelected: (index) => setState(() => _index = index),
              ),
              const VerticalDivider(width: 1),
              Expanded(child: Column(children: [
                _DesktopTopBar(storeName: auth.session?.currentStoreName ?? 'Quincaillerie', storeId: widget.storeId, license: license),
                if (license.shouldShowRenewalWarning) const MaterialBanner(content: Text('Abonnement expiré : fonctionnement hors-ligne temporairement autorisé.'), actions: [SizedBox()]),
                Expanded(child: enabled ? screens[_index] : const _RestrictedMode()),
              ])),
            ]),
          ),
        ),
      ),
    );
  }
}

class _DesktopTopBar extends StatelessWidget {
  final String storeName; final String storeId; final LicenseState license;
  const _DesktopTopBar({required this.storeName, required this.storeId, required this.license});
  @override Widget build(BuildContext context) => Material(
    child: SizedBox(height: 64, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: Row(children: [
      Text(storeName, style: Theme.of(context).textTheme.titleLarge), const Spacer(),
      Chip(avatar: Icon(license.mode.name == 'active' ? Icons.verified_outlined : Icons.offline_bolt_outlined, size: 16), label: Text(license.mode.name == 'active' ? 'Licence active' : 'Mode hors ligne')),
      const SizedBox(width: 12), Consumer<SyncService>(builder: (_, sync, __) => OutlinedButton.icon(onPressed: () async { await sync.syncNow(storeId: storeId); }, icon: const Icon(Icons.sync, size: 18), label: Text(switch (sync.status) { SyncStatus.syncing => 'Synchronisation…', SyncStatus.offline => 'Hors ligne', _ => 'Synchroniser' }))),
    ]))),
  );
}

class _RestrictedMode extends StatelessWidget { const _RestrictedMode(); @override Widget build(BuildContext context) => const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.lock_outline, size: 48), SizedBox(height: 12), Text('Mode restreint'), Text('Les données restent consultables. Renouvelez la licence pour créer de nouvelles opérations.')])); }
class _DesktopPlaceholder extends StatelessWidget { final String title; final IconData icon; const _DesktopPlaceholder({required this.title, required this.icon}); @override Widget build(BuildContext context) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 48), const SizedBox(height: 12), Text('$title bientôt disponible')])); }
class _DismissIntent extends Intent { const _DismissIntent(); }
