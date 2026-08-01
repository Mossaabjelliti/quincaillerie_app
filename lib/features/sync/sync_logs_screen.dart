import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/sync_service.dart';

class SyncLogsScreen extends StatelessWidget {
  const SyncLogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final syncService = context.read<SyncService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Journaux de synchronisation')),
      body: FutureBuilder(
        future: syncService.recentLogs(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final logs = snapshot.data ?? [];
          if (logs.isEmpty) {
            return const Center(child: Text('Aucun log de synchronisation.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: logs.length,
            separatorBuilder: (_, __) => const Divider(height: 20),
            itemBuilder: (context, index) {
              final log = logs[index];
              return ListTile(
                leading: const Icon(Icons.sync_problem_outlined),
                title: Text('${log.action} • ${log.targetTable}'),
                subtitle: Text('${log.rowId}\n${log.errorMessage}'),
                isThreeLine: true,
                trailing: Text(
                  '${log.createdAt.hour.toString().padLeft(2, '0')}:${log.createdAt.minute.toString().padLeft(2, '0')}',
                ),
              );
            },
          );
        },
      ),
    );
  }
}
