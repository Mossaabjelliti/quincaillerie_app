import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart' show Value;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/local/database.dart';

enum SyncStatus { idle, syncing, success, failed, offline }

/// Offline-first sync strategy:
/// 1. The app NEVER waits on this service to function — all reads/writes
///    happen against the local Drift database instantly.
/// 2. This service's only job is to push rows where `synced = false`
///    up to Supabase, then mark them synced.
/// 3. Conflict resolution: last-write-wins at the row level. Good enough
///    for MVP since each store has one active device most of the time.
///    Revisit if/when multi-device-per-store becomes common (Phase 3).
class SyncService {
  final AppDatabase db;
  final SupabaseClient supabase;

  SyncStatus status = SyncStatus.idle;
  DateTime? lastSyncedAt;

  SyncService({required this.db, required this.supabase});

  Future<bool> _hasConnection() async {
    final result = await Connectivity().checkConnectivity();
    return result.any((r) => r != ConnectivityResult.none);
  }

  /// Call this from a button ("Synchroniser maintenant") or a daily
  /// background task (e.g. via WorkManager on Android).
  Future<SyncStatus> syncNow() async {
    if (!await _hasConnection()) {
      status = SyncStatus.offline;
      return status;
    }

    status = SyncStatus.syncing;
    try {
      await _pushProducts();
      await _pushStockMovements();
      await _pushSales();
      lastSyncedAt = DateTime.now();
      status = SyncStatus.success;
    } catch (e) {
      status = SyncStatus.failed;
      // In production: log to a local error table so it retries next time
      // and so support can see what failed without needing device access.
    }
    return status;
  }

  Future<void> _pushProducts() async {
    final unsynced = await db.unsyncedProducts();
    for (final product in unsynced) {
      await supabase.from('products').upsert({
        'id': product.id,
        'store_id': product.storeId,
        'name': product.name,
        'barcode': product.barcode,
        'category': product.category,
        'unit': product.unit.name,
        'buy_price': product.buyPrice,
        'sell_price': product.sellPrice,
        'quantity': product.quantity,
        'low_stock_threshold': product.lowStockThreshold,
        'updated_at': product.updatedAt.toIso8601String(),
      });
      await (db.update(db.products)..where((p) => p.id.equals(product.id)))
          .write(const ProductsCompanion(synced: Value(true)));
    }
  }

  Future<void> _pushStockMovements() async {
    final unsynced = await db.unsyncedMovements();
    for (final m in unsynced) {
      await supabase.from('stock_movements').upsert({
        'id': m.id,
        'product_id': m.productId,
        'store_id': m.storeId,
        'user_id': m.userId,
        'type': m.type.name,
        'quantity': m.quantity,
        'note': m.note,
        'created_at': m.createdAt.toIso8601String(),
      });
      await (db.update(db.stockMovements)..where((row) => row.id.equals(m.id)))
          .write(const StockMovementsCompanion(synced: Value(true)));
    }
  }

  Future<void> _pushSales() async {
    final unsynced = await db.unsyncedSales();
    for (final s in unsynced) {
      await supabase.from('sales').upsert({
        'id': s.id,
        'store_id': s.storeId,
        'user_id': s.userId,
        'total': s.total,
        'payment_method': s.paymentMethod.name,
        'created_at': s.createdAt.toIso8601String(),
      });
      await (db.update(db.sales)..where((row) => row.id.equals(s.id)))
          .write(const SalesCompanion(synced: Value(true)));
    }
  }
}
