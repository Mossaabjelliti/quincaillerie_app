import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:drift/drift.dart' as drift;
import '../../data/local/database.dart';

/// All numbers here are computed from the LOCAL database. Nothing on this
/// screen requires internet — a quincaillier should be able to check
/// "how much did I make this month" at any time, sync or no sync.
class DashboardScreen extends StatelessWidget {
  final String storeId;

  const DashboardScreen({super.key, required this.storeId});

  @override
  Widget build(BuildContext context) {
    final db = context.read<AppDatabase>();
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);

    return Scaffold(
      appBar: AppBar(title: const Text('Tableau de bord')),
      body: FutureBuilder<_MonthlyStats>(
        future: _computeMonthlyStats(db, storeId, startOfMonth),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final stats = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _StatCard(
                label: 'Chiffre d\'affaires (ce mois)',
                value: '${stats.revenue.toStringAsFixed(2)} DT',
                color: Colors.green,
              ),
              _StatCard(
                label: 'Argent sorti (achats/réappro)',
                value: '${stats.purchases.toStringAsFixed(2)} DT',
                color: Colors.red,
              ),
              _StatCard(
                label: 'Marge brute estimée',
                value: '${(stats.revenue - stats.purchases).toStringAsFixed(2)} DT',
                color: Colors.blue,
              ),
              _StatCard(
                label: 'Produits en stock bas',
                value: '${stats.lowStockCount}',
                color: Colors.orange,
              ),
            ],
          );
        },
      ),
    );
  }

  Future<_MonthlyStats> _computeMonthlyStats(
      AppDatabase db, String storeId, DateTime since) async {
    final salesQuery = db.select(db.sales)
      ..where((s) => s.storeId.equals(storeId) & s.createdAt.isBiggerOrEqualValue(since));
    final salesRows = await salesQuery.get();
    final revenue = salesRows.fold<double>(0, (sum, s) => sum + s.total);

    final movementsQuery = db.select(db.stockMovements)
      ..where((m) =>
          m.storeId.equals(storeId) &
          m.type.equalsValue(MovementType.stockIn) &
          m.createdAt.isBiggerOrEqualValue(since));
    final inMovements = await movementsQuery.get();

    // Purchases estimated via buy price at time of entry - joined against
    // current product price for MVP simplicity; refine with price history later.
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
  _MonthlyStats({required this.revenue, required this.purchases, required this.lowStockCount});
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 15)),
            Text(value,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}
