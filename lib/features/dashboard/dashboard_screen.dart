import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth/authorization_service.dart';
import '../../core/auth/permission.dart';
import '../../core/dashboard/dashboard_data.dart';
import 'dashboard_provider.dart';

/// Interactive Stocki Dashboard integrating Owner vs Employee view perspectives
/// powered by [DashboardProvider] and strictly guarded by [AuthorizationService].
class DashboardScreen extends StatelessWidget {
  final String storeId;

  const DashboardScreen({super.key, required this.storeId});

  @override
  Widget build(BuildContext context) {
    final authz = context.watch<AuthorizationService>();
    final dashboardProvider = context.watch<DashboardProvider>();
    final isOwnerOrManager = authz.can(Permission.reportsFinancial);

    return Scaffold(
      appBar: AppBar(
        title: Text(isOwnerOrManager ? 'Tableau de bord (Propriétaire)' : 'Tableau de bord (Employé)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => dashboardProvider.refresh(),
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => dashboardProvider.refresh(),
        child: _buildBody(context, dashboardProvider, isOwnerOrManager),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    DashboardProvider provider,
    bool isOwnerOrManager,
  ) {
    if (provider.isLoading &&
        provider.ownerSummary == OwnerDashboardSummary.empty &&
        provider.employeeSummary == EmployeeDashboardSummary.empty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 12),
              Text(
                'Erreur de chargement: ${provider.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => provider.refresh(),
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    if (isOwnerOrManager) {
      return _OwnerDashboardView(summary: provider.ownerSummary);
    } else {
      return _EmployeeDashboardView(summary: provider.employeeSummary);
    }
  }
}

class _OwnerDashboardView extends StatelessWidget {
  final OwnerDashboardSummary summary;

  const _OwnerDashboardView({required this.summary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Revenue & Today's Sales Banner
        Card(
          elevation: 0,
          color: theme.colorScheme.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Revenu du Jour',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${summary.todaySalesCount} Vente(s)',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '${summary.todayRevenue.toStringAsFixed(3)} TND',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Semaine: ${summary.weeklyRevenue.toStringAsFixed(3)} TND  |  Mois: ${summary.monthlyRevenue.toStringAsFixed(3)} TND',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Key Business Metrics Grid
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                icon: Icons.inventory_2_outlined,
                iconColor: Colors.blue.shade700,
                bgColor: Colors.blue.shade50,
                title: 'Valeur du Stock',
                value: '${summary.stockValuation.toStringAsFixed(3)} TND',
                subtitle: '${summary.productCount} Produits',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricTile(
                icon: Icons.account_balance_wallet_outlined,
                iconColor: Colors.purple.shade700,
                bgColor: Colors.purple.shade50,
                title: 'Créances Clients',
                value: '${summary.outstandingCustomerDebt.toStringAsFixed(3)} TND',
                subtitle: '${summary.unpaidDebtCount} Dette(s) impayée(s)',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _MetricTile(
                icon: Icons.warning_amber_rounded,
                iconColor: Colors.orange.shade800,
                bgColor: Colors.orange.shade50,
                title: 'Stock Bas',
                value: '${summary.lowStockCount} Produit(s)',
                subtitle: 'Réapprovisionnement',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricTile(
                icon: Icons.remove_shopping_cart_outlined,
                iconColor: Colors.red.shade700,
                bgColor: Colors.red.shade50,
                title: 'Ruptures de Stock',
                value: '${summary.outOfStockCount} Produit(s)',
                subtitle: 'Epuisé',
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Low Stock Items Preview
        if (summary.lowStockProducts.isNotEmpty) ...[
          Text(
            'Alertes de Stock Bas',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...summary.lowStockProducts.take(5).map(
                (p) => Card(
                  elevation: 0,
                  color: Colors.orange.shade50,
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: ListTile(
                    leading: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                    title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Quantité restante: ${p.quantity} (seuil: ${p.lowStockThreshold})'),
                    trailing: Text(
                      '${p.sellPrice.toStringAsFixed(3)} TND',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
          const SizedBox(height: 16),
        ],

        // Recent Business Activity Audit Trail
        Text(
          'Activité Récente de la Boutique',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (summary.recentActivity.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            child: Text('Aucune activité enregistrée pour le moment.'),
          )
        else
          ...summary.recentActivity.take(8).map(
                (act) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    child: Icon(Icons.history, size: 20),
                  ),
                  title: Text(
                    act.action,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text('${act.entityType} • ${act.timestamp.toString().split('.').first}'),
                ),
              ),
      ],
    );
  }
}

class _EmployeeDashboardView extends StatelessWidget {
  final EmployeeDashboardSummary summary;

  const _EmployeeDashboardView({required this.summary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Personal Sales Summary Banner
        Card(
          elevation: 0,
          color: theme.colorScheme.secondaryContainer,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Activité Personnelle',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '${summary.todayPersonalSalesCount} Vente(s)',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Réalisées par vous aujourd\'hui',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Operational Quick Actions Grid
        Text(
          'Actions Rapides',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _QuickActionButton(
                icon: Icons.shopping_cart_outlined,
                label: 'Nouvelle Vente',
                color: Colors.green,
                onTap: () {
                  Navigator.of(context).pushNamed('/cart');
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionButton(
                icon: Icons.qr_code_scanner,
                label: 'Scanner',
                color: Colors.blue,
                onTap: () {
                  Navigator.of(context).pushNamed('/add-product');
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Low Stock Alert Awareness
        Card(
          elevation: 0,
          color: summary.lowStockCount > 0 ? Colors.orange.shade50 : Colors.grey.shade100,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: summary.lowStockCount > 0 ? Colors.orange.shade200 : Colors.transparent,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: summary.lowStockCount > 0 ? Colors.orange.shade100 : Colors.grey.shade200,
                  child: Icon(
                    Icons.warning_amber_rounded,
                    color: summary.lowStockCount > 0 ? Colors.orange.shade900 : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${summary.lowStockCount} Produit(s) en stock bas',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: summary.lowStockCount > 0 ? Colors.orange.shade900 : theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        summary.lowStockCount > 0 ? 'Signaler le réapprovisionnement' : 'Stock suffisant',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Own Activity Stream
        Text(
          'Vos Dernières Actions',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (summary.recentPersonalActivity.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            child: Text('Aucune action récente enregistrée.'),
          )
        else
          ...summary.recentPersonalActivity.map(
                (act) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    child: Icon(Icons.history, size: 20),
                  ),
                  title: Text(act.action, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('${act.entityType} • ${act.timestamp.toString().split('.').first}'),
                ),
              ),
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 12.0),
          child: Column(
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final String title;
  final String value;
  final String subtitle;

  const _MetricTile({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.title,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: bgColor,
              child: Icon(icon, color: iconColor),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
