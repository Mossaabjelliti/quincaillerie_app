import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' hide Column;
import '../../data/local/database.dart';

class CartItem {
  final Product product;
  double quantity;

  CartItem({
    required this.product,
    this.quantity = 1.0,
  });

  double get subtotal => product.sellPrice * quantity;
}

/// Manages active shopping cart state and handles checkout database transactions.
class CartProvider extends ChangeNotifier {
  final Map<String, CartItem> _items = {};

  List<CartItem> get items => _items.values.toList();

  int get itemCount => _items.length;

  double get totalQuantity =>
      _items.values.fold(0.0, (sum, item) => sum + item.quantity);

  double get totalAmount =>
      _items.values.fold(0.0, (sum, item) => sum + item.subtotal);

  bool get isEmpty => _items.isEmpty;

  CartItem? getItem(String productId) => _items[productId];

  void addItem(Product product, [double quantity = 1.0]) {
    if (_items.containsKey(product.id)) {
      _items[product.id]!.quantity += quantity;
    } else {
      _items[product.id] = CartItem(
        product: product,
        quantity: quantity,
      );
    }
    notifyListeners();
  }

  void updateQuantity(String productId, double quantity) {
    if (!_items.containsKey(productId)) return;

    if (quantity <= 0) {
      _items.remove(productId);
    } else {
      _items[productId]!.quantity = quantity;
    }
    notifyListeners();
  }

  void removeItem(String productId) {
    _items.remove(productId);
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }

  /// Complete sale checkout and perform atomic local SQLite updates:
  /// 1. Create 1 Sale row
  /// 2. Create SaleItem rows for each item
  /// 3. Create StockMovement (stockOut) rows
  /// 4. Reduce Product stock quantity
  Future<bool> checkout({
    required AppDatabase db,
    required String storeId,
    required String userId,
    required PaymentMethod paymentMethod,
  }) async {
    if (_items.isEmpty) return false;

    const uuid = Uuid();
    final saleId = uuid.v4();
    final now = DateTime.now();
    final currentItems = List<CartItem>.from(_items.values);
    final total = totalAmount;

    await db.transaction(() async {
      // 1. Insert Sale record
      await db.into(db.sales).insert(
            SalesCompanion.insert(
              id: saleId,
              storeId: storeId,
              userId: userId,
              total: total,
              paymentMethod: paymentMethod,
              createdAt: Value(now),
              synced: const Value(false),
            ),
          );

      for (final item in currentItems) {
        final saleItemId = uuid.v4();
        final movementId = uuid.v4();

        // 2. Insert SaleItem record
        await db.into(db.saleItems).insert(
              SaleItemsCompanion.insert(
                id: saleItemId,
                saleId: saleId,
                productId: item.product.id,
                quantity: item.quantity,
                unitPrice: item.product.sellPrice,
                subtotal: item.subtotal,
              ),
            );

        // 3. Insert StockMovement record (stockOut)
        await db.into(db.stockMovements).insert(
              StockMovementsCompanion.insert(
                id: movementId,
                productId: item.product.id,
                storeId: storeId,
                userId: userId,
                type: MovementType.stockOut,
                quantity: item.quantity,
                note: Value('Vente #${saleId.substring(0, 8)}'),
                createdAt: Value(now),
                synced: const Value(false),
              ),
            );

        // 4. Update Product stock level
        final newQuantity = item.product.quantity - item.quantity;
        await (db.update(db.products)
              ..where((p) => p.id.equals(item.product.id)))
            .write(
          ProductsCompanion(
            quantity: Value(newQuantity),
            updatedAt: Value(now),
            synced: const Value(false),
          ),
        );
      }
    });

    clear();
    return true;
  }
}
