import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/auth/authorization_service.dart';
import '../../core/auth/permission.dart';
import '../../core/licensing/license_service.dart';
import '../../services/sync_service.dart';
import '../auth/store_selection_screen.dart';

/// Application settings and account management screen.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final authz = context.watch<AuthorizationService>();
    final sync = context.watch<SyncService>();
    final license = context.watch<LicenseService>().state;
    final theme = Theme.of(context);

    final session = auth.session;
    final storeName = session?.currentStoreName ?? 'Non défini';
    final storeId = session?.currentStoreId ?? '';
    final userEmail = session?.userEmail ?? '';
    final roleLabel = session?.currentRole.displayLabel ?? 'Employé';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Store & User Profile Card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: theme.colorScheme.primaryContainer,
                        radius: 24,
                        child: Icon(
                          Icons.store_rounded,
                          color: theme.colorScheme.primary,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              storeName,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              userEmail,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Chip(
                        label: Text(
                          roleLabel,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Licence',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Row(
                        children: [
                          Icon(
                            license.mode.name == 'active'
                                ? Icons.verified_rounded
                                : Icons.offline_bolt_outlined,
                            size: 16,
                            color: license.mode.name == 'active' ? Colors.green : Colors.orange,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            license.mode.name == 'active' ? 'Active' : 'Mode hors ligne',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: license.mode.name == 'active' ? Colors.green : Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Synchronization Section
          Text(
            'Synchronisation',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.sync_rounded),
                  title: const Text('Synchroniser les données'),
                  subtitle: Text(
                    switch (sync.status) {
                      SyncStatus.syncing => 'Synchronisation en cours…',
                      SyncStatus.offline => 'Hors-ligne',
                      SyncStatus.failed => 'Dernière tentative échouée',
                      _ => 'À jour',
                    },
                  ),
                  trailing: OutlinedButton(
                    onPressed: () async {
                      final status = await sync.syncNow(storeId: storeId);
                      if (!context.mounted) return;
                      final msg = status == SyncStatus.success
                          ? 'Synchronisation réussie.'
                          : 'Échec de synchronisation.';
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                    },
                    child: const Text('Synchroniser'),
                  ),
                ),
                if (authz.can(Permission.activityView)) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.sync_problem_rounded),
                    title: const Text('Journaux de synchronisation'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).pushNamed('/sync-logs'),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Store Operations Section
          Text(
            'Session & Compte',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.swap_horiz_rounded),
                  title: const Text('Changer de magasin'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const StoreSelectionScreen()),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.logout_rounded, color: Colors.red),
                  title: const Text('Se déconnecter', style: TextStyle(color: Colors.red)),
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Déconnexion'),
                        content: const Text('Voulez-vous vraiment vous déconnecter ?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Annuler'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: TextButton.styleFrom(foregroundColor: Colors.red),
                            child: const Text('Déconnexion'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true && context.mounted) {
                      auth.signOut();
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'Stocki v1.0 • Quincaillerie Pro OS',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}
