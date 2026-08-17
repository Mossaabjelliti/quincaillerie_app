import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' hide Column;
import '../../data/local/database.dart';

/// Screen displaying store-wide activity (Owner) or personal activity (Employee).
class ActivityScreen extends StatefulWidget {
  final String storeId;
  final String userId;
  final bool isOwnerView;

  const ActivityScreen({
    super.key,
    required this.storeId,
    required this.userId,
    required this.isOwnerView,
  });

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  IconData _iconForEntityType(String entityType) => switch (entityType.toLowerCase()) {
        'sale' => Icons.point_of_sale_outlined,
        'product' => Icons.inventory_2_outlined,
        'purchase' => Icons.local_shipping_outlined,
        'customer' => Icons.people_outline,
        'member' => Icons.badge_outlined,
        'sync' => Icons.sync,
        _ => Icons.history,
      };

  Color _colorForEntityType(String entityType) => switch (entityType.toLowerCase()) {
        'sale' => Colors.green,
        'product' => Colors.blue,
        'purchase' => Colors.orange,
        'customer' => Colors.purple,
        'member' => Colors.amber.shade800,
        _ => Colors.blueGrey,
      };

  @override
  Widget build(BuildContext context) {
    final db = context.watch<AppDatabase>();
    final theme = Theme.of(context);
    final title = widget.isOwnerView ? 'Activité du Magasin' : 'Mon Activité';

    final stream = widget.isOwnerView
        ? (db.select(db.activityLogs)
              ..where((a) => a.storeId.equals(widget.storeId))
              ..orderBy([(a) => OrderingTerm.desc(a.timestamp)])
              ..limit(100))
            .watch()
        : (db.select(db.activityLogs)
              ..where((a) => a.storeId.equals(widget.storeId) & a.userId.equals(widget.userId))
              ..orderBy([(a) => OrderingTerm.desc(a.timestamp)])
              ..limit(100))
            .watch();

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: StreamBuilder<List<ActivityLog>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final activities = snapshot.data ?? [];
          if (activities.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    widget.isOwnerView
                        ? 'Aucune activité enregistrée dans ce magasin.'
                        : 'Aucune action récente enregistrée.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: activities.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final act = activities[index];
              final icon = _iconForEntityType(act.entityType);
              final color = _colorForEntityType(act.entityType);

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Icon(icon, color: color, size: 20),
                ),
                title: Text(
                  act.action,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '${act.entityType} • ${_dateFormat.format(act.timestamp)}'
                  '${widget.isOwnerView ? ' • Par: ${act.userId}' : ''}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
