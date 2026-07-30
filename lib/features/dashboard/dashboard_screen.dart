import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:drift/drift.dart' hide Column;
import '../../data/local/database.dart';

/// Offline dashboard computing revenue, purchases, profit margin,
/// and low-stock alerts directly from local SQLite.
class DashboardScreen extends StatelessWidget {
  final String storeId;

  const DashboardScreen({super.key, required this.storeId});

  @override
  Widget build(BuildContext context) {
    final db = context.read<AppDatabase>();
    final theme = Theme.of(context);
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);

    final monthNames = [
      'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
      'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
    ];
    final currentMonthName = monthNames[now.month - 1];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tableau de bord'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.calendar_today_outlined, size: 14, color: Colors.blue),
                const SizedBox(width: 6),
                Text(
                  '$currentMonthName ${now.year}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: FutureBuilder<_MonthlyStats>(
        future: _computeMonthlyStats(db, storeId, startOfMonth),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final stats = snapshot.data ??
              _MonthlyStats(revenue: 0, purchases: 0, lowStockCount: 0);

          final margin = stats.revenue - stats.purchases;

          return RefreshIndicator(
            onRefresh: () async {
              // Trigger rebuild
              (context as Element).markNeedsBuild();
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Welcome Banner Card
                Card(
                  elevation: 0,
                  color: theme.colorScheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Activité Mensuelle',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.wifi_off, size: 14, color: Colors.white),
                                  SizedBox(width: 4),
                                  Text(
                                    'Mode Hors-ligne',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${stats.revenue.toStringAsFixed(3)} TND',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Chiffre d\'affaires du mois',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Stat Cards Grid
                Row(
                  children: [
                    Expanded(
                      child: _MetricTile(
                        icon: Icons.trending_up,
                        iconColor: Colors.green.shade700,
                        bgColor: Colors.green.shade50,
                        title: 'Marge estimée',
                        value: '${margin.toStringAsFixed(3)} TND',
                        subtitle: 'CA minus Achats',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MetricTile(
                        icon: Icons.shopping_bag_outlined,
                        iconColor: Colors.blue.shade700,
                        bgColor: Colors.blue.shade50,
                        title: 'Achats stock',
                        value: '${stats.purchases.toStringAsFixed(3)} TND',
                        subtitle: 'Réapprovisionnement',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Low Stock Warning Banner
                Card(
                  elevation: 0,
                  color: stats.lowStockCount > 0
                      ? Colors.orange.shade50
                      : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: stats.lowStockCount > 0
                          ? Colors.orange.shade200
                          : Colors.transparent,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: stats.lowStockCount > 0
                              ? Colors.orange.shade100
                              : Colors.grey.shade200,
                          child: Icon(
                            Icons.warning_amber_rounded,
                            color: stats.lowStockCount > 0
                                ? Colors.orange.shade900
                                : Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${stats.lowStockCount} Produit(s) en stock bas',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: stats.lowStockCount > 0
                                      ? Colors.orange.shade900
                                      : theme.colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                stats.lowStockCount > 0
                                    ? 'Réapprovisionnement recommandé'
                                    : 'Tous les stocks sont suffisants',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<_MonthlyStats> _computeMonthlyStats(
      AppDatabase db, String storeId, DateTime since) async {
    final salesQuery = db.select(db.sales)
      ..where((s) => (s.storeId.equals(storeId)) & (s.createdAt.isBiggerOrEqualValue(since)));
    final salesRows = await salesQuery.get();
    final revenue = salesRows.fold<double>(0, (sum, s) => sum + s.total);

    final movementsQuery = db.select(db.stockMovements)
      ..where((m) =>
          (m.storeId.equals(storeId)) &
          (m.type.equalsValue(MovementType.stockIn)) &
          (m.createdAt.isBiggerOrEqualValue(since)));
    final inMovements = await movementsQuery.get();

    double purchases = 0;
    for (final m in inMovements) {
      final product = await (db.select(db.products)..where((p) => p.id.equals(m.productId)))
          .getSingleOrNull();
      if (product != null) purchases += product.buyPrice * m.quantity;
    }

    final lowStock = await db.lowStockProducts(storeId);

    return _MonthlyStats(
      revenue: revenue,
      purchases: purchases,
      lowStockCount: lowStock.length,
    );
  }
}

class _MonthlyStats {
  final double revenue;
  final double purchases;
  final int lowStockCount;

  _MonthlyStats({
    required this.revenue,
    required this.purchases,
    required this.lowStockCount,
  });
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
