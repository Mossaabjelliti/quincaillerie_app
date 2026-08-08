import 'package:drift/drift.dart' hide Column, Table;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/local/database.dart';
import '../cart/cart_provider.dart';
import '../cart/cart_screen.dart';

/// Keyboard-first POS surface for USB barcode scanners on Windows.
class DesktopPosScreen extends StatefulWidget {
  final String storeId;
  final String userId;
  const DesktopPosScreen({super.key, required this.storeId, required this.userId});
  @override State<DesktopPosScreen> createState() => _DesktopPosScreenState();
}

class _DesktopPosScreenState extends State<DesktopPosScreen> {
  final _query = TextEditingController();
  final _focus = FocusNode();
  List<Product> _matches = [];

  @override void initState() { super.initState(); WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus()); }
  @override void dispose() { _query.dispose(); _focus.dispose(); super.dispose(); }

  Future<void> _search([String? value]) async {
    final term = (value ?? _query.text).trim();
    if (term.isEmpty) return;
    final db = context.read<AppDatabase>();
    final rows = await (db.select(db.products)
          ..where((p) => p.storeId.equals(widget.storeId))
          ..where((p) => p.barcode.equals(term) | p.name.like('%$term%'))
          ..limit(20))
        .get();
    if (!mounted) return;
    if (rows.length == 1 && rows.first.barcode == term) { _add(rows.first); return; }
    setState(() => _matches = rows);
  }

  void _add(Product product) {
    context.read<CartProvider>().addItem(product);
    _query.clear(); setState(() => _matches = []); _focus.requestFocus();
  }

  @override Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(children: [
        Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Point de vente', style: Theme.of(context).textTheme.headlineSmall), const SizedBox(height: 16),
          TextField(controller: _query, focusNode: _focus, onSubmitted: _search, decoration: InputDecoration(prefixIcon: const Icon(Icons.qr_code_scanner), labelText: 'Scanner ou rechercher un produit', hintText: 'Code-barres, nom…  (Entrée pour ajouter)', border: const OutlineInputBorder(), suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: _search))),
          const SizedBox(height: 12),
          Expanded(child: _matches.isEmpty ? const Center(child: Text('Scannez un article ou saisissez une recherche.')) : ListView.separated(itemCount: _matches.length, separatorBuilder: (_, __) => const Divider(), itemBuilder: (_, index) { final product = _matches[index]; return ListTile(title: Text(product.name), subtitle: Text('${product.barcode} • Stock ${product.quantity}'), trailing: Text('${product.sellPrice.toStringAsFixed(3)} TND'), onTap: () => _add(product)); })),
        ])),
        const SizedBox(width: 24), SizedBox(width: 380, child: Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Panier', style: Theme.of(context).textTheme.titleLarge), const Divider(),
          Expanded(child: cart.isEmpty ? const Center(child: Text('Panier vide')) : ListView.builder(itemCount: cart.items.length, itemBuilder: (_, index) { final item = cart.items[index]; return ListTile(dense: true, title: Text(item.product.name), subtitle: Text('${item.quantity} × ${item.product.sellPrice.toStringAsFixed(3)}'), trailing: IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: () => cart.removeItem(item.product.id))); })),
          const Divider(), Text('${cart.totalAmount.toStringAsFixed(3)} TND', textAlign: TextAlign.right, style: Theme.of(context).textTheme.headlineSmall), const SizedBox(height: 12),
          FilledButton.icon(onPressed: cart.isEmpty ? null : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CartScreen(storeId: widget.storeId, userId: widget.userId))), icon: const Icon(Icons.point_of_sale), label: const Text('Encaisser')),
        ])))),
      ]),
    );
  }
}
