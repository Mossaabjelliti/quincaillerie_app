import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:drift/drift.dart' hide Column;
import '../../data/local/database.dart';

class InventoryScreen extends StatefulWidget {
  final String storeId;

  const InventoryScreen({super.key, required this.storeId});

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

              await (db.update(db.products)..where((p) => p.id.equals(product.id))).write(
                ProductsCompanion(
                  quantity: Value(newQty),
                  sellPrice: Value(newSell),
                  buyPrice: Value(newBuy),
                  lowStockThreshold: Value(newThreshold),
                  updatedAt: Value(DateTime.now()),
                  synced: const Value(false),
                ),
              );

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

  @override
  Widget build(BuildContext context) {
    final db = context.watch<AppDatabase>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventaire & Stock'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_box_outlined),
            tooltip: 'Nouveau produit',
            onPressed: () => Navigator.of(context).pushNamed('/add-product'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar & Filter Controls
          Padding(
            padding: const EdgeInsets.all(12.0),
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
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    FilterChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 16,
                            color: _showLowStockOnly ? Colors.orange.shade800 : null,
                          ),
                          const SizedBox(width: 4),
                          const Text('Stock bas uniquement'),
                        ],
                      ),
                      selected: _showLowStockOnly,
                      onSelected: (val) => setState(() => _showLowStockOnly = val),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _categories.map((cat) {
                      final isSelected = _selectedCategory == cat;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6.0),
                        child: ChoiceChip(
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
                  // Search query filter
                  if (_searchQuery.isNotEmpty) {
                    final q = _searchQuery.toLowerCase();
                    final matchName = p.name.toLowerCase().contains(q);
                    final matchCode = p.barcode.toLowerCase().contains(q);
                    if (!matchName && !matchCode) return false;
                  }

                  // Category filter
                  if (_selectedCategory != 'Tous' && p.category != _selectedCategory) {
                    return false;
                  }

                  // Low stock filter
                  if (_showLowStockOnly && p.quantity > p.lowStockThreshold) {
                    return false;
                  }

                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 64,
                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Aucun produit trouvé',
                          style: theme.textTheme.titleMedium,
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: filtered.length,
                  separatorBuilder: (ctx, i) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final p = filtered[i];
                    final isLowStock = p.quantity <= p.lowStockThreshold;
                    final unitSuffix = _getUnitSuffix(p.unit);

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              p.name,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          if (isLowStock)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              margin: const EdgeInsets.only(left: 6),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(4),
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
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text('Code: ${p.barcode} | Catégorie: ${p.category}'),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                'Stock: ${p.quantity} $unitSuffix',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isLowStock ? Colors.orange.shade900 : Colors.green.shade800,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Prix: ${p.sellPrice.toStringAsFixed(3)} TND',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.qr_code),
                            tooltip: 'Code QR',
                            onPressed: () {
                              Navigator.of(context).pushNamed(
                                '/qr-generator',
                                arguments: p,
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            tooltip: 'Modifier',
                            onPressed: () => _showEditProductDialog(p),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            tooltip: 'Supprimer',
                            onPressed: () => _deleteProduct(p),
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
  }
}
