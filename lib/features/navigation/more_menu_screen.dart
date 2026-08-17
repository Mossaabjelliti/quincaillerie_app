import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/auth/authorization_service.dart';
import '../../core/auth/permission.dart';
import '../admin/member_management_screen.dart';
import '../customers/customer_debt_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../suppliers/supplier_management_screen.dart';
import '../activity/activity_screen.dart';
import '../settings/settings_screen.dart';

/// Secondary overflow menu ("Plus") for mobile navigation, preventing bottom-bar overcrowding.
class MoreMenuScreen extends StatelessWidget {
  final String storeId;
  final String userId;

  const MoreMenuScreen({
    super.key,
    required this.storeId,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final authz = context.watch<AuthorizationService>();
    final theme = Theme.of(context);
    final isOwner = authz.can(Permission.settingsManage);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plus d\'options'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header summary
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    child: const Icon(Icons.storefront_rounded),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          auth.session?.currentStoreName ?? 'Quincaillerie',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${auth.session?.userEmail ?? ""} • ${auth.session?.currentRole.displayLabel ?? ""}',
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
          const SizedBox(height: 16),

          Text(
            'Modules & Gestion',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          // Owner & Manager Modules
          if (authz.can(Permission.customersView))
            _MenuCardTile(
              icon: Icons.people_outline,
              iconColor: Colors.blue.shade700,
              title: 'Clients & Ardoises',
              subtitle: 'Gestion des clients et suivi des crédits',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CustomerDebtScreen()),
              ),
            ),

          if (authz.can(Permission.suppliersView))
            _MenuCardTile(
              icon: Icons.local_shipping_outlined,
              iconColor: Colors.teal.shade700,
              title: 'Fournisseurs & Réceptions',
              subtitle: 'Entrées de stock et commandes fournisseurs',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SupplierManagementScreen()),
              ),
            ),

          if (authz.can(Permission.employeesView))
            _MenuCardTile(
              icon: Icons.group_outlined,
              iconColor: Colors.indigo.shade700,
              title: 'Employés & Rôles',
              subtitle: 'Gestion des membres et permissions du magasin',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MemberManagementScreen()),
              ),
            ),

          // Activity Log (Owner vs Employee)
          if (authz.can(Permission.activityView))
            _MenuCardTile(
              icon: Icons.history,
              iconColor: Colors.deepOrange.shade700,
              title: 'Activité du Magasin',
              subtitle: 'Historique des opérations et audit trail',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ActivityScreen(
                    storeId: storeId,
                    userId: userId,
                    isOwnerView: true,
                  ),
                ),
              ),
            )
          else if (authz.can(Permission.activityViewOwn))
            _MenuCardTile(
              icon: Icons.history_toggle_off,
              iconColor: Colors.deepOrange.shade700,
              title: 'Mon Activité',
              subtitle: 'Historique de vos actions enregistrées',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ActivityScreen(
                    storeId: storeId,
                    userId: userId,
                    isOwnerView: false,
                  ),
                ),
              ),
            ),

          // For employees without owner navigation, allow opening personal dashboard
          if (!isOwner && authz.can(Permission.salesView))
            _MenuCardTile(
              icon: Icons.dashboard_outlined,
              iconColor: Colors.purple.shade700,
              title: 'Statistiques & Activité',
              subtitle: 'Aperçu de vos ventes et alertes stock',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => DashboardScreen(storeId: storeId)),
              ),
            ),

          if (authz.can(Permission.activityView))
            _MenuCardTile(
              icon: Icons.sync_problem_rounded,
              iconColor: Colors.blueGrey.shade700,
              title: 'Logs de Synchronisation',
              subtitle: 'Statut et historique des synchronisations Supabase',
              onTap: () => Navigator.of(context).pushNamed('/sync-logs'),
            ),

          _MenuCardTile(
            icon: Icons.settings_outlined,
            iconColor: Colors.grey.shade800,
            title: 'Paramètres',
            subtitle: 'Compte, magasins, synchronisation et licence',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuCardTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuCardTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: iconColor.withValues(alpha: 0.12),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: onTap,
      ),
    );
  }
}
