import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' hide Column;
import '../../data/local/database.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/auth/authorization_service.dart';
import '../../core/auth/permission.dart';
import '../../core/inventory/stock_engine.dart';

class SupplierManagementScreen extends StatefulWidget {
  const SupplierManagementScreen({super.key});

  @override
  State<SupplierManagementScreen> createState() => _SupplierManagementScreenState();
}

class _SupplierManagementScreenState extends State<SupplierManagementScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // ADD SUPPLIER
  // ---------------------------------------------------------------------------

  void _openAddSupplierModal(BuildContext context) {
    final authz = context.read<AuthorizationService>();
    if (!authz.can(Permission.suppliersManage)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AccÃ¨s restreint: permission insuffisante pour gÃ©rer les fournisseurs.')),
      );
      return;
    }

    final nameCtl = TextEditingController();
    final phoneCtl = TextEditingController();
    final addressCtl = TextEditingController();
    final emailCtl = TextEditingController();
    final notesCtl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(top: 24, left: 24, right: 24, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Nouveau Fournisseur', style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextField(controller: nameCtl, autofocus: true, decoration: const InputDecoration(labelText: 'Nom *', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: phoneCtl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'TÃ©lÃ©phone', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: addressCtl, decoration: const InputDecoration(labelText: 'Adresse / Ville', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: emailCtl, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: notesCtl, decoration: const InputDecoration(labelText: 'Notes', border: OutlineInputBorder())),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    final name = nameCtl.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Le nom du fournisseur est obligatoire.')));
                      return;
                    }
                    final db = context.read<AppDatabase>();
                    final storeId = context.read<AuthProvider>().session?.currentStoreId ?? '';
                    const uuid = Uuid();
                    await db.into(db.suppliers).insert(
                      SuppliersCompanion.insert(
                        id: uuid.v4(),
                        storeId: storeId,
                        name: name,
                        phone: phoneCtl.text.trim().isEmpty ? const Value.absent() : Value(phoneCtl.text.trim()),
                        address: addressCtl.text.trim().isEmpty ? const Value.absent() : Value(addressCtl.text.trim()),
                        email: emailCtl.text.trim().isEmpty ? const Value.absent() : Value(emailCtl.text.trim()),
                        notes: notesCtl.text.trim().isEmpty ? const Value.absent() : Value(notesCtl.text.trim()),
                        synced: const Value(false),
                      ),
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fournisseur "$name" enregistrÃ©.')));
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade700, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: const Text('Enregistrer Fournisseur'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // EDIT SUPPLIER
  // ---------------------------------------------------------------------------

  void _openEditSupplierModal(BuildContext context, Supplier supplier) {
    final authz = context.read<AuthorizationService>();
    if (!authz.can(Permission.suppliersManage)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permission insuffisante.')));
      return;
    }

    final nameCtl = TextEditingController(text: supplier.name);
    final phoneCtl = TextEditingController(text: supplier.phone);
    final addressCtl = TextEditingController(text: supplier.address);
    final emailCtl = TextEditingController(text: supplier.email);
    final notesCtl = TextEditingController(text: supplier.notes);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(top: 24, left: 24, right: 24, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Modifier Fournisseur', style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextField(controller: nameCtl, decoration: const InputDecoration(labelText: 'Nom *', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: phoneCtl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'TÃ©lÃ©phone', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: addressCtl, decoration: const InputDecoration(labelText: 'Adresse / Ville', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: emailCtl, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: notesCtl, decoration: const InputDecoration(labelText: 'Notes', border: OutlineInputBorder())),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    final name = nameCtl.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Le nom est obligatoire.')));
                      return;
                    }
                    final db = context.read<AppDatabase>();
                    await (db.update(db.suppliers)..where((s) => s.id.equals(supplier.id))).write(
                      SuppliersCompanion(
                        name: Value(name),
                        phone: Value(phoneCtl.text.trim()),
                        address: Value(addressCtl.text.trim()),
                        email: Value(emailCtl.text.trim()),
                        notes: Value(notesCtl.text.trim()),
                        synced: const Value(false),
                      ),
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fournisseur "$name" modifiÃ©.')));
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade700, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: const Text('Sauvegarder'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // DELETE SUPPLIER
  // ---------------------------------------------------------------------------

  void _confirmDeleteSupplier(BuildContext context, Supplier supplier) {
    final authz = context.read<AuthorizationService>();
    if (!authz.can(Permission.suppliersManage)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permission insuffisante.')));
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le fournisseur ?'),
        content: Text('ÃŠtes-vous sÃ»r de vouloir supprimer "${supplier.name}" ? Les achats associÃ©s seront conservÃ©s.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final db = context.read<AppDatabase>();
              await (db.delete(db.suppliers)..where((s) => s.id.equals(supplier.id))).go();
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('"${supplier.name}" supprimÃ©.')));
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // MULTI-PRODUCT PURCHASE CREATION
  // ---------------------------------------------------------------------------

  void _openNewPurchaseModal(BuildContext context, Supplier supplier) {
    final authz = context.read<AuthorizationService>();
    if (!authz.can(Permission.suppliersManage)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permission insuffisante.')));
      return;
    }

    final db = context.read<AppDatabase>();
    final storeId = context.read<AuthProvider>().session?.currentStoreId ?? '';
    final userId = context.read<AuthProvider>().session?.userId ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return _PurchaseCreationSheet(
          db: db,
          storeId: storeId,
          userId: userId,
          supplier: supplier,
          onComplete: () {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Achat enregistrÃ© chez ${supplier.name}.'), backgroundColor: Colors.green.shade700),
              );
            }
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // SUPPLIER DETAILS + PURCHASE HISTORY
  // ---------------------------------------------------------------------------

  void _showSupplierDetails(BuildContext context, Supplier supplier) {
    final db = context.read<AppDatabase>();
    final storeId = context.read<AuthProvider>().session?.currentStoreId ?? '';
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.85,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.blueGrey.shade100,
                    foregroundColor: Colors.blueGrey.shade900,
                    child: Text(supplier.name.substring(0, 1).toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(supplier.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        if (supplier.phone.isNotEmpty) Text('TÃ©l: ${supplier.phone}', style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                        if (supplier.address.isNotEmpty) Text(supplier.address, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                      ],
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.edit_outlined, size: 20), tooltip: 'Modifier', onPressed: () { Navigator.pop(ctx); _openEditSupplierModal(context, supplier); }),
                  IconButton(icon: Icon(Icons.delete_outline, size: 20, color: Colors.red.shade400), tooltip: 'Supprimer', onPressed: () { Navigator.pop(ctx); _confirmDeleteSupplier(context, supplier); }),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 12),

              // Action: New purchase
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.add_shopping_cart_rounded),
                  label: const Text('Nouvel Achat'),
                  style: FilledButton.styleFrom(backgroundColor: Colors.amber.shade700),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _openNewPurchaseModal(context, supplier);
                  },
                ),
              ),
              const SizedBox(height: 12),

              const Divider(),
              Text('Historique des Achats', style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),

              // Purchase list
              Expanded(
                child: StreamBuilder<List<Purchase>>(
                  stream: (db.select(db.purchases)
                        ..where((p) => p.supplierId.equals(supplier.id) & p.storeId.equals(storeId))
                        ..orderBy([(p) => OrderingTerm.desc(p.createdAt)]))
                      .watch(),
                  builder: (context, snapshot) {
                    final purchases = snapshot.data ?? [];
                    if (purchases.isEmpty) return const Center(child: Text('Aucun achat enregistrÃ©.'));

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: purchases.length,
                      itemBuilder: (ctx, i) {
                        final p = purchases[i];
                        final statusLabel = p.paymentStatus == 'PAID'
                            ? 'PAYÃ‰'
                            : (p.paymentStatus == 'PARTIAL' ? 'PARTIEL' : (p.paymentStatus == 'PENDING' ? 'EN ATTENTE' : p.paymentStatus));
                        final statusColor = p.paymentStatus == 'PAID'
                            ? Colors.green
                            : (p.paymentStatus == 'PARTIAL' ? Colors.orange : Colors.red);

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ExpansionTile(
                            leading: CircleAvatar(
                              radius: 18,
                              backgroundColor: statusColor.withValues(alpha: 0.15),
                              child: Icon(Icons.receipt_outlined, size: 18, color: statusColor),
                            ),
                            title: Text('${p.total.toStringAsFixed(3)} TND', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('${dateFormat.format(p.createdAt)} â€¢ $statusLabel', style: TextStyle(fontSize: 12, color: statusColor)),
                            children: [
                              FutureBuilder<List<PurchaseItem>>(
                                future: (db.select(db.purchaseItems)..where((pi) => pi.purchaseId.equals(p.id))).get(),
                                builder: (context, itemSnap) {
                                  final items = itemSnap.data ?? [];
                                  if (items.isEmpty) return const Padding(padding: EdgeInsets.all(8), child: Text('Pas de dÃ©tails.'));
                                  return Column(
                                    children: items.map((item) {
                                      return FutureBuilder<Product?>(
                                        future: (db.select(db.products)..where((pr) => pr.id.equals(item.productId))).getSingleOrNull(),
                                        builder: (context, prodSnap) {
                                          final prodName = prodSnap.data?.name ?? item.productId.substring(0, 8);
                                          return ListTile(
                                            dense: true,
                                            title: Text(prodName, style: const TextStyle(fontSize: 14)),
                                            subtitle: Text('${item.quantity} Ã— ${item.buyPrice.toStringAsFixed(3)} TND'),
                                            trailing: Text('${item.subtotal.toStringAsFixed(3)} TND', style: const TextStyle(fontWeight: FontWeight.bold)),
                                          );
                                        },
                                      );
                                    }).toList(),
                                  );
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final db = context.watch<AppDatabase>();
    final storeId = context.watch<AuthProvider>().session?.currentStoreId ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Fournisseurs & Achats')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddSupplierModal(context),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Nouveau Fournisseur'),
        backgroundColor: Colors.amber.shade700,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher par nom, tÃ©l ou adresseâ€¦',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchController.clear(); setState(() => _searchQuery = ''); })
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Supplier>>(
              stream: (db.select(db.suppliers)
                    ..where((s) => s.storeId.equals(storeId))
                    ..orderBy([(s) => OrderingTerm.asc(s.name)]))
                  .watch(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

                final allSuppliers = snapshot.data ?? [];
                final suppliers = _searchQuery.isEmpty
                    ? allSuppliers
                    : allSuppliers
                        .where((s) =>
                            s.name.toLowerCase().contains(_searchQuery) ||
                            s.phone.toLowerCase().contains(_searchQuery) ||
                            s.address.toLowerCase().contains(_searchQuery))
                        .toList();

                if (suppliers.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.local_shipping_outlined, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty ? 'Aucun fournisseur enregistrÃ©.' : 'Aucun rÃ©sultat trouvÃ©.',
                          style: const TextStyle(color: Colors.grey, fontSize: 16),
                        ),
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
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _showSupplierDetails(context, sup),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Colors.blueGrey.shade100,
                                child: Text(sup.name.isNotEmpty ? sup.name.substring(0, 1).toUpperCase() : '?'),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(sup.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    const SizedBox(height: 2),
                                    Text(
                                      [
                                        if (sup.phone.isNotEmpty) 'TÃ©l: ${sup.phone}',
                                        if (sup.address.isNotEmpty) sup.address,
                                      ].join(' â€¢ '),
                                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_shopping_cart_rounded, color: Colors.amber),
                                tooltip: 'Nouvel achat',
                                onPressed: () => _openNewPurchaseModal(context, sup),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// PURCHASE CREATION SHEET â€” Multi-product, payment status, atomic insertion
// =============================================================================

class _PurchaseCreationSheet extends StatefulWidget {
  final AppDatabase db;
  final String storeId;
  final String userId;
  final Supplier supplier;
  final VoidCallback onComplete;

  const _PurchaseCreationSheet({
    required this.db,
    required this.storeId,
    required this.userId,
    required this.supplier,
    required this.onComplete,
  });

  @override
  State<_PurchaseCreationSheet> createState() => _PurchaseCreationSheetState();
}

class _PurchaseLineItem {
  Product product;
  double quantity = 1;
  double buyPrice;
  double get subtotal => quantity * buyPrice;

  _PurchaseLineItem({required this.product, required this.buyPrice});
}

class _PurchaseCreationSheetState extends State<_PurchaseCreationSheet> {
  final List<_PurchaseLineItem> _lines = [];
  String _paymentStatus = 'PAID';
  bool _saving = false;

  final _productSearchCtl = TextEditingController();
  List<Product> _productResults = [];

  double get _grandTotal => _lines.fold(0.0, (sum, l) => sum + l.subtotal);

  Future<void> _searchProducts(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _productResults = []);
      return;
    }
    final q = query.trim().toLowerCase();
    final results = await (widget.db.select(widget.db.products)
          ..where((p) => p.storeId.equals(widget.storeId))
          ..limit(20))
        .get();
    setState(() {
      _productResults = results.where((p) => p.name.toLowerCase().contains(q) || p.barcode.toLowerCase().contains(q)).toList();
    });
  }

  void _addProduct(Product product) {
    final existing = _lines.indexWhere((l) => l.product.id == product.id);
    if (existing >= 0) {
      setState(() => _lines[existing].quantity += 1);
    } else {
      setState(() => _lines.add(_PurchaseLineItem(product: product, buyPrice: product.buyPrice)));
    }
    _productSearchCtl.clear();
    setState(() => _productResults = []);
  }

  Future<void> _savePurchase() async {
    if (_lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ajoutez au moins un produit.')));
      return;
    }
    setState(() => _saving = true);

    try {
      const uuid = Uuid();
      final purchaseId = uuid.v4();
      final now = DateTime.now();
      final total = _grandTotal;
      final engine = StockEngine(db: widget.db);

      await widget.db.transaction(() async {
        // 1. Insert Purchase
        await widget.db.into(widget.db.purchases).insert(
          PurchasesCompanion.insert(
            id: purchaseId,
            storeId: widget.storeId,
            supplierId: widget.supplier.id,
            createdBy: widget.userId,
            total: total,
            paymentStatus: Value(_paymentStatus),
            createdAt: Value(now),
            synced: const Value(false),
          ),
        );

        // 2. Insert each PurchaseItem + StockMovement + reconcile
        for (final line in _lines) {
          final itemId = uuid.v4();
          await widget.db.into(widget.db.purchaseItems).insert(
            PurchaseItemsCompanion.insert(
              id: itemId,
              purchaseId: purchaseId,
              productId: line.product.id,
              quantity: line.quantity,
              buyPrice: line.buyPrice,
              subtotal: line.subtotal,
            ),
          );

          await engine.recordMovement(
            storeId: widget.storeId,
            productId: line.product.id,
            userId: widget.userId,
            type: MovementType.purchase,
            quantity: line.quantity,
            movementId: '$purchaseId:${line.product.id}',
            note: 'Achat #${purchaseId.substring(0, 8)} | Fournisseur: ${widget.supplier.name}',
          );

          // Update buy price on product if changed
          if ((line.buyPrice - line.product.buyPrice).abs() > 0.001) {
            await (widget.db.update(widget.db.products)..where((p) => p.id.equals(line.product.id))).write(
              ProductsCompanion(
                buyPrice: Value(line.buyPrice),
                updatedAt: Value(now),
                synced: const Value(false),
              ),
            );
          }
        }
      });

      if (mounted) Navigator.pop(context);
      widget.onComplete();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      padding: EdgeInsets.only(top: 16, left: 16, right: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Text('Nouvel Achat â€” ${widget.supplier.name}', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              ),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 8),

          // Product search
          TextField(
            controller: _productSearchCtl,
            decoration: InputDecoration(
              hintText: 'Chercher un produit (nom ou code-barres)â€¦',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
            ),
            onChanged: _searchProducts,
          ),

          // Search results dropdown
          if (_productResults.isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxHeight: 160),
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4, offset: const Offset(0, 2))],
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _productResults.length,
                itemBuilder: (ctx, i) {
                  final p = _productResults[i];
                  return ListTile(
                    dense: true,
                    title: Text(p.name, style: const TextStyle(fontSize: 14)),
                    subtitle: Text('Code: ${p.barcode} â€¢ Achat: ${p.buyPrice.toStringAsFixed(3)} TND', style: const TextStyle(fontSize: 11)),
                    trailing: const Icon(Icons.add_circle_outline, color: Colors.green),
                    onTap: () => _addProduct(p),
                  );
                },
              ),
            ),

          const SizedBox(height: 8),

          // Line items
          Expanded(
            child: _lines.isEmpty
                ? Center(
                    child: Text('Ajoutez des produits Ã  l\'achat.', style: TextStyle(color: Colors.grey.shade500)),
                  )
                : ListView.builder(
                    itemCount: _lines.length,
                    itemBuilder: (ctx, i) {
                      final line = _lines[i];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(line.product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        SizedBox(
                                          width: 70,
                                          child: TextFormField(
                                            initialValue: line.quantity.toString(),
                                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                            decoration: const InputDecoration(labelText: 'QtÃ©', border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8)),
                                            style: const TextStyle(fontSize: 13),
                                            onChanged: (val) {
                                              final q = double.tryParse(val.replaceAll(',', '.'));
                                              if (q != null && q > 0) setState(() => line.quantity = q);
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        SizedBox(
                                          width: 90,
                                          child: TextFormField(
                                            initialValue: line.buyPrice.toStringAsFixed(3),
                                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                            decoration: const InputDecoration(labelText: 'P.Achat', border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8)),
                                            style: const TextStyle(fontSize: 13),
                                            onChanged: (val) {
                                              final bp = double.tryParse(val.replaceAll(',', '.'));
                                              if (bp != null && bp >= 0) setState(() => line.buyPrice = bp);
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text('= ${line.subtotal.toStringAsFixed(3)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 22),
                                onPressed: () => setState(() => _lines.removeAt(i)),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          const Divider(),

          // Payment status
          Row(
            children: [
              const Text('Statut: ', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Expanded(
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'PAID', label: Text('PayÃ©', style: TextStyle(fontSize: 12))),
                    ButtonSegment(value: 'PARTIAL', label: Text('Partiel', style: TextStyle(fontSize: 12))),
                    ButtonSegment(value: 'PENDING', label: Text('En attente', style: TextStyle(fontSize: 12))),
                  ],
                  selected: {_paymentStatus},
                  onSelectionChanged: (v) => setState(() => _paymentStatus = v.first),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Total + Save
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.amber.shade300)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.amber.shade900)),
                Text('${_grandTotal.toStringAsFixed(3)} TND', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.amber.shade900)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _saving ? null : _savePurchase,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade700, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
            child: _saving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Valider l\'Achat'),
          ),
        ],
      ),
    );
  }
}
