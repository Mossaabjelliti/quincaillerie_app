import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' hide Column;
import '../../data/local/database.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/auth/authorization_service.dart';
import '../../core/auth/permission.dart';
import '../../core/auth/user_role.dart';

/// Screen for store owners/managers to manage store members (RBAC).
/// Operates locally first; rows are pushed to Supabase by the sync engine.
class MemberManagementScreen extends StatefulWidget {
  const MemberManagementScreen({super.key});

  @override
  State<MemberManagementScreen> createState() => _MemberManagementScreenState();
}

class _MemberManagementScreenState extends State<MemberManagementScreen> {
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  String _roleLabel(UserRole role) => role.displayLabel;

  IconData _roleIcon(UserRole role) => switch (role) {
        UserRole.owner => Icons.verified_user_outlined,
        UserRole.employee => Icons.badge_outlined,
        UserRole.manager => Icons.manage_accounts_outlined,
        UserRole.cashier => Icons.point_of_sale_outlined,
        UserRole.stockManager => Icons.inventory_2_outlined,
        UserRole.accountant => Icons.calculate_outlined,
      };

  Future<void> _openAddMemberModal(BuildContext context) async {
    final authz = context.read<AuthorizationService>();
    if (!authz.can(Permission.employeesManage)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Accès restreint: permission insuffisante pour gérer les membres.')),
      );
      return;
    }

    UserRole selectedRole = UserRole.cashier;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          top: 24,
          left: 24,
          right: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: StatefulBuilder(
          builder: (ctx, setModalState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Nouveau Membre',
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email du membre *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<UserRole>(
                initialValue: selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Rôle',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.manage_accounts_outlined),
                ),
                items: UserRole.storeAssignableRoles.map((role) {
                  return DropdownMenuItem<UserRole>(
                    value: role,
                    child: Row(
                      children: [
                        Icon(_roleIcon(role), size: 20),
                        const SizedBox(width: 10),
                        Text(_roleLabel(role)),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setModalState(() => selectedRole = val);
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  final email = _emailController.text.trim();
                  if (email.isEmpty || !email.contains('@')) return;

                  final db = context.read<AppDatabase>();
                  final auth = context.read<AuthProvider>();
                  final storeId = auth.session?.currentStoreId ?? '';
                  const uuid = Uuid();

                  // Note: The user_id is determined on the server during sync.
                  // Locally we store the email as a provisional user reference.
                  await db.into(db.storeMembers).insert(
                        StoreMembersCompanion.insert(
                          id: uuid.v4(),
                          storeId: storeId,
                          userId: email,
                          role: Value(selectedRole.wireValue),
                          synced: const Value(false),
                        ),
                      );

                  _emailController.clear();
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Ajouter le Membre'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _changeRole(StoreMember member) async {
    final authz = context.read<AuthorizationService>();
    if (!authz.can(Permission.employeesManage)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Accès restreint: permission insuffisante pour modifier les rôles.')),
      );
      return;
    }

    final memberRole = UserRole.fromWire(member.role);
    final selected = await showDialog<UserRole>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Changer le rôle — ${member.userId}'),
        children: UserRole.storeAssignableRoles.map((role) {
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, role),
            child: Row(
              children: [
                Icon(_roleIcon(role), size: 20, color: Colors.amber.shade700),
                const SizedBox(width: 10),
                Text(_roleLabel(role)),
                const Spacer(),
                if (role == memberRole)
                  const Icon(Icons.check, size: 18, color: Colors.green),
              ],
            ),
          );
        }).toList(),
      ),
    );

    if (selected == null || selected == memberRole || !mounted) return;

    final db = context.read<AppDatabase>();
    await (db.update(db.storeMembers)..where((m) => m.id.equals(member.id))).write(
      StoreMembersCompanion(role: Value(selected.wireValue), synced: const Value(false)),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Rôle mis à jour → ${_roleLabel(selected)}')),
      );
    }
  }

  Future<void> _removeMember(StoreMember member) async {
    final authz = context.read<AuthorizationService>();
    if (!authz.can(Permission.employeesManage)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Accès restreint: permission insuffisante pour retirer des membres.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Retirer le membre ?'),
        content: Text('Voulez-vous retirer "${member.userId}" de ce magasin ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final db = context.read<AppDatabase>();
    await (db.delete(db.storeMembers)..where((m) => m.id.equals(member.id))).go();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Membre retiré : ${member.userId}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = context.watch<AppDatabase>();
    final auth = context.watch<AuthProvider>();
    final storeId = auth.session?.currentStoreId ?? '';
    final currentUserId = auth.session?.userId ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des Membres'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddMemberModal(context),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Ajouter un Membre'),
        backgroundColor: Colors.amber.shade700,
      ),
      body: StreamBuilder<List<StoreMember>>(
        stream: (db.select(db.storeMembers)..where((m) => m.storeId.equals(storeId))).watch(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final members = snapshot.data ?? [];
          if (members.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.group_outlined, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text('Aucun membre. Ajoutez votre premier membre.'),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: members.length,
            itemBuilder: (context, index) {
              final member = members[index];
              final isSelf = member.userId == currentUserId;
              final memberRole = UserRole.fromWire(member.role);

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.amber.shade100,
                    foregroundColor: Colors.amber.shade900,
                    child: Icon(_roleIcon(memberRole)),
                  ),
                  title: Text(
                    member.userId,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Row(
                    children: [
                      Icon(_roleIcon(memberRole), size: 14),
                      const SizedBox(width: 4),
                      Text(_roleLabel(memberRole)),
                      if (isSelf) ...[
                        const SizedBox(width: 8),
                        const Text('• Vous', style: TextStyle(color: Colors.green)),
                      ],
                    ],
                  ),
                  trailing: isSelf
                      ? null
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              tooltip: 'Changer le rôle',
                              onPressed: () => _changeRole(member),
                            ),
                            IconButton(
                              icon: const Icon(Icons.person_remove_outlined, color: Colors.red),
                              tooltip: 'Retirer',
                              onPressed: () => _removeMember(member),
                            ),
                          ],
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