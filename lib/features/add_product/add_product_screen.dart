import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' hide Column;
import '../../data/local/database.dart';
import '../../core/device_identity.dart';

/// Screen allowing shop owners to register a new product in their local inventory.
/// Supports both fixed-unit items (pieces) and hardware bulk/cut items (meters, kg, liters).
class AddProductScreen extends StatefulWidget {
  final String storeId;
  final String userId;
  final String? initialBarcode;

  const AddProductScreen({
    super.key,
    required this.storeId,
    required this.userId,
    this.initialBarcode,
  });

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _barcodeController;
  late final TextEditingController _nameController;
  late final TextEditingController _categoryController;
  late final TextEditingController _buyPriceController;
  late final TextEditingController _sellPriceController;
  late final TextEditingController _quantityController;
  late final TextEditingController _lowStockController;

  ProductUnit _selectedUnit = ProductUnit.piece;
  bool _isSubmitting = false;

  static const List<String> _suggestedCategories = [
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
  void initState() {
    super.initState();
    _barcodeController = TextEditingController(text: widget.initialBarcode ?? '');
    _nameController = TextEditingController();
    _categoryController = TextEditingController(text: _suggestedCategories.first);
    _buyPriceController = TextEditingController(text: '0.000');
    _sellPriceController = TextEditingController();
    _quantityController = TextEditingController(text: '0');
    _lowStockController = TextEditingController(text: '5');
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    _nameController.dispose();
    _categoryController.dispose();
    _buyPriceController.dispose();
    _sellPriceController.dispose();
    _quantityController.dispose();
    _lowStockController.dispose();
    super.dispose();
  }

  String _getUnitLabel(ProductUnit unit) {
    switch (unit) {
      case ProductUnit.piece:
        return 'Pièce (pc)';
      case ProductUnit.meter:
        return 'Mètre (m)';
      case ProductUnit.kg:
        return 'Kilogramme (kg)';
      case ProductUnit.liter:
        return 'Litre (L)';
    }
  }

  IconData _getUnitIcon(ProductUnit unit) {
    switch (unit) {
      case ProductUnit.piece:
        return Icons.inventory_2_outlined;
      case ProductUnit.meter:
        return Icons.straighten;
      case ProductUnit.kg:
        return Icons.scale_outlined;
      case ProductUnit.liter:
        return Icons.opacity_outlined;
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final db = context.read<AppDatabase>();
      final barcode = _barcodeController.text.trim();
      final name = _nameController.text.trim();
      final category = _categoryController.text.trim();
      final buyPrice = double.tryParse(_buyPriceController.text.replaceAll(',', '.')) ?? 0.0;
      final sellPrice = double.tryParse(_sellPriceController.text.replaceAll(',', '.')) ?? 0.0;
      final quantity = double.tryParse(_quantityController.text.replaceAll(',', '.')) ?? 0.0;
      final lowStock = double.tryParse(_lowStockController.text.replaceAll(',', '.')) ?? 5.0;

      // Check if barcode already exists for this store
      final existing = await (db.select(db.products)
            ..where((p) => (p.barcode.equals(barcode)) & (p.storeId.equals(widget.storeId))))
          .getSingleOrNull();

      if (existing != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Un produit avec le code "$barcode" existe déjà (${existing.name}).'),
            backgroundColor: Colors.red.shade700,
          ),
        );
        setState(() => _isSubmitting = false);
        return;
      }

      final newId = const Uuid().v4();
      final now = DateTime.now();
      final deviceId = await DeviceIdentity.id;

      await db.transaction(() async {
        await db.into(db.products).insert(
              ProductsCompanion.insert(
                id: newId,
                storeId: widget.storeId,
                name: name,
                barcode: barcode,
                category: Value(category),
                unit: _selectedUnit,
                buyPrice: Value(buyPrice),
                sellPrice: Value(sellPrice),
                // This is a cache. The opening balance below is authoritative.
                quantity: const Value(0),
                lowStockThreshold: Value(lowStock),
                createdAt: Value(now),
                updatedAt: Value(now),
                synced: const Value(false),
              ),
            );
        if (quantity != 0) {
          await db.into(db.stockMovements).insert(
                StockMovementsCompanion.insert(
                  id: const Uuid().v4(),
                  productId: newId,
                  storeId: widget.storeId,
                  userId: widget.userId,
                  deviceId: Value(deviceId),
                  type: MovementType.stockIn,
                  quantity: quantity,
                  note: const Value('Stock initial'),
                  createdAt: Value(now),
                  synced: const Value(false),
                ),
              );
          await (db.update(db.products)..where((p) => p.id.equals(newId)))
              .write(ProductsCompanion(quantity: Value(quantity)));
        }
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Produit "$name" créé avec succès (Stock: $quantity ${_getUnitLabel(_selectedUnit)})'),
          backgroundColor: Colors.green.shade700,
        ),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la création du produit: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nouveau produit'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                margin: const EdgeInsets.only(bottom: 20),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Icon(Icons.qr_code_2, color: theme.colorScheme.primary, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Code-barres scanné',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              _barcodeController.text.isNotEmpty
                                  ? _barcodeController.text
                                  : 'Aucun code scanné',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Section: Informations Générales
              Text(
                'Informations générales',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              // Barcode Field (in case manual edit is needed)
              TextFormField(
                controller: _barcodeController,
                decoration: const InputDecoration(
                  labelText: 'Code-barres / Identifiant *',
                  prefixIcon: Icon(Icons.qr_code),
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Veuillez saisir un code-barres';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Name Field
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Nom du produit *',
                  hintText: 'ex: Câble 2.5mm, Vis à bois 4x40...',
                  prefixIcon: Icon(Icons.shopping_bag_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Le nom du produit est obligatoire';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Category Field with Autocomplete
              Autocomplete<String>(
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return _suggestedCategories;
                  }
                  return _suggestedCategories.where((String option) {
                    return option
                        .toLowerCase()
                        .contains(textEditingValue.text.toLowerCase());
                  });
                },
                initialValue: TextEditingValue(text: _categoryController.text),
                onSelected: (String selection) {
                  _categoryController.text = selection;
                },
                fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                  // Keep external controller in sync
                  controller.addListener(() {
                    _categoryController.text = controller.text;
                  });
                  return TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    onEditingComplete: onEditingComplete,
                    decoration: const InputDecoration(
                      labelText: 'Catégorie',
                      hintText: 'Sélectionner ou saisir une catégorie',
                      prefixIcon: Icon(Icons.category_outlined),
                      border: OutlineInputBorder(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),

              // Section: Unité et Tarification
              Text(
                'Unité & Tarification (TND)',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              // Unit Selector (Hardware specific: piece, meter, kg, liter)
              DropdownButtonFormField<ProductUnit>(
                initialValue: _selectedUnit,
                decoration: const InputDecoration(
                  labelText: 'Unité de vente *',
                  prefixIcon: Icon(Icons.straighten),
                  border: OutlineInputBorder(),
                  helperText: 'Adapté aux produits au mètre, kg, litre ou pièce',
                ),
                items: ProductUnit.values.map((unit) {
                  return DropdownMenuItem<ProductUnit>(
                    value: unit,
                    child: Row(
                      children: [
                        Icon(_getUnitIcon(unit), size: 20),
                        const SizedBox(width: 10),
                        Text(_getUnitLabel(unit)),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedUnit = val);
                  }
                },
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  // Buy Price
                  Expanded(
                    child: TextFormField(
                      controller: _buyPriceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Prix d\'achat (TND)',
                        prefixIcon: Icon(Icons.arrow_downward, color: Colors.blue),
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) {
                        if (val != null && val.isNotEmpty) {
                          final p = double.tryParse(val.replaceAll(',', '.'));
                          if (p == null || p < 0) return 'Prix invalide';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Sell Price
                  Expanded(
                    child: TextFormField(
                      controller: _sellPriceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Prix de vente (TND) *',
                        prefixIcon: Icon(Icons.arrow_upward, color: Colors.green),
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) {
                          return 'Obligatoire';
                        }
                        final p = double.tryParse(val.replaceAll(',', '.'));
                        if (p == null || p < 0) return 'Prix invalide';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Section: Stock initial & Alertes
              Text(
                'Stock initial & Alertes',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  // Initial Quantity
                  Expanded(
                    child: TextFormField(
                      controller: _quantityController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Stock initial *',
                        suffixText: _selectedUnit.name,
                        prefixIcon: const Icon(Icons.inventory),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) {
                          return 'Obligatoire';
                        }
                        final q = double.tryParse(val.replaceAll(',', '.'));
                        if (q == null || q < 0) return 'Quantité invalide';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Low Stock Threshold
                  Expanded(
                    child: TextFormField(
                      controller: _lowStockController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Seuil stock bas *',
                        suffixText: _selectedUnit.name,
                        prefixIcon: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) {
                          return 'Obligatoire';
                        }
                        final s = double.tryParse(val.replaceAll(',', '.'));
                        if (s == null || s < 0) return 'Seuil invalide';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: Text(
                    _isSubmitting ? 'Enregistrement...' : 'Enregistrer le produit',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
