import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' hide Column;
import '../../data/local/database.dart';
import '../../core/auth/auth_provider.dart';

class UnitVariantDialog extends StatefulWidget {
  final Product product;
  const UnitVariantDialog({super.key, required this.product});

  @override
  State<UnitVariantDialog> createState() => _UnitVariantDialogState();
}

class _UnitVariantDialogState extends State<UnitVariantDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _unitNameController = TextEditingController();
  final _factorController = TextEditingController();
  final _unitPriceController = TextEditingController();

  final _variantNameController = TextEditingController();
  final _variantBarcodeController = TextEditingController();
  final _variantBuyPriceController = TextEditingController();
  final _variantSellPriceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _unitNameController.dispose();
    _factorController.dispose();
    _unitPriceController.dispose();

    _variantNameController.dispose();
    _variantBarcodeController.dispose();
    _variantBuyPriceController.dispose();
    _variantSellPriceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = context.watch<AppDatabase>();
    final storeId = context.watch<AuthProvider>().session?.currentStoreId ?? '';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        width: 500,
        height: 550,
        child: Column(
          children: [
            Text(
              'Unités & Variantes - ${widget.product.name}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Conversions d\'Unités'),
                Tab(text: 'Variantes Produit'),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Units
                  Column(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _addUnitModal(context, storeId, db),
                        icon: const Icon(Icons.add),
                        label: const Text('Ajouter une unité (ex: Carton de 50)'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade700, foregroundColor: Colors.white),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: StreamBuilder<List<ProductUnitConversion>>(
                          stream: (db.select(db.productUnitConversions)..where((u) => u.productId.equals(widget.product.id))).watch(),
                          builder: (context, snapshot) {
                            final units = snapshot.data ?? [];
                            if (units.isEmpty) {
                              return const Center(child: Text('Aucune unité supplémentaire configurée.'));
                            }
                            return ListView.builder(
                              itemCount: units.length,
                              itemBuilder: (context, index) {
                                final u = units[index];
                                return ListTile(
                                  title: Text('${u.unitName} = ${u.conversionFactor} unités de base'),
                                  subtitle: Text('Prix de vente: ${u.sellingPrice.toStringAsFixed(3)} TND'),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),

                  // Tab 2: Variants
                  Column(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _addVariantModal(context, storeId, db),
                        icon: const Icon(Icons.add),
                        label: const Text('Ajouter une variante (ex: 1.5mm / 10m)'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade700, foregroundColor: Colors.white),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: StreamBuilder<List<ProductVariant>>(
                          stream: (db.select(db.productVariants)..where((v) => v.productId.equals(widget.product.id))).watch(),
                          builder: (context, snapshot) {
                            final variants = snapshot.data ?? [];
                            if (variants.isEmpty) {
                              return const Center(child: Text('Aucune variante configurée.'));
                            }
                            return ListView.builder(
                              itemCount: variants.length,
                              itemBuilder: (context, index) {
                                final v = variants[index];
                                return ListTile(
                                  title: Text(v.variantName),
                                  subtitle: Text('Code: ${v.barcode} • Prix: ${v.sellPrice.toStringAsFixed(3)} TND'),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addUnitModal(BuildContext context, String storeId, AppDatabase db) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(top: 20, left: 20, right: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Nouvelle Unité', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 12),
              TextField(controller: _unitNameController, decoration: const InputDecoration(labelText: 'Nom de l\'unité (ex: Carton)')),
              TextField(controller: _factorController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Facteur de conversion (ex: 50)')),
              TextField(controller: _unitPriceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Prix de vente spécial (TND)')),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  final factor = double.tryParse(_factorController.text) ?? 1.0;
                  final price = double.tryParse(_unitPriceController.text) ?? widget.product.sellPrice * factor;
                  const uuid = Uuid();

                  await db.into(db.productUnitConversions).insert(
                        ProductUnitConversionsCompanion.insert(
                          id: uuid.v4(),
                          storeId: storeId,
                          productId: widget.product.id,
                          unitName: _unitNameController.text.trim(),
                          conversionFactor: Value(factor),
                          sellingPrice: Value(price),
                        ),
                      );
                  _unitNameController.clear();
                  _factorController.clear();
                  _unitPriceController.clear();
                  if (mounted) Navigator.pop(context);
                },
                child: const Text('Enregistrer Unité'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _addVariantModal(BuildContext context, String storeId, AppDatabase db) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(top: 20, left: 20, right: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Nouvelle Variante', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 12),
              TextField(controller: _variantNameController, decoration: const InputDecoration(labelText: 'Nom variante (ex: 2.5mm / 50m)')),
              TextField(controller: _variantBarcodeController, decoration: const InputDecoration(labelText: 'Code-barres spécifique')),
              TextField(controller: _variantSellPriceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Prix de vente (TND)')),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  final price = double.tryParse(_variantSellPriceController.text) ?? widget.product.sellPrice;
                  const uuid = Uuid();

                  await db.into(db.productVariants).insert(
                        ProductVariantsCompanion.insert(
                          id: uuid.v4(),
                          storeId: storeId,
                          productId: widget.product.id,
                          variantName: _variantNameController.text.trim(),
                          barcode: Value(_variantBarcodeController.text.trim()),
                          sellPrice: Value(price),
                        ),
                      );
                  _variantNameController.clear();
                  _variantBarcodeController.clear();
                  _variantSellPriceController.clear();
                  if (mounted) Navigator.pop(context);
                },
                child: const Text('Enregistrer Variante'),
              ),
            ],
          ),
        );
      },
    );
  }
}
