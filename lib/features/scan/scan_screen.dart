import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../data/local/database.dart';
import '../../core/inventory/stock_engine.dart';
import '../cart/cart_provider.dart';

class ScanScreen extends StatefulWidget {
  final String storeId;
  final String userId;
  final bool canManageStock;

  const ScanScreen({
    super.key,
    required this.storeId,
    required this.userId,
    required this.canManageStock,
  });

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool _handling = false;
  bool _isTorchOn = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleBarcode(String rawCode) async {
    final code = rawCode.trim();
    if (code.isEmpty || _handling) return;

    setState(() => _handling = true);

    try {
      final db = context.read<AppDatabase>();
      final product = await (db.select(db.products)
            ..where((p) => p.barcode.equals(code))
            ..where((p) => p.storeId.equals(widget.storeId)))
          .getSingleOrNull();

      if (!mounted) return;

      if (product == null) {
        if (widget.canManageStock) {
          await Navigator.of(context).pushNamed('/add-product', arguments: code);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Produit inconnu. Demandez à un responsable de l’ajouter.')),
          );
        }
      } else {
        await _showMovementDialog(product);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de scan: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _handling = false);
      }
    }
  }

  Future<void> _showMovementDialog(Product product) async {
    final qtyController = TextEditingController(text: '1');

    // Load available unit conversions and variants for this product.
    final db = context.read<AppDatabase>();
    final units = await (db.select(db.productUnitConversions)
          ..where((u) => u.productId.equals(product.id)))
        .get();
    final variants = await (db.select(db.productVariants)
          ..where((v) => v.productId.equals(product.id)))
        .get();

    if (!mounted) return;

    ProductUnitConversion? selectedUnit;
    ProductVariant? selectedVariant;

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final displayPrice = selectedVariant?.sellPrice ??
              selectedUnit?.sellingPrice ??
              product.sellPrice;
          final displayUnit = selectedVariant?.variantName ??
              selectedUnit?.unitName ??
              product.unit.name;

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.qr_code_2_rounded, color: Colors.amber.shade900),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name,
                              style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Code: ${product.barcode} | Unit: ${product.unit.name}',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blueGrey.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Stock: ${product.quantity} ${product.unit.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('${displayPrice.toStringAsFixed(3)} TND', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade800, fontSize: 16)),
                      ],
                    ),
                  ),
                  if (units.isNotEmpty || variants.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    if (units.isNotEmpty)
                      DropdownButtonFormField<ProductUnitConversion>(
                        initialValue: selectedUnit,
                        decoration: const InputDecoration(
                          labelText: 'Unité de vente',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.straighten),
                        ),
                        items: units.map((u) {
                          return DropdownMenuItem<ProductUnitConversion>(
                            value: u,
                            child: Text('${u.unitName} (${u.conversionFactor} pc) — ${u.sellingPrice.toStringAsFixed(3)} TND'),
                          );
                        }).toList(),
                        onChanged: (val) => setModalState(() => selectedUnit = val),
                      ),
                    if (variants.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<ProductVariant>(
                        initialValue: selectedVariant,
                        decoration: const InputDecoration(
                          labelText: 'Variante',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.category_outlined),
                        ),
                        items: variants.map((v) {
                          return DropdownMenuItem<ProductVariant>(
                            value: v,
                            child: Text('${v.variantName} — ${v.sellPrice.toStringAsFixed(3)} TND'),
                          );
                        }).toList(),
                        onChanged: (val) => setModalState(() => selectedVariant = val),
                      ),
                    ],
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    controller: qtyController,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Quantité ($displayUnit)',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.numbers_rounded),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add_shopping_cart_rounded),
                    label: const Text('Ajouter au panier (Vente)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.pop(ctx, {
                      'action': 'cart',
                      'qty': double.tryParse(qtyController.text) ?? 1.0,
                      'unit': selectedUnit,
                      'variant': selectedVariant,
                    }),
                  ),
                  const SizedBox(height: 10),
                  if (widget.canManageStock) ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.call_received),
                            label: const Text('Entrée (achat)'),
                            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                            onPressed: () => Navigator.pop(ctx, {
                              'action': 'movement',
                              'type': MovementType.stockIn,
                              'qty': double.tryParse(qtyController.text) ?? 1.0,
                            }),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.call_made),
                            label: const Text('Sortie directe'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.orange.shade800,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () => Navigator.pop(ctx, {
                              'action': 'movement',
                              'type': MovementType.stockOut,
                              'qty': double.tryParse(qtyController.text) ?? 1.0,
                            }),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );

    if (result == null || !mounted) return;

    if (result['action'] == 'cart') {
      final qty = result['qty'] as double;
      if (qty > 0) {
        final unit = result['unit'] as ProductUnitConversion?;
        final variant = result['variant'] as ProductVariant?;
        context.read<CartProvider>().addItem(product, qty, unit, variant);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${product.name} ($qty) ajouté au panier'),
            action: SnackBarAction(
              label: 'Panier',
              onPressed: () => Navigator.of(context).pushNamed('/cart'),
            ),
          ),
        );
      }
    } else if (result['action'] == 'movement') {
      await _recordMovement(product, result['type'] as MovementType, result['qty'] as double);
    }
  }

  Future<void> _recordMovement(Product product, MovementType type, double qty) async {
    if (qty <= 0) return;
    final db = context.read<AppDatabase>();
    await StockEngine(db: db).recordMovement(
      storeId: widget.storeId,
      productId: product.id,
      userId: widget.userId,
      type: type,
      quantity: qty,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${product.name}: mouvement de stock enregistré')),
    );
  }

  Future<void> _showManualEntryDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Saisie manuelle / Douchette Scanner'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Code-barres / Référence',
            hintText: 'ex: 619123456789',
            prefixIcon: Icon(Icons.qr_code),
            border: OutlineInputBorder(),
          ),
          onSubmitted: (val) {
            if (val.trim().isNotEmpty) {
              Navigator.pop(ctx, val.trim());
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(ctx, controller.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade700, foregroundColor: Colors.white),
            child: const Text('Valider'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      _handleBarcode(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scanner de Code-barres'),
        actions: [
          IconButton(
            icon: Icon(_isTorchOn ? Icons.flash_on : Icons.flash_off),
            tooltip: 'Flash',
            onPressed: () async {
              await _controller.toggleTorch();
              setState(() => _isTorchOn = !_isTorchOn);
            },
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch_outlined),
            tooltip: 'Changer de caméra',
            onPressed: () => _controller.switchCamera(),
          ),
          IconButton(
            icon: const Icon(Icons.keyboard),
            tooltip: 'Saisie manuelle',
            onPressed: _showManualEntryDialog,
          ),
          IconButton(
            icon: const Icon(Icons.add_box_outlined),
            tooltip: 'Nouveau produit',
            onPressed: widget.canManageStock ? () => Navigator.of(context).pushNamed('/add-product') : null,
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              final barcodes = capture.barcodes;
              if (barcodes.isNotEmpty) {
                final code = barcodes.first.rawValue ?? barcodes.first.displayValue;
                if (code != null && code.isNotEmpty) {
                  _handleBarcode(code);
                }
              }
            },
            errorBuilder: (context, error, child) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.camera_alt_outlined, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        kIsWeb
                            ? 'Caméra indisponible sur ce navigateur ou autorisation refusée.'
                            : 'Impossible d\'accéder à la caméra. Vérifiez les autorisations.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _showManualEntryDialog,
                        icon: const Icon(Icons.keyboard),
                        label: const Text('Utiliser la saisie manuelle / Douchette'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // Scanning Reticle Overlay
          Center(
            child: Container(
              width: 260,
              height: 180,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.amber, width: 3),
                borderRadius: BorderRadius.circular(16),
                color: Colors.transparent,
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.qr_code_scanner, color: Colors.amber, size: 40),
                  SizedBox(height: 8),
                  Text(
                    'Placez le code-barres ici',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, backgroundColor: Colors.black54),
                  ),
                ],
              ),
            ),
          ),

          // Cart Floating Footer
          if (cart.itemCount > 0)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(16),
                color: theme.colorScheme.primaryContainer,
                child: InkWell(
                  onTap: () => Navigator.of(context).pushNamed('/cart'),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Badge(
                          label: Text('${cart.itemCount}'),
                          child: Icon(
                            Icons.shopping_cart,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Panier en cours',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                                ),
                              ),
                              Text(
                                '${cart.totalAmount.toStringAsFixed(3)} TND',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => Navigator.of(context).pushNamed('/cart'),
                          icon: const Icon(Icons.arrow_forward),
                          label: const Text('Caisse'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: theme.colorScheme.onPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}