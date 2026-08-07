import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' hide Column;
import '../../data/local/database.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/inventory/stock_engine.dart';

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
                          phone: _phoneController.text.trim().isEmpty ? const Value.absent() : Value(_phoneController.text.trim()),
                          address: _addressController.text.trim().isEmpty ? const Value.absent() : Value(_addressController.text.trim()),
                          email: _emailController.text.trim().isEmpty ? const Value.absent() : Value(_emailController.text.trim()),
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

  Future<void> _openReceiveStockModal(Supplier supplier) async {
    final barcodeController = TextEditingController();
    final quantityController = TextEditingController(text: '1');
    final buyPriceController = TextEditingController();
    final noteController = TextEditingController();

    await showModalBottomSheet(
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
              Text('Réception marchandise - ${supplier.name}', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(controller: barcodeController, decoration: const InputDecoration(labelText: 'Code-barres produit', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: quantityController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Quantité reçue', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: buyPriceController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Prix d’achat unitaire', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: noteController, decoration: const InputDecoration(labelText: 'Remarque', border: OutlineInputBorder())),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  final db = context.read<AppDatabase>();
                  final storeId = context.read<AuthProvider>().session?.currentStoreId ?? '';
                  final product = await (db.select(db.products)
                        ..where((p) => p.storeId.equals(storeId) & p.barcode.equals(barcodeController.text.trim())))
                      .getSingleOrNull();
                  if (product == null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Produit introuvable pour ce code-barres.')));
                    return;
                  }

                  final quantity = double.tryParse(quantityController.text.replaceAll(',', '.')) ?? 0;
                  if (quantity <= 0) return;
                  final buyPrice = double.tryParse(buyPriceController.text.replaceAll(',', '.')) ?? product.buyPrice;
                  const uuid = Uuid();
                  final now = DateTime.now();
                  final total = buyPrice * quantity;
                  final purchaseId = uuid.v4();

                  await db.into(db.purchases).insert(
                        PurchasesCompanion.insert(
                          id: purchaseId,
                          storeId: storeId,
                          supplierId: supplier.id,
                          createdBy: context.read<AuthProvider>().session?.userId ?? '',
                          total: total,
                          paymentStatus: const Value('RECEIVED'),
                          createdAt: Value(now),
                          synced: const Value(false),
                        ),
                      );

                  await db.into(db.purchaseItems).insert(
                        PurchaseItemsCompanion.insert(
                          id: uuid.v4(),
                          purchaseId: purchaseId,
                          productId: product.id,
                          quantity: quantity,
                          buyPrice: buyPrice,
                          subtotal: total,
                        ),
                      );

                  await StockEngine(db: db).recordMovement(
                    storeId: storeId,
                    productId: product.id,
                    userId: context.read<AuthProvider>().session?.userId ?? '',
                    type: MovementType.purchase,
                    quantity: quantity,
                    movementId: '$purchaseId:${product.id}',
                    note: '${noteController.text.trim()} | Fournisseur: ${supplier.name}',
                  );

                  await (db.update(db.products)..where((p) => p.id.equals(product.id))).write(
                    ProductsCompanion(
                      buyPrice: Value(buyPrice),
                      updatedAt: Value(now),
                      synced: const Value(false),
                    ),
                  );

                  if (mounted) Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade700, foregroundColor: Colors.white),
                child: const Text('Enregistrer la réception'),
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
                    tooltip: 'Réception marchandise',
                    onPressed: () {
                      _openReceiveStockModal(sup);
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
