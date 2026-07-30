import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../data/local/database.dart';

class StockEngine {
  final AppDatabase db;

  StockEngine({required this.db});

  /// Record an inventory movement (Event Sourcing pattern)
  Future<String> recordMovement({
    required String storeId,
    required String productId,
    required String userId,
    required MovementType type,
    required double quantity,
    required String deviceId,
    String note = '',
  }) async {
    const uuid = Uuid();
    final movementId = uuid.v4();
    final now = DateTime.now();

    await db.into(db.stockMovements).insert(
          StockMovementsCompanion.insert(
            id: movementId,
            productId: productId,
            storeId: storeId,
            userId: userId,
            deviceId: Value(deviceId),
            type: type,
            quantity: quantity,
            note: Value(note),
            createdAt: Value(now),
            synced: const Value(false),
          ),
        );

    // Also update product cached stock level for fast local querying
    final currentStock = await calculateProductStock(storeId, productId);
    await (db.update(db.products)..where((p) => p.id.equals(productId))).write(
      ProductsCompanion(
        quantity: Value(currentStock),
        updatedAt: Value(now),
        synced: const Value(false),
      ),
    );

    return movementId;
  }

  /// Calculates real-time stock balance strictly by aggregating all movements.
  /// Current Stock = SUM(PURCHASE/stockIn/returnItem) - SUM(SALE/stockOut) + SUM(ADJUSTMENT)
  Future<double> calculateProductStock(String storeId, String productId) async {
    final movements = await (db.select(db.stockMovements)
          ..where((m) => m.storeId.equals(storeId) & m.productId.equals(productId)))
        .get();

    double total = 0.0;
    for (final m in movements) {
      switch (m.type) {
        case MovementType.stockIn:
        case MovementType.purchase:
        case MovementType.returnItem:
          total += m.quantity;
          break;
        case MovementType.stockOut:
        case MovementType.sale:
          total -= m.quantity;
          break;
        case MovementType.adjustment:
          total += m.quantity; // Adjustment can be positive or negative
          break;
      }
    }
    return total;
  }

  /// Get movement history audit log for a product
  Future<List<StockMovement>> getProductHistory(String storeId, String productId) async {
    return (db.select(db.stockMovements)
          ..where((m) => m.storeId.equals(storeId) & m.productId.equals(productId))
          ..orderBy([(m) => OrderingTerm.desc(m.createdAt)]))
        .get();
  }

  /// Recalculate and repair cached quantities for all products in a store
  Future<void> reconcileStoreStock(String storeId) async {
    final products = await db.allProducts(storeId);
    final now = DateTime.now();

    for (final p in products) {
      final stock = await calculateProductStock(storeId, p.id);
      if (p.quantity != stock) {
        await (db.update(db.products)..where((row) => row.id.equals(p.id))).write(
          ProductsCompanion(
            quantity: Value(stock),
            updatedAt: Value(now),
            synced: const Value(false),
          ),
        );
      }
    }
  }
}
