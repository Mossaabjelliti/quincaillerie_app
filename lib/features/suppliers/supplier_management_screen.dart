import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' hide Column;
import '../../data/local/database.dart';
import '../../core/auth/auth_provider.dart';

class SupplierManagementScreen extends StatefulWidget {
  const SupplierManagementScreen({super.key});

  @override
  State<SupplierManagementScreen> createState() => _SupplierManagementScreenState();
}

class _SupplierManagementScreenState extends State<SupplierManagementScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _emailController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _emailController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _openAddSupplierModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            top: 24,
            left: 24,
            right: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Nouveau Fournisseur',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nom du Fournisseur *', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Téléphone', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Adresse / Ville', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  if (_nameController.text.trim().isEmpty) return;
                  final db = context.read<AppDatabase>();
                  final storeId = context.read<AuthProvider>().session?.currentStoreId ?? '';
                  const uuid = Uuid();

                  await db.into(db.suppliers).insert(
                        SuppliersCompanion.insert(
                          id: uuid.v4(),
                          storeId: storeId,
                          name: _nameController.text.trim(),
                          phone: Value(_phoneController.text.trim()),
                          address: Value(_addressController.text.trim()),
                          email: Value(_emailController.text.trim()),
                          synced: const Value(false),
                        ),
                      );

                  _nameController.clear();
                  _phoneController.clear();
                  _addressController.clear();
                  _emailController.clear();
                  if (mounted) Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Enregistrer Fournisseur'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = context.watch<AppDatabase>();
    final storeId = context.watch<AuthProvider>().session?.currentStoreId ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des Fournisseurs'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddSupplierModal(context),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Nouveau Fournisseur'),
        backgroundColor: Colors.amber.shade700,
      ),
      body: StreamBuilder<List<Supplier>>(
        stream: (db.select(db.suppliers)..where((s) => s.storeId.equals(storeId))).watch(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final suppliers = snapshot.data ?? [];
          if (suppliers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.local_shipping_outlined, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text('Aucun fournisseur enregistré.', style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: suppliers.length,
            itemBuilder: (context, index) {
              final sup = suppliers[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blueGrey.shade100,
                    child: Text(sup.name.substring(0, 1).toUpperCase()),
                  ),
                  title: Text(sup.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    sup.phone.isNotEmpty ? 'Tél: ${sup.phone} ${sup.address.isNotEmpty ? "• " + sup.address : ""}' : 'Pas de contact',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.add_shopping_cart_rounded, color: Colors.amber),
                    tooltip: 'Nouvel Achat / Bon de Commande',
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Nouveau Bon d\'Achat pour ${sup.name}')),
                      );
                    },
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
