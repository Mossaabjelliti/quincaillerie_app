import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart' show Value;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../data/local/database.dart';

enum SyncStatusState { idle, syncing, success, failed, offline }

class SyncManager {
  final AppDatabase db;
  final SupabaseClient supabase;
  final String deviceId;

  SyncStatusState status = SyncStatusState.idle;
  DateTime? lastSyncedAt;
  String? lastError;

  SyncManager({
    required this.db,
    required this.supabase,
    required this.deviceId,
  });

  Future<bool> hasInternet() async {
    final result = await Connectivity().checkConnectivity();
    return result.any((r) => r != ConnectivityResult.none);
  }

  /// Complete bidirectional synchronization
  Future<SyncStatusState> syncAll(String storeId) async {
    if (!await hasInternet()) {
      status = SyncStatusState.offline;
      return status;
    }

    status = SyncStatusState.syncing;
    lastError = null;

    try {
      // 1. Push local changes up to Supabase
      await _pushAll(storeId);

      // 2. Pull remote changes down to Drift
      await _pullAll(storeId);

      lastSyncedAt = DateTime.now();
      status = SyncStatusState.success;
    } catch (e) {
      status = SyncStatusState.failed;
      lastError = e.toString();
      await _logError('GLOBAL_SYNC', 'all', 'SYNC_ALL', lastError!);
    }
    return status;
  }

  // -----------------------------------------------------------------------
  // PUSH LOCAL -> SUPABASE
  // -----------------------------------------------------------------------

  Future<void> _pushAll(String storeId) async {
    await _pushProducts();
    await _pushStockMovements();
    await _pushSales();
    await _pushSuppliers();
    await _pushPurchases();
    await _pushCustomers();
    await _pushDebts();
    await _pushDebtPayments();
  }

  Future<void> _pushProducts() async {
    final unsynced = await db.unsyncedProducts();
    for (final p in unsynced) {
      try {
        await supabase.from('products').upsert({
          'id': p.id,
          'store_id': p.storeId,
          'name': p.name,
          'barcode': p.barcode,
          'category': p.category,
          'unit': p.unit.name,
          'buy_price': p.buyPrice,
          'sell_price': p.sellPrice,
          'quantity': p.quantity,
          'low_stock_threshold': p.lowStockThreshold,
          'updated_at': p.updatedAt.toIso8601String(),
        });
        await (db.update(db.products)..where((row) => row.id.equals(p.id)))
            .write(const ProductsCompanion(synced: Value(true)));
      } catch (e) {
        await _logError('products', p.id, 'PUSH', e.toString());
      }
    }
  }

  Future<void> _pushStockMovements() async {
    final unsynced = await db.unsyncedMovements();
    for (final m in unsynced) {
      try {
        await supabase.from('stock_movements').upsert({
          'id': m.id,
          'product_id': m.productId,
          'store_id': m.storeId,
          'user_id': m.userId,
          'device_id': m.deviceId.isNotEmpty ? m.deviceId : deviceId,
          'type': m.type.name.toUpperCase(),
          'quantity': m.quantity,
          'note': m.note,
          'created_at': m.createdAt.toIso8601String(),
        });
        await (db.update(db.stockMovements)..where((row) => row.id.equals(m.id)))
            .write(const StockMovementsCompanion(synced: Value(true)));
      } catch (e) {
        await _logError('stock_movements', m.id, 'PUSH', e.toString());
      }
    }
  }

  Future<void> _pushSales() async {
    final unsynced = await db.unsyncedSales();
    for (final s in unsynced) {
      try {
        await supabase.from('sales').upsert({
          'id': s.id,
          'store_id': s.storeId,
          'user_id': s.userId,
          'customer_id': s.customerId,
          'total': s.total,
          'payment_method': s.paymentMethod.name,
          'created_at': s.createdAt.toIso8601String(),
        });

        final items = await (db.select(db.saleItems)..where((i) => i.saleId.equals(s.id))).get();
        for (final item in items) {
          await supabase.from('sale_items').upsert({
            'id': item.id,
            'sale_id': item.saleId,
            'product_id': item.productId,
            'quantity': item.quantity,
            'unit_price': item.unitPrice,
            'subtotal': item.subtotal,
          });
        }

        await (db.update(db.sales)..where((row) => row.id.equals(s.id)))
            .write(const SalesCompanion(synced: Value(true)));
      } catch (e) {
        await _logError('sales', s.id, 'PUSH', e.toString());
      }
    }
  }

  Future<void> _pushSuppliers() async {
    final unsynced = await db.unsyncedSuppliers();
    for (final sup in unsynced) {
      try {
        await supabase.from('suppliers').upsert({
          'id': sup.id,
          'store_id': sup.storeId,
          'name': sup.name,
          'phone': sup.phone,
          'address': sup.address,
          'email': sup.email,
          'notes': sup.notes,
          'created_at': sup.createdAt.toIso8601String(),
        });
        await (db.update(db.suppliers)..where((row) => row.id.equals(sup.id)))
            .write(const SuppliersCompanion(synced: Value(true)));
      } catch (e) {
        await _logError('suppliers', sup.id, 'PUSH', e.toString());
      }
    }
  }

  Future<void> _pushPurchases() async {
    final unsynced = await db.unsyncedPurchases();
    for (final pur in unsynced) {
      try {
        await supabase.from('purchase_orders').upsert({
          'id': pur.id,
          'store_id': pur.storeId,
          'supplier_id': pur.supplierId,
          'created_by': pur.createdBy,
          'total': pur.total,
          'payment_status': pur.paymentStatus,
          'created_at': pur.createdAt.toIso8601String(),
        });

        final items = await (db.select(db.purchaseItems)..where((i) => i.purchaseId.equals(pur.id))).get();
        for (final item in items) {
          await supabase.from('purchase_items').upsert({
            'id': item.id,
            'purchase_id': item.purchaseId,
            'product_id': item.productId,
            'quantity': item.quantity,
            'buy_price': item.buyPrice,
            'subtotal': item.subtotal,
          });
        }

        await (db.update(db.purchases)..where((row) => row.id.equals(pur.id)))
            .write(const PurchasesCompanion(synced: Value(true)));
      } catch (e) {
        await _logError('purchase_orders', pur.id, 'PUSH', e.toString());
      }
    }
  }

  Future<void> _pushCustomers() async {
    final unsynced = await db.unsyncedCustomers();
    for (final c in unsynced) {
      try {
        await supabase.from('customers').upsert({
          'id': c.id,
          'store_id': c.storeId,
          'name': c.name,
          'phone': c.phone,
          'address': c.address,
          'notes': c.notes,
          'created_at': c.createdAt.toIso8601String(),
        });
        await (db.update(db.customers)..where((row) => row.id.equals(c.id)))
            .write(const CustomersCompanion(synced: Value(true)));
      } catch (e) {
        await _logError('customers', c.id, 'PUSH', e.toString());
      }
    }
  }

  Future<void> _pushDebts() async {
    final unsynced = await db.unsyncedDebts();
    for (final d in unsynced) {
      try {
        await supabase.from('customer_debts').upsert({
          'id': d.id,
          'store_id': d.storeId,
          'customer_id': d.customerId,
          'sale_id': d.saleId,
          'total_amount': d.totalAmount,
          'paid_amount': d.paidAmount,
          'remaining_amount': d.remainingAmount,
          'due_date': d.dueDate?.toIso8601String(),
          'status': d.status,
          'created_at': d.createdAt.toIso8601String(),
        });
        await (db.update(db.customerDebts)..where((row) => row.id.equals(d.id)))
            .write(const CustomerDebtsCompanion(synced: Value(true)));
      } catch (e) {
        await _logError('customer_debts', d.id, 'PUSH', e.toString());
      }
    }
  }

  Future<void> _pushDebtPayments() async {
    final unsynced = await db.unsyncedDebtPayments();
    for (final dp in unsynced) {
      try {
        await supabase.from('debt_payments').upsert({
          'id': dp.id,
          'store_id': dp.storeId,
          'debt_id': dp.debtId,
          'customer_id': dp.customerId,
          'amount': dp.amount,
          'payment_method': dp.paymentMethod,
          'note': dp.note,
          'created_at': dp.createdAt.toIso8601String(),
        });
        await (db.update(db.debtPayments)..where((row) => row.id.equals(dp.id)))
            .write(const DebtPaymentsCompanion(synced: Value(true)));
      } catch (e) {
        await _logError('debt_payments', dp.id, 'PUSH', e.toString());
      }
    }
  }

  // -----------------------------------------------------------------------
  // PULL SUPABASE -> LOCAL
  // -----------------------------------------------------------------------

  Future<void> _pullAll(String storeId) async {
    try {
      final remoteProducts = await supabase.from('products').select().eq('store_id', storeId);
      for (final rp in remoteProducts) {
        final unit = ProductUnit.values.firstWhere(
          (u) => u.name == rp['unit'],
          orElse: () => ProductUnit.piece,
        );
        await db.into(db.products).insertOnConflictUpdate(
              ProductsCompanion.insert(
                id: rp['id'],
                storeId: rp['store_id'],
                name: rp['name'],
                barcode: rp['barcode'],
                category: Value(rp['category'] ?? ''),
                unit: unit,
                buyPrice: Value((rp['buy_price'] as num?)?.toDouble() ?? 0.0),
                sellPrice: Value((rp['sell_price'] as num?)?.toDouble() ?? 0.0),
                quantity: Value((rp['quantity'] as num?)?.toDouble() ?? 0.0),
                lowStockThreshold: Value((rp['low_stock_threshold'] as num?)?.toDouble() ?? 5.0),
                synced: const Value(true),
              ),
            );
      }
    } catch (e) {
      await _logError('products', 'pull_all', 'PULL', e.toString());
    }
  }

  Future<void> _logError(String tableName, String rowId, String action, String error) async {
    const uuid = Uuid();
    await db.into(db.syncLogs).insert(
          SyncLogsCompanion.insert(
            id: uuid.v4(),
            targetTable: tableName,
            rowId: rowId,
            action: action,
            errorMessage: error,
            createdAt: Value(DateTime.now()),
          ),
        );
  }
}
