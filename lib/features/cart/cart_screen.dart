import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:drift/drift.dart' hide Column;
import '../../data/local/database.dart';
import '../../services/pdf_receipt_service.dart';
import '../../core/licensing/license_service.dart';
import '../../core/auth/authorization_service.dart';
import '../../core/auth/permission.dart';
import 'cart_provider.dart';

class CartScreen extends StatefulWidget {
  final String storeId;
  final String userId;

  const CartScreen({
    super.key,
    required this.storeId,
    required this.userId,
  });

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  PaymentMethod _paymentMethod = PaymentMethod.cash;
  bool _isProcessing = false;
  bool _regularPricing = false;

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

  String _getPaymentMethodLabel(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cash:
        return 'Espèces';
      case PaymentMethod.check:
        return 'Chèque';
      case PaymentMethod.credit:
        return 'Crédit / Ardoise';
    }
  }

  Future<void> _showQuantityEditDialog(CartItem item) async {
    final controller = TextEditingController(text: item.quantity.toString());
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Quantité — ${item.product.name}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Quantité (${_getUnitSuffix(item.product.unit)})',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(controller.text.replaceAll(',', '.'));
              if (val != null && val > 0) {
                Navigator.pop(ctx, val);
              }
            },
            child: const Text('Valider'),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      context.read<CartProvider>().updateQuantity(item.product.id, result);
    }
  }

  Future<void> _handleCheckout() async {
    final authz = context.read<AuthorizationService>();
    if (!authz.can(Permission.salesCreate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Accès restreint: permission insuffisante pour enregistrer une vente.')),
      );
      return;
    }

    final cart = context.read<CartProvider>();
    if (cart.isEmpty) return;
    if (!context.read<LicenseService>().state.entitlements.canCreateCommercialOperations) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mode restreint : le renouvellement est requis pour les nouvelles ventes.')));
      return;
    }
    if (_paymentMethod == PaymentMethod.credit && cart.customerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choisissez un client avant une vente à crédit.')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final db = context.read<AppDatabase>();
      final total = cart.totalAmount;
      final methodLabel = _getPaymentMethodLabel(_paymentMethod);

      final success = await cart.checkout(
        db: db,
        storeId: widget.storeId,
        userId: widget.userId,
        paymentMethod: _paymentMethod,
        customerId: cart.customerId,
        customerName: cart.customerName,
        priceMultiplier: _regularPricing ? 0.95 : 1.0,
      );

      if (!mounted) return;

      if (success) {
        // Fetch last created sale for print
        final latestSales = await (db.select(db.sales)
              ..where((s) => s.storeId.equals(widget.storeId))
              ..orderBy([(s) => OrderingTerm.desc(s.createdAt)]))
            .get();
        final latestSale = latestSales.firstOrNull;

        if (!mounted) return;

        final saleItems = latestSale == null
            ? <SaleItem>[]
            : await (db.select(db.saleItems)..where((item) => item.saleId.equals(latestSale.id))).get();

        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: const Icon(Icons.check_circle, color: Colors.green, size: 56),
            title: const Text('Vente enregistrée !'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Montant total: ${total.toStringAsFixed(3)} TND\nMode de paiement: $methodLabel',
                  textAlign: TextAlign.center,
                ),
                if (cart.customerName != null) ...[
                  const SizedBox(height: 8),
                  Text('Client: ${cart.customerName}', textAlign: TextAlign.center),
                ],
                if (latestSale != null) ...[
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.print_outlined),
                    label: const Text('Imprimer le reçu (PDF)'),
                    onPressed: () async {
                      final products = await db.allProducts(widget.storeId);
                      await PdfReceiptService.printReceipt(
                        sale: latestSale,
                        items: saleItems,
                        products: products,
                        customerName: cart.customerName,
                      );
                    },
                  ),
                ],
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                },
                child: const Text('Nouvelle vente'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la validation de la vente: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panier & Caisse'),
        actions: [
          if (!cart.isEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Vider le panier',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Vider le panier ?'),
                    content: const Text('Tous les articles seront retirés.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Annuler'),
                      ),
                      TextButton(
                        onPressed: () {
                          cart.clear();
                          Navigator.pop(ctx);
                        },
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        child: const Text('Vider'),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: cart.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.shopping_cart_outlined,
                      size: 80,
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Votre panier est vide',
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Scannez un code-barres ou saisissez un produit pour l\'ajouter au panier.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Card(
                    child: ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: Text(cart.customerName ?? 'Client passage'),
                      subtitle: Text(
                        _regularPricing ? 'Tarif régulier appliqué' : 'Tarif passage appliqué',
                      ),
                      trailing: Wrap(
                        spacing: 8,
                        children: [
                          TextButton(
                            onPressed: () => _showCustomerPicker(cart),
                            child: Text(cart.customerId == null ? 'Choisir client' : 'Changer'),
                          ),
                          Switch(
                            value: _regularPricing,
                            onChanged: (value) {
                              setState(() => _regularPricing = value);
                              cart.setCustomer(
                                customerId: cart.customerId,
                                customerName: cart.customerName,
                                priceMultiplier: value ? 0.95 : 1.0,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: cart.items.length,
                    separatorBuilder: (ctx, i) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final item = cart.items[i];

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.product.name,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.primaryContainer,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          item.unitLabel.toUpperCase(),
                                          style: theme.textTheme.labelSmall?.copyWith(
                                            color: theme.colorScheme.onPrimaryContainer,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${(item.effectiveUnitPrice * (_regularPricing ? 0.95 : 1.0)).toStringAsFixed(3)} TND / ${item.unitLabel}',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, size: 20),
                                  onPressed: () {
                                    cart.updateQuantity(
                                      item.product.id,
                                      item.quantity - 1.0,
                                    );
                                  },
                                ),
                                InkWell(
                                  onTap: () => _showQuantityEditDialog(item),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: theme.colorScheme.outline.withValues(alpha: 0.5),
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${item.quantity} ${item.unitLabel}',
                                      style: theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline, size: 20),
                                  onPressed: () {
                                    cart.updateQuantity(
                                      item.product.id,
                                      item.quantity + 1.0,
                                    );
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${(item.subtotal * (_regularPricing ? 0.95 : 1.0)).toStringAsFixed(3)} TND',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 18, color: Colors.red),
                                  onPressed: () => cart.removeItem(item.product.id),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mode de paiement',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SegmentedButton<PaymentMethod>(
                        segments: const [
                          ButtonSegment(
                            value: PaymentMethod.cash,
                            label: Text('Espèces'),
                            icon: Icon(Icons.payments_outlined, size: 18),
                          ),
                          ButtonSegment(
                            value: PaymentMethod.check,
                            label: Text('Chèque'),
                            icon: Icon(Icons.article_outlined, size: 18),
                          ),
                          ButtonSegment(
                            value: PaymentMethod.credit,
                            label: Text('Crédit'),
                            icon: Icon(Icons.account_balance_wallet_outlined, size: 18),
                          ),
                        ],
                        selected: {_paymentMethod},
                        onSelectionChanged: (set) {
                          setState(() => _paymentMethod = set.first);
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total à payer',
                            style: theme.textTheme.titleLarge,
                          ),
                          Text(
                            '${cart.totalAmount.toStringAsFixed(3)} TND',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: _isProcessing ? null : _handleCheckout,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: theme.colorScheme.onPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: _isProcessing
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check_circle),
                          label: Text(
                            _isProcessing
                                ? 'Enregistrement...' : 'Valider la vente (${cart.totalAmount.toStringAsFixed(3)} TND)',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

        Future<void> _showCustomerPicker(CartProvider cart) async {
          final db = context.read<AppDatabase>();
          final customers = await (db.select(db.customers)..where((c) => c.storeId.equals(widget.storeId))).get();

          if (!mounted) return;

          final selected = await showModalBottomSheet<Customer?>(
            context: context,
            isScrollControlled: true,
            builder: (ctx) => SafeArea(
              child: ListView(
                shrinkWrap: true,
                children: [
                  ListTile(
                    leading: const Icon(Icons.person_off_outlined),
                    title: const Text('Client passage'),
                    onTap: () => Navigator.pop(ctx, null),
                  ),
                  ...customers.map(
                    (customer) => ListTile(
                      leading: const Icon(Icons.person),
                      title: Text(customer.name),
                      subtitle: Text(customer.phone.isNotEmpty ? customer.phone : 'Sans numéro'),
                      onTap: () => Navigator.pop(ctx, customer),
                    ),
                  ),
                ],
              ),
            ),
          );

          if (!mounted) return;
          if (selected == null) {
            cart.setCustomer(customerId: null, customerName: null, priceMultiplier: _regularPricing ? 0.95 : 1.0);
            return;
          }

          cart.setCustomer(
            customerId: selected.id,
            customerName: selected.name,
            priceMultiplier: _regularPricing ? 0.95 : 1.0,
          );
        }
}
