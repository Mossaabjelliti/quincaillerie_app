import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' hide Column;
import '../../data/local/database.dart';
import '../cart/cart_provider.dart';

/// The core daily workflow screen: scan a product's code, then log
/// stock IN (received from supplier) or OUT (sold).
///
/// Works with either the phone camera (mobile_scanner) OR a Bluetooth/USB
/// barcode gun in "keyboard wedge" mode — a physical scanner just types
/// the barcode into a focused TextField, so this screen also exposes a
/// manual/hardware-input fallback further down (see ManualEntryField).
class ScanScreen extends StatefulWidget {
  final String storeId;
  final String userId;

  const ScanScreen({super.key, required this.storeId, required this.userId});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _handling = false; // debounce: avoid double-firing on the same code

  Future<void> _handleBarcode(String code) async {
    if (_handling) return;
    setState(() => _handling = true);

    final db = context.read<AppDatabase>();
    final product = await (db.select(db.products)
          ..where((p) => (p.barcode.equals(code)) & (p.storeId.equals(widget.storeId))))
        .getSingleOrNull();

    if (!mounted) return;

    if (product == null) {
      // Unknown code -> offer to create a new product on the spot.
      await Navigator.of(context).pushNamed('/add-product', arguments: code);
    } else {
      await _showMovementDialog(product);
    }

    setState(() => _handling = false);
  }

  Future<void> _showMovementDialog(Product product) async {
    final qtyController = TextEditingController(text: '1');
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16, right: 16, top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              product.name,
              style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Stock disponible: ${product.quantity} ${product.unit.name} | Prix: ${product.sellPrice.toStringAsFixed(3)} TND',
              style: Theme.of(ctx).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: qtyController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Quantité (${product.unit.name})',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.add_shopping_cart),
              label: const Text('Ajouter au panier (Vente)', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.primary,
                foregroundColor: Theme.of(ctx).colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () => Navigator.pop(ctx, {
                'action': 'cart',
                'qty': double.tryParse(qtyController.text) ?? 1.0,
              }),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.call_received),
                    label: const Text('Entrée (achat)'),
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
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.orange.shade800),
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
        ),
      ),
    );

    if (result == null || !mounted) return;

    if (result['action'] == 'cart') {
      final qty = result['qty'] as double;
      if (qty > 0) {
        context.read<CartProvider>().addItem(product, qty);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${product.name} ($qty ${product.unit.name}) ajouté au panier'),
            action: SnackBarAction(
              label: 'Voir panier',
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
    const uuid = Uuid();

    final delta = type == MovementType.stockOut ? -qty : qty;
    final newQty = product.quantity + delta;

    await db.transaction(() async {
      await db.into(db.stockMovements).insert(StockMovementsCompanion.insert(
            id: uuid.v4(),
            productId: product.id,
            storeId: widget.storeId,
            userId: widget.userId,
            type: type,
            quantity: qty,
          ));

      await (db.update(db.products)..where((p) => p.id.equals(product.id))).write(
        ProductsCompanion(
          quantity: Value(newQty),
          updatedAt: Value(DateTime.now()),
          synced: const Value(false),
        ),
      );
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${product.name}: stock mis à jour ($newQty)')),
    );
  }

  Future<void> _showManualEntryDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Saisie manuelle du code-barres'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Code-barres / Référence',
            hintText: 'ex: 123456789',
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
        title: const Text('Scanner'),
        actions: [
          IconButton(
            icon: const Icon(Icons.keyboard),
            tooltip: 'Saisie manuelle du code',
            onPressed: _showManualEntryDialog,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Nouveau produit',
            onPressed: () => Navigator.of(context).pushNamed('/add-product'),
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart_outlined),
                tooltip: 'Panier',
                onPressed: () => Navigator.of(context).pushNamed('/cart'),
              ),
              if (cart.itemCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '${cart.itemCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              final barcode = capture.barcodes.firstOrNull?.rawValue;
              if (barcode != null) _handleBarcode(barcode);
            },
          ),
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
