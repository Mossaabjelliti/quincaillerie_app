import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' hide Column;
import '../../data/local/database.dart';
import '../../core/device_identity.dart';
import '../../core/inventory/stock_engine.dart';

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
  String? _customerId;
  String? _customerName;
  double _priceMultiplier = 1.0;

  List<CartItem> get items => _items.values.toList();

  int get itemCount => _items.length;

  double get totalQuantity =>
      _items.values.fold(0.0, (sum, item) => sum + item.quantity);

  double get totalAmount =>
      _items.values.fold(0.0, (sum, item) => sum + (item.subtotal * _priceMultiplier));

    String? get customerId => _customerId;
    String? get customerName => _customerName;
    double get priceMultiplier => _priceMultiplier;

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
    _customerId = null;
    _customerName = null;
    _priceMultiplier = 1.0;
    notifyListeners();
  }

  void setCustomer({String? customerId, String? customerName, double priceMultiplier = 1.0}) {
    _customerId = customerId;
    _customerName = customerName;
    _priceMultiplier = priceMultiplier;
    notifyListeners();
  }

  /// Complete sale checkout and perform atomic local SQLite updates:
  /// 1. Create 1 Sale row
  /// 2. Create SaleItem rows for each item
  /// 3. Create StockMovement (stockOut) rows
  /// 4. Record stock movements. Product.quantity is rebuilt afterwards as a cache.
  Future<bool> checkout({
    required AppDatabase db,
    required String storeId,
    required String userId,
    required PaymentMethod paymentMethod,
    String? customerId,
    String? customerName,
    double priceMultiplier = 1.0,
  }) async {
    if (_items.isEmpty) return false;
    if (paymentMethod == PaymentMethod.credit && (customerId == null || customerId.isEmpty)) {
      return false;
    }

    const uuid = Uuid();
    final saleId = uuid.v4();
    final now = DateTime.now();
    final currentItems = List<CartItem>.from(_items.values);
    final total = _items.values.fold<double>(0.0, (sum, item) => sum + (item.product.sellPrice * item.quantity * priceMultiplier));
    final effectiveCustomerId = customerId ?? _customerId;
    final effectiveCustomerName = customerName ?? _customerName;
    final deviceId = await DeviceIdentity.id;

    await db.transaction(() async {
      // 1. Insert Sale record
      await db.into(db.sales).insert(
            SalesCompanion.insert(
              id: saleId,
              storeId: storeId,
              userId: userId,
              customerId: effectiveCustomerId != null ? Value(effectiveCustomerId) : const Value.absent(),
              total: total,
              paymentMethod: paymentMethod,
              createdAt: Value(now),
              synced: const Value(false),
            ),
          );

      for (final item in currentItems) {
        final saleItemId = uuid.v4();
        final movementId = uuid.v4();
        final unitPrice = item.product.sellPrice * priceMultiplier;

        // 2. Insert SaleItem record
        await db.into(db.saleItems).insert(
              SaleItemsCompanion.insert(
                id: saleItemId,
                saleId: saleId,
                productId: item.product.id,
                quantity: item.quantity,
                unitPrice: unitPrice,
                subtotal: unitPrice * item.quantity,
              ),
            );

        // 3. Insert the immutable inventory event.
        await db.into(db.stockMovements).insert(
              StockMovementsCompanion.insert(
                id: movementId,
                productId: item.product.id,
                storeId: storeId,
                userId: userId,
                deviceId: Value(deviceId),
                type: MovementType.sale,
                quantity: item.quantity,
                note: Value('Vente #${saleId.substring(0, 8)}'),
                createdAt: Value(now),
                synced: const Value(false),
              ),
            );

      }

      if (paymentMethod == PaymentMethod.credit && effectiveCustomerId != null) {
        final debtId = uuid.v4();
        await db.into(db.customerDebts).insert(
              CustomerDebtsCompanion.insert(
                id: debtId,
                storeId: storeId,
                customerId: effectiveCustomerId,
                saleId: Value(saleId),
                totalAmount: total,
                paidAmount: const Value(0.0),
                remainingAmount: total,
                dueDate: const Value.absent(),
                status: const Value('UNPAID'),
                createdAt: Value(now),
                synced: const Value(false),
              ),
            );

        if (effectiveCustomerName != null) {
          await (db.update(db.sales)..where((row) => row.id.equals(saleId))).write(
            SalesCompanion(customerId: Value(effectiveCustomerId)),
          );
        }
      }

      // The cache participates in the same commit as the sale. If this fails,
      // the business transaction rolls back instead of looking failed after a
      // sale has already been committed.
      final stockEngine = StockEngine(db: db);
      for (final item in currentItems) {
        await stockEngine.reconcileProductCache(storeId, item.product.id);
      }
    });

    clear();
    return true;
  }
}
