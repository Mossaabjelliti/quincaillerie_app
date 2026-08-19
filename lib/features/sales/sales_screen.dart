import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' hide Column;
import '../../data/local/database.dart';
import '../../services/pdf_receipt_service.dart';

class SalesScreen extends StatefulWidget {
  final String storeId;
  final bool canViewFinancials;

  const SalesScreen({super.key, required this.storeId, required this.canViewFinancials});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  PaymentMethod? _filterMethod;

  String _getPaymentLabel(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cash:
        return 'Espèces';
      case PaymentMethod.check:
        return 'Chèque';
      case PaymentMethod.credit:
        return 'Crédit / Ardoise';
    }
  }

  Color _getPaymentColor(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cash:
        return Colors.green;
      case PaymentMethod.check:
        return Colors.blue;
      case PaymentMethod.credit:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.canViewFinancials) {
      return Scaffold(
        appBar: AppBar(title: const Text('Historique des ventes')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Accès restreint: votre rôle ne permet pas de consulter les ventes.'),
          ),
        ),
      );
    }

    final db = context.watch<AppDatabase>();
    final theme = Theme.of(context);
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique des ventes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Scanner / Nouvelle vente',
            onPressed: () => Navigator.of(context).pushNamed('/scanner'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('Toutes'),
                    selected: _filterMethod == null,
                    onSelected: (selected) {
                      if (selected) setState(() => _filterMethod = null);
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Espèces'),
                    selected: _filterMethod == PaymentMethod.cash,
                    onSelected: (selected) {
                      setState(() => _filterMethod = selected ? PaymentMethod.cash : null);
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Chèque'),
                    selected: _filterMethod == PaymentMethod.check,
                    onSelected: (selected) {
                      setState(() => _filterMethod = selected ? PaymentMethod.check : null);
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Crédit / Ardoise'),
                    selected: _filterMethod == PaymentMethod.credit,
                    onSelected: (selected) {
                      setState(() => _filterMethod = selected ? PaymentMethod.credit : null);
                    },
                  ),
                ],
              ),
            ),
          ),

          // Sales List Stream
          Expanded(
            child: StreamBuilder<List<Sale>>(
              stream: (db.select(db.sales)
                    ..where((s) => s.storeId.equals(widget.storeId))
                    ..orderBy([(s) => OrderingTerm.desc(s.createdAt)]))
                  .watch(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final sales = snapshot.data ?? [];
                final filtered = _filterMethod == null
                    ? sales
                    : sales.where((s) => s.paymentMethod == _filterMethod).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 64,
                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Aucune vente trouvée',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => Navigator.of(context).pushNamed('/scanner'),
                          icon: const Icon(Icons.qr_code_scanner),
                          label: const Text('Nouvelle vente (Scanner)'),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) {
                    final sale = filtered[i];
                    final paymentLabel = _getPaymentLabel(sale.paymentMethod);
                    final paymentColor = _getPaymentColor(sale.paymentMethod);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ExpansionTile(
                        leading: CircleAvatar(
                          backgroundColor: paymentColor.withValues(alpha: 0.2),
                          child: Icon(Icons.point_of_sale, color: paymentColor),
                        ),
                        title: Text(
                          'Vente #${sale.id.substring(0, 8)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${dateFormat.format(sale.createdAt)} • $paymentLabel',
                        ),
                        trailing: Text(
                          '${sale.total.toStringAsFixed(3)} TND',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        children: [
                          FutureBuilder<List<SaleItem>>(
                            future: (db.select(db.saleItems)
                                  ..where((item) => item.saleId.equals(sale.id)))
                                .get(),
                            builder: (context, itemSnapshot) {
                              if (!itemSnapshot.hasData) {
                                return const Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Center(child: CircularProgressIndicator()),
                                );
                              }

                              final items = itemSnapshot.data!;
                              return Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Articles vendus:',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 8),
                                    ...items.map((item) => Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              FutureBuilder<Product?>(
                                                future: (db.select(db.products)
                                                      ..where((p) => p.id.equals(item.productId)))
                                                    .getSingleOrNull(),
                                                builder: (ctx, prodSnap) {
                                                  final prodName = prodSnap.data?.name ?? 'Produit #${item.productId.substring(0, 6)}';
                                                  return Text(
                                                    '${item.quantity} x $prodName',
                                                    style: const TextStyle(fontSize: 14),
                                                  );
                                                },
                                              ),
                                              Text(
                                                '${item.subtotal.toStringAsFixed(3)} TND',
                                                style: const TextStyle(fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                        )),
                                     const SizedBox(height: 12),
                                     FutureBuilder<Invoice?>(
                                       future: (db.select(db.invoices)..where((inv) => inv.saleId.equals(sale.id))).getSingleOrNull(),
                                       builder: (ctx, invSnap) {
                                         final invoice = invSnap.data;
                                         final invoiceNumber = invoice?.invoiceNumber;
                                         return Column(
                                           crossAxisAlignment: CrossAxisAlignment.start,
                                           children: [
                                             if (invoiceNumber != null) ...[
                                               Container(
                                                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                 decoration: BoxDecoration(
                                                   color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                                                   borderRadius: BorderRadius.circular(6),
                                                 ),
                                                 child: Row(
                                                   mainAxisSize: MainAxisSize.min,
                                                   children: [
                                                     Icon(Icons.receipt_outlined, size: 16, color: theme.colorScheme.primary),
                                                     const SizedBox(width: 6),
                                                     Text(
                                                       'Facture: $invoiceNumber',
                                                       style: TextStyle(
                                                         fontWeight: FontWeight.bold,
                                                         fontSize: 12,
                                                         color: theme.colorScheme.primary,
                                                       ),
                                                     ),
                                                   ],
                                                 ),
                                               ),
                                               const SizedBox(height: 10),
                                             ],
                                             Row(
                                               children: [
                                                 Expanded(
                                                   child: OutlinedButton.icon(
                                                     icon: const Icon(Icons.receipt_long_outlined, size: 18),
                                                     label: const Text('Ticket (80mm)'),
                                                     onPressed: () async {
                                                       final products = await db.allProducts(widget.storeId);
                                                       Customer? customer;
                                                       if (sale.customerId.isNotEmpty) {
                                                         customer = await (db.select(db.customers)..where((c) => c.id.equals(sale.customerId))).getSingleOrNull();
                                                       }
                                                       final store = await (db.select(db.stores)..where((s) => s.id.equals(widget.storeId))).getSingleOrNull();
                                                       await PdfReceiptService.printReceipt(
                                                         sale: sale,
                                                         items: items,
                                                         products: products,
                                                         storeName: store?.name ?? 'QUINCAILLERIE PRO',
                                                         customerName: customer?.name,
                                                       );
                                                     },
                                                   ),
                                                 ),
                                                 const SizedBox(width: 8),
                                                 Expanded(
                                                   child: FilledButton.tonalIcon(
                                                     icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                                                     label: const Text('Facture A4'),
                                                     onPressed: () async {
                                                       final products = await db.allProducts(widget.storeId);
                                                       Customer? customer;
                                                       if (sale.customerId.isNotEmpty) {
                                                         customer = await (db.select(db.customers)..where((c) => c.id.equals(sale.customerId))).getSingleOrNull();
                                                       }
                                                       final store = await (db.select(db.stores)..where((s) => s.id.equals(widget.storeId))).getSingleOrNull();
                                                       await PdfReceiptService.printA4Invoice(
                                                         sale: sale,
                                                         items: items,
                                                         products: products,
                                                         storeName: store?.name ?? 'QUINCAILLERIE PRO',
                                                         storePhone: store?.phone ?? '',
                                                         storeAddress: store?.address ?? '',
                                                         customerName: customer?.name,
                                                         customerPhone: customer?.phone,
                                                         invoiceNumber: invoiceNumber,
                                                       );
                                                     },
                                                   ),
                                                 ),
                                               ],
                                             ),
                                           ],
                                         );
                                       },
                                     ),
                                   ],
                                 ),
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
  }
}
