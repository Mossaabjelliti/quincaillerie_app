import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:uuid/uuid.dart';
import '../../data/local/database.dart';
import '../../core/inventory/stock_engine.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/device_identity.dart';
import 'unit_variant_dialog.dart';

class InventoryScreen extends StatefulWidget {
  final String storeId;
  final bool canManageStock;

  const InventoryScreen({super.key, required this.storeId, required this.canManageStock});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'Tous';
  bool _showLowStockOnly = false;

  static const List<String> _categories = [
    'Tous',
    'Vis & Boulons',
    'Tuyauterie & Plomberie',
    'Électricité & Éclairage',
    'Peinture & Vernis',
    'Outillage',
    'Serrurerie & Quincaillerie',
    'Matériaux de construction',
    'Jardinage & Arrosage',
    'Sanitaire',
    'Divers',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _getUnitSuffix(ProductUnit unit) {
    switch (unit) {
      case ProductUnit.piece:
        return 'pc';
      case ProductUnit.meter:
        return 'm';
      case ProductUnit.kg:
        return 'kg';
      case ProductUnit.liter:
        return 'L';
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Vis & Boulons':
        return Icons.hardware_outlined;
      case 'Tuyauterie & Plomberie':
        return Icons.plumbing_outlined;
      case 'Électricité & Éclairage':
        return Icons.flash_on_outlined;
      case 'Peinture & Vernis':
        return Icons.format_paint_outlined;
      case 'Outillage':
        return Icons.build_outlined;
      case 'Serrurerie & Quincaillerie':
        return Icons.lock_outline;
      case 'Matériaux de construction':
        return Icons.foundation_outlined;
      case 'Jardinage & Arrosage':
        return Icons.grass_outlined;
      case 'Sanitaire':
        return Icons.bathtub_outlined;
      default:
        return Icons.category_outlined;
    }
  }

  Future<void> _showEditProductDialog(Product product) async {
    final qtyController = TextEditingController(text: product.quantity.toString());
    final buyPriceController = TextEditingController(text: product.buyPrice.toStringAsFixed(3));
    final sellPriceController = TextEditingController(text: product.sellPrice.toStringAsFixed(3));
    final lowStockController = TextEditingController(text: product.lowStockThreshold.toString());

    final formKey = GlobalKey<FormState>();

    final updated = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Modifier — ${product.name}'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: qtyController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Quantité en stock (${_getUnitSuffix(product.unit)})',
                    border: const OutlineInputBorder(),
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'Obligatoire';
                    if (double.tryParse(val.replaceAll(',', '.')) == null) return 'Invalide';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: sellPriceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Prix de vente (TND)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'Obligatoire';
                    if (double.tryParse(val.replaceAll(',', '.')) == null) return 'Invalide';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: buyPriceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Prix d\'achat (TND)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: lowStockController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Seuil stock bas',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final db = ctx.read<AppDatabase>();
              final newQty = double.parse(qtyController.text.replaceAll(',', '.'));
              final newSell = double.parse(sellPriceController.text.replaceAll(',', '.'));
              final newBuy = double.tryParse(buyPriceController.text.replaceAll(',', '.')) ?? product.buyPrice;
              final newThreshold = double.tryParse(lowStockController.text.replaceAll(',', '.')) ?? product.lowStockThreshold;
              final deviceId = await DeviceIdentity.id;

              final userId = ctx.read<AuthProvider>().session?.userId ?? '';
              await db.transaction(() async {
                await (db.update(db.products)..where((p) => p.id.equals(product.id))).write(
                  ProductsCompanion(
                    sellPrice: Value(newSell),
                    buyPrice: Value(newBuy),
                    lowStockThreshold: Value(newThreshold),
                    updatedAt: Value(DateTime.now()),
                    synced: const Value(false),
                  ),
                );
                final delta = newQty - product.quantity;
                if (delta != 0) {
                  await db.into(db.stockMovements).insert(
                        StockMovementsCompanion.insert(
                          id: const Uuid().v4(),
                          productId: product.id,
                          storeId: widget.storeId,
                          userId: userId,
                          deviceId: Value(deviceId),
                          type: MovementType.adjustment,
                          quantity: delta,
                          note: const Value('Modification depuis fiche produit'),
                          createdAt: Value(DateTime.now()),
                          synced: const Value(false),
                        ),
                      );
                  await (db.update(db.products)..where((p) => p.id.equals(product.id))).write(
                    ProductsCompanion(quantity: Value(newQty)),
                  );
                }
              });

              if (!ctx.mounted) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (updated == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Produit "${product.name}" mis à jour')),
      );
    }
  }

  Future<void> _deleteProduct(Product product) async {
    if (!widget.canManageStock) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le produit ?'),
        content: Text('Voulez-vous vraiment supprimer "${product.name}" de l\'inventaire ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final db = context.read<AppDatabase>();
      await (db.delete(db.products)..where((p) => p.id.equals(product.id))).go();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Produit "${product.name}" supprimé')),
      );
    }
  }

  Future<void> _showPhysicalCountDialog(Product product) async {
    final countController = TextEditingController(text: product.quantity.toString());
    final reasonController = TextEditingController(text: 'Comptage physique');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Comptage physique — ${product.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: countController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Quantité réelle',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Motif / remarque',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (result != true || !mounted) return;

    final actualQty = double.tryParse(countController.text.replaceAll(',', '.'));
    if (actualQty == null) return;

    final db = context.read<AppDatabase>();
    final userId = context.read<AuthProvider>().session?.userId ?? '';
    final engine = StockEngine(db: db);
    final delta = actualQty - product.quantity;
    if (delta == 0) return;

    await engine.recordMovement(
      storeId: widget.storeId,
      productId: product.id,
      userId: userId,
      type: MovementType.adjustment,
      quantity: delta,
      note: '${reasonController.text.trim()} | réel: $actualQty | système: ${product.quantity}',
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Stock réconcilié: ${product.name} = $actualQty')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = context.watch<AppDatabase>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventaire & Stock'),
        actions: [
          if (widget.canManageStock)
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'Nouveau produit',
              onPressed: () => Navigator.of(context).pushNamed('/add-product'),
            ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Rechercher par nom ou code-barres',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    FilterChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 16,
                            color: _showLowStockOnly ? Colors.white : Colors.orange.shade800,
                          ),
                          const SizedBox(width: 6),
                          const Text('Stock bas uniquement'),
                        ],
                      ),
                      selected: _showLowStockOnly,
                      selectedColor: Colors.orange.shade800,
                      onSelected: (val) => setState(() => _showLowStockOnly = val),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _categories.map((cat) {
                      final isSelected = _selectedCategory == cat;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6.0),
                        child: ChoiceChip(
                          avatar: cat != 'Tous'
                              ? Icon(
                                  _getCategoryIcon(cat),
                                  size: 16,
                                  color: isSelected ? Colors.white : theme.colorScheme.primary,
                                )
                              : null,
                          label: Text(cat),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _selectedCategory = cat);
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // Products List Stream
          Expanded(
            child: StreamBuilder<List<Product>>(
              stream: db.watchProducts(widget.storeId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final all = snapshot.data ?? [];
                final filtered = all.where((p) {
                  if (_searchQuery.isNotEmpty) {
                    final q = _searchQuery.toLowerCase();
                    final matchName = p.name.toLowerCase().contains(q);
                    final matchCode = p.barcode.toLowerCase().contains(q);
                    if (!matchName && !matchCode) return false;
                  }

                  if (_selectedCategory != 'Tous' && p.category != _selectedCategory) {
                    return false;
                  }

                  if (_showLowStockOnly && p.quantity > p.lowStockThreshold) {
                    return false;
                  }

                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 72,
                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Aucun produit trouvé',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Essayez de modifier votre recherche ou ajoutez un nouveau produit.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) {
                    final p = filtered[i];
                    final isLowStock = p.quantity <= p.lowStockThreshold;
                    final unitSuffix = _getUnitSuffix(p.unit);
                    final catIcon = _getCategoryIcon(p.category);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: theme.colorScheme.primaryContainer,
                                  child: Icon(catIcon, color: theme.colorScheme.primary, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p.name,
                                        style: theme.textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        'Code: ${p.barcode} • ${p.category}',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isLowStock)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade100,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Stock bas',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange.shade900,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const Divider(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'En stock',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    Text(
                                      '${p.quantity} $unitSuffix',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: isLowStock ? Colors.orange.shade900 : Colors.green.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Prix de vente',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    Text(
                                      '${p.sellPrice.toStringAsFixed(3)} TND',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                                Wrap(
                                  alignment: WrapAlignment.end,
                                  spacing: 0,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.qr_code, size: 20),
                                      tooltip: 'Code QR',
                                      onPressed: () {
                                        Navigator.of(context).pushNamed(
                                          '/qr-generator',
                                          arguments: p,
                                        );
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.qr_code_scanner_outlined, size: 20),
                                      tooltip: 'Unités & variantes',
                                      onPressed: widget.canManageStock
                                          ? () => showDialog(
                                                context: context,
                                                builder: (_) => UnitVariantDialog(product: p),
                                              )
                                          : null,
                                    ),
                                    if (widget.canManageStock)
                                      IconButton(
                                        icon: const Icon(Icons.fact_check_outlined, size: 20),
                                        tooltip: 'Comptage physique',
                                        onPressed: () => _showPhysicalCountDialog(p),
                                      ),
                                    if (widget.canManageStock)
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 20),
                                        tooltip: 'Modifier',
                                        onPressed: () => _showEditProductDialog(p),
                                      ),
                                    if (widget.canManageStock)
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                        tooltip: 'Supprimer',
                                        onPressed: () => _deleteProduct(p),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ],
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
