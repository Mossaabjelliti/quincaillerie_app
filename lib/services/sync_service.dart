import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../core/inventory/stock_engine.dart';
import '../data/local/database.dart';

enum SyncStatus { idle, syncing, success, failed, offline }

class SyncService {
  final AppDatabase db;
  final SupabaseClient supabase;
  final StockEngine _stockEngine;
  final String deviceId = const Uuid().v4();

  SyncStatus status = SyncStatus.idle;
  DateTime? lastSyncedAt;

  SyncService({required this.db, required this.supabase})
      : _stockEngine = StockEngine(db: db);

  Future<bool> _hasConnection() async {
    final result = await Connectivity().checkConnectivity();
    return result.any((r) => r != ConnectivityResult.none);
  }

  Future<List<SyncLog>> recentLogs({int limit = 50}) {
    return (db.select(db.syncLogs)
          ..orderBy([(row) => OrderingTerm.desc(row.createdAt)])
          ..limit(limit))
        .get();
  }

  Future<void> _logError(String targetTable, String rowId, String action, String errorMessage) async {
    await db.into(db.syncLogs).insert(
          SyncLogsCompanion.insert(
            id: const Uuid().v4(),
            targetTable: targetTable,
            rowId: rowId,
            action: action,
            errorMessage: errorMessage,
            createdAt: Value(DateTime.now()),
          ),
        );
  }

  Future<List<String>> _knownStoreIds() async {
    final ids = <String>{};
    void addAll(Iterable<String> values) {
      for (final value in values) {
        if (value.isNotEmpty) ids.add(value);
      }
    }

    addAll((await db.select(db.stores).get()).map((row) => row.id));
    addAll((await db.select(db.products).get()).map((row) => row.storeId));
    addAll((await db.select(db.stockMovements).get()).map((row) => row.storeId));
    addAll((await db.select(db.sales).get()).map((row) => row.storeId));
    addAll((await db.select(db.customers).get()).map((row) => row.storeId));
    addAll((await db.select(db.suppliers).get()).map((row) => row.storeId));
    addAll((await db.select(db.purchases).get()).map((row) => row.storeId));
    addAll((await db.select(db.storeMembers).get()).map((row) => row.storeId));
    return ids.toList();
  }

  /// Daily sync entry point used by the app shell and background task.
  Future<SyncStatus> syncNow() async {
    if (!await _hasConnection()) {
      status = SyncStatus.offline;
      return status;
    }

    status = SyncStatus.syncing;
    try {
      final storeIds = await _knownStoreIds();
      for (final storeId in storeIds) {
        await _pushStore(storeId);
        await _pullStore(storeId);
      }
      lastSyncedAt = DateTime.now();
      status = SyncStatus.success;
    } catch (e) {
      status = SyncStatus.failed;
      await _logError('GLOBAL_SYNC', 'all', 'SYNC', e.toString());
    }
    return status;
  }

  Future<void> _pushStore(String storeId) async {
    await _pushProducts(storeId);
    await _pushStockMovements(storeId);
    await _pushSales(storeId);
    await _pushSaleItems(storeId);
    await _pushCustomers(storeId);
    await _pushDebts(storeId);
    await _pushDebtPayments(storeId);
    await _pushSuppliers(storeId);
    await _pushPurchases(storeId);
    await _pushProductUnits(storeId);
    await _pushProductVariants(storeId);
    await _pushStoresAndMembers(storeId);
  }

  Future<void> _pullStore(String storeId) async {
    await _pullStoreRecord(storeId);
    await _pullProducts(storeId);
    await _pullStockMovements(storeId);
    await _pullSales(storeId);
    await _pullSaleItems(storeId);
    await _pullCustomers(storeId);
    await _pullDebts(storeId);
    await _pullDebtPayments(storeId);
    await _pullSuppliers(storeId);
    await _pullPurchases(storeId);
    await _pullProductUnits(storeId);
    await _pullProductVariants(storeId);
    await _stockEngine.reconcileStoreStock(storeId);
  }

  Future<void> _pushProducts(String storeId) async {
    final unsynced = await (db.select(db.products)
          ..where((p) => p.storeId.equals(storeId) & p.synced.equals(false)))
        .get();
    for (final product in unsynced) {
      try {
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
          'brand': product.brand,
          'supplier_id': product.supplierId,
          'image_url': product.imageUrl,
          'updated_at': product.updatedAt.toIso8601String(),
        });
        await (db.update(db.products)..where((row) => row.id.equals(product.id)))
            .write(const ProductsCompanion(synced: Value(true)));
      } catch (e) {
        await _logError('products', product.id, 'PUSH', e.toString());
      }
    }
  }

  Future<void> _pushStockMovements(String storeId) async {
    final unsynced = await (db.select(db.stockMovements)
          ..where((m) => m.storeId.equals(storeId) & m.synced.equals(false)))
        .get();
    for (final movement in unsynced) {
      try {
        await supabase.from('stock_movements').upsert({
          'id': movement.id,
          'product_id': movement.productId,
          'store_id': movement.storeId,
          'user_id': movement.userId,
          'device_id': movement.deviceId.isNotEmpty ? movement.deviceId : deviceId,
          'type': movement.type.name,
          'quantity': movement.quantity,
          'note': movement.note,
          'created_at': movement.createdAt.toIso8601String(),
        });
        await (db.update(db.stockMovements)..where((row) => row.id.equals(movement.id)))
            .write(const StockMovementsCompanion(synced: Value(true)));
      } catch (e) {
        await _logError('stock_movements', movement.id, 'PUSH', e.toString());
      }
    }
  }

  Future<void> _pushSales(String storeId) async {
    final unsynced = await (db.select(db.sales)
          ..where((s) => s.storeId.equals(storeId) & s.synced.equals(false)))
        .get();
    for (final sale in unsynced) {
      try {
        await supabase.from('sales').upsert({
          'id': sale.id,
          'store_id': sale.storeId,
          'user_id': sale.userId,
          'customer_id': sale.customerId,
          'total': sale.total,
          'payment_method': sale.paymentMethod.name,
          'created_at': sale.createdAt.toIso8601String(),
        });
        await (db.update(db.sales)..where((row) => row.id.equals(sale.id)))
            .write(const SalesCompanion(synced: Value(true)));
      } catch (e) {
        await _logError('sales', sale.id, 'PUSH', e.toString());
      }
    }
  }

  Future<void> _pushSaleItems(String storeId) async {
    final sales = await (db.select(db.sales)..where((s) => s.storeId.equals(storeId))).get();
    for (final sale in sales) {
      final items = await (db.select(db.saleItems)..where((item) => item.saleId.equals(sale.id))).get();
      for (final item in items) {
        try {
          await supabase.from('sale_items').upsert({
            'id': item.id,
            'sale_id': item.saleId,
            'product_id': item.productId,
            'quantity': item.quantity,
            'unit_price': item.unitPrice,
            'subtotal': item.subtotal,
          });
        } catch (e) {
          await _logError('sale_items', item.id, 'PUSH', e.toString());
        }
      }
    }
  }

  Future<void> _pushCustomers(String storeId) async {
    final unsynced = await (db.select(db.customers)
          ..where((c) => c.storeId.equals(storeId) & c.synced.equals(false)))
        .get();
    for (final customer in unsynced) {
      try {
        await supabase.from('customers').upsert({
          'id': customer.id,
          'store_id': customer.storeId,
          'name': customer.name,
          'phone': customer.phone,
          'address': customer.address,
          'notes': customer.notes,
          'created_at': customer.createdAt.toIso8601String(),
        });
        await (db.update(db.customers)..where((row) => row.id.equals(customer.id)))
            .write(const CustomersCompanion(synced: Value(true)));
      } catch (e) {
        await _logError('customers', customer.id, 'PUSH', e.toString());
      }
    }
  }

  Future<void> _pushDebts(String storeId) async {
    final unsynced = await (db.select(db.customerDebts)
          ..where((d) => d.storeId.equals(storeId) & d.synced.equals(false)))
        .get();
    for (final debt in unsynced) {
      try {
        await supabase.from('customer_debts').upsert({
          'id': debt.id,
          'store_id': debt.storeId,
          'customer_id': debt.customerId,
          'sale_id': debt.saleId,
          'total_amount': debt.totalAmount,
          'paid_amount': debt.paidAmount,
          'remaining_amount': debt.remainingAmount,
          'due_date': debt.dueDate?.toIso8601String(),
          'status': debt.status,
          'created_at': debt.createdAt.toIso8601String(),
        });
        await (db.update(db.customerDebts)..where((row) => row.id.equals(debt.id)))
            .write(const CustomerDebtsCompanion(synced: Value(true)));
      } catch (e) {
        await _logError('customer_debts', debt.id, 'PUSH', e.toString());
      }
    }
  }

  Future<void> _pushDebtPayments(String storeId) async {
    final unsynced = await (db.select(db.debtPayments)
          ..where((p) => p.storeId.equals(storeId) & p.synced.equals(false)))
        .get();
    for (final payment in unsynced) {
      try {
        await supabase.from('debt_payments').upsert({
          'id': payment.id,
          'store_id': payment.storeId,
          'debt_id': payment.debtId,
          'customer_id': payment.customerId,
          'amount': payment.amount,
          'payment_method': payment.paymentMethod,
          'note': payment.note,
          'created_at': payment.createdAt.toIso8601String(),
        });
        await (db.update(db.debtPayments)..where((row) => row.id.equals(payment.id)))
            .write(const DebtPaymentsCompanion(synced: Value(true)));
      } catch (e) {
        await _logError('debt_payments', payment.id, 'PUSH', e.toString());
      }
    }
  }

  Future<void> _pushSuppliers(String storeId) async {
    final unsynced = await (db.select(db.suppliers)
          ..where((s) => s.storeId.equals(storeId) & s.synced.equals(false)))
        .get();
    for (final supplier in unsynced) {
      try {
        await supabase.from('suppliers').upsert({
          'id': supplier.id,
          'store_id': supplier.storeId,
          'name': supplier.name,
          'phone': supplier.phone,
          'address': supplier.address,
          'email': supplier.email,
          'notes': supplier.notes,
          'created_at': supplier.createdAt.toIso8601String(),
        });
        await (db.update(db.suppliers)..where((row) => row.id.equals(supplier.id)))
            .write(const SuppliersCompanion(synced: Value(true)));
      } catch (e) {
        await _logError('suppliers', supplier.id, 'PUSH', e.toString());
      }
    }
  }

  Future<void> _pushPurchases(String storeId) async {
    final unsynced = await (db.select(db.purchases)
          ..where((p) => p.storeId.equals(storeId) & p.synced.equals(false)))
        .get();
    for (final purchase in unsynced) {
      try {
        await supabase.from('purchase_orders').upsert({
          'id': purchase.id,
          'store_id': purchase.storeId,
          'supplier_id': purchase.supplierId,
          'created_by': purchase.createdBy,
          'total': purchase.total,
          'payment_status': purchase.paymentStatus,
          'created_at': purchase.createdAt.toIso8601String(),
        });
        await (db.update(db.purchases)..where((row) => row.id.equals(purchase.id)))
            .write(const PurchasesCompanion(synced: Value(true)));
      } catch (e) {
        await _logError('purchase_orders', purchase.id, 'PUSH', e.toString());
      }
    }
  }

  Future<void> _pushProductUnits(String storeId) async {
    final unsynced = await (db.select(db.productUnitConversions)
          ..where((u) => u.storeId.equals(storeId) & u.synced.equals(false)))
        .get();
    for (final unit in unsynced) {
      try {
        await supabase.from('product_units').upsert({
          'id': unit.id,
          'store_id': unit.storeId,
          'product_id': unit.productId,
          'unit_name': unit.unitName,
          'conversion_factor': unit.conversionFactor,
          'selling_price': unit.sellingPrice,
        });
        await (db.update(db.productUnitConversions)..where((row) => row.id.equals(unit.id)))
            .write(const ProductUnitConversionsCompanion(synced: Value(true)));
      } catch (e) {
        await _logError('product_units', unit.id, 'PUSH', e.toString());
      }
    }
  }

  Future<void> _pushProductVariants(String storeId) async {
    final unsynced = await (db.select(db.productVariants)
          ..where((v) => v.storeId.equals(storeId) & v.synced.equals(false)))
        .get();
    for (final variant in unsynced) {
      try {
        await supabase.from('product_variants').upsert({
          'id': variant.id,
          'store_id': variant.storeId,
          'product_id': variant.productId,
          'variant_name': variant.variantName,
          'barcode': variant.barcode,
          'buy_price': variant.buyPrice,
          'sell_price': variant.sellPrice,
          'stock_quantity': variant.stockQuantity,
        });
        await (db.update(db.productVariants)..where((row) => row.id.equals(variant.id)))
            .write(const ProductVariantsCompanion(synced: Value(true)));
      } catch (e) {
        await _logError('product_variants', variant.id, 'PUSH', e.toString());
      }
    }
  }

  Future<void> _pushStoresAndMembers(String storeId) async {
    final store = await (db.select(db.stores)..where((row) => row.id.equals(storeId))).getSingleOrNull();
    if (store != null && !store.synced) {
      try {
        await supabase.from('stores').upsert({
          'id': store.id,
          'name': store.name,
          'address': store.address,
          'phone': store.phone,
          'owner_id': store.ownerId,
          'created_at': store.createdAt.toIso8601String(),
        });
        await (db.update(db.stores)..where((row) => row.id.equals(store.id)))
            .write(const StoresCompanion(synced: Value(true)));
      } catch (e) {
        await _logError('stores', store.id, 'PUSH', e.toString());
      }
    }

    final members = await (db.select(db.storeMembers)
          ..where((row) => row.storeId.equals(storeId) & row.synced.equals(false)))
        .get();
    for (final member in members) {
      try {
        await supabase.from('store_members').upsert({
          'id': member.id,
          'store_id': member.storeId,
          'user_id': member.userId,
          'role': member.role,
          'created_at': member.createdAt.toIso8601String(),
        });
        await (db.update(db.storeMembers)..where((row) => row.id.equals(member.id)))
            .write(const StoreMembersCompanion(synced: Value(true)));
      } catch (e) {
        await _logError('store_members', member.id, 'PUSH', e.toString());
      }
    }
  }

  Future<void> _pullStoreRecord(String storeId) async {
    try {
      final remote = await supabase.from('stores').select().eq('id', storeId).maybeSingle();
      if (remote != null) {
        await db.into(db.stores).insertOnConflictUpdate(
              StoresCompanion.insert(
                id: remote['id'] as String,
                name: remote['name'] as String,
                address: Value(remote['address'] as String? ?? ''),
                phone: Value(remote['phone'] as String? ?? ''),
                ownerId: remote['owner_id'] as String? ?? '',
                createdAt: Value(DateTime.tryParse(remote['created_at'] as String? ?? '') ?? DateTime.now()),
                synced: const Value(true),
              ),
            );
      }
    } catch (e) {
      await _logError('stores', storeId, 'PULL', e.toString());
    }
  }

  Future<void> _pullProducts(String storeId) async {
    try {
      final remoteRows = await supabase.from('products').select().eq('store_id', storeId);
      for (final remote in remoteRows as List) {
        final remoteUpdatedAt = DateTime.tryParse(remote['updated_at'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
        final local = await (db.select(db.products)..where((p) => p.id.equals(remote['id'] as String))).getSingleOrNull();
        if (local != null && local.updatedAt.isAfter(remoteUpdatedAt)) {
          continue;
        }

        await db.into(db.products).insertOnConflictUpdate(
              ProductsCompanion.insert(
                id: remote['id'] as String,
                storeId: remote['store_id'] as String,
                name: remote['name'] as String,
                barcode: remote['barcode'] as String,
                category: Value(remote['category'] as String? ?? ''),
                unit: ProductUnit.values.firstWhere(
                  (unit) => unit.name == (remote['unit'] as String? ?? 'piece'),
                  orElse: () => ProductUnit.piece,
                ),
                buyPrice: Value((remote['buy_price'] as num?)?.toDouble() ?? 0),
                sellPrice: Value((remote['sell_price'] as num?)?.toDouble() ?? 0),
                quantity: Value((remote['quantity'] as num?)?.toDouble() ?? 0),
                lowStockThreshold: Value((remote['low_stock_threshold'] as num?)?.toDouble() ?? 5),
                brand: Value(remote['brand'] as String? ?? ''),
                supplierId: Value(remote['supplier_id'] as String? ?? ''),
                imageUrl: Value(remote['image_url'] as String? ?? ''),
                createdAt: Value(DateTime.tryParse(remote['created_at'] as String? ?? '') ?? DateTime.now()),
                updatedAt: Value(remoteUpdatedAt.isAtSameMomentAs(DateTime.fromMillisecondsSinceEpoch(0)) ? DateTime.now() : remoteUpdatedAt),
                synced: const Value(true),
              ),
            );
      }
    } catch (e) {
      await _logError('products', storeId, 'PULL', e.toString());
    }
  }

  Future<void> _pullStockMovements(String storeId) async {
    try {
      final remoteRows = await supabase.from('stock_movements').select().eq('store_id', storeId);
      for (final remote in remoteRows as List) {
        await db.into(db.stockMovements).insertOnConflictUpdate(
              StockMovementsCompanion.insert(
                id: remote['id'] as String,
                productId: remote['product_id'] as String,
                storeId: remote['store_id'] as String,
                userId: remote['user_id'] as String,
                deviceId: Value(remote['device_id'] as String? ?? ''),
                type: MovementType.values.firstWhere(
                  (type) => type.name == (remote['type'] as String? ?? 'stockOut'),
                  orElse: () => MovementType.stockOut,
                ),
                quantity: (remote['quantity'] as num).toDouble(),
                note: Value(remote['note'] as String? ?? ''),
                createdAt: Value(DateTime.tryParse(remote['created_at'] as String? ?? '') ?? DateTime.now()),
                synced: const Value(true),
              ),
            );
      }
    } catch (e) {
      await _logError('stock_movements', storeId, 'PULL', e.toString());
    }
  }

  Future<void> _pullSales(String storeId) async {
    try {
      final remoteRows = await supabase.from('sales').select().eq('store_id', storeId);
      for (final remote in remoteRows as List) {
        await db.into(db.sales).insertOnConflictUpdate(
              SalesCompanion.insert(
                id: remote['id'] as String,
                storeId: remote['store_id'] as String,
                userId: remote['user_id'] as String,
                customerId: Value(remote['customer_id'] as String? ?? ''),
                total: (remote['total'] as num).toDouble(),
                paymentMethod: PaymentMethod.values.firstWhere(
                  (method) => method.name == (remote['payment_method'] as String? ?? 'cash'),
                  orElse: () => PaymentMethod.cash,
                ),
                createdAt: Value(DateTime.tryParse(remote['created_at'] as String? ?? '') ?? DateTime.now()),
                synced: const Value(true),
              ),
            );
      }
    } catch (e) {
      await _logError('sales', storeId, 'PULL', e.toString());
    }
  }

  Future<void> _pullSaleItems(String storeId) async {
    try {
      final sales = await (db.select(db.sales)..where((sale) => sale.storeId.equals(storeId))).get();
      for (final sale in sales) {
        final remoteRows = await supabase.from('sale_items').select().eq('sale_id', sale.id);
        for (final remote in remoteRows as List) {
          await db.into(db.saleItems).insertOnConflictUpdate(
                SaleItemsCompanion.insert(
                  id: remote['id'] as String,
                  saleId: remote['sale_id'] as String,
                  productId: remote['product_id'] as String,
                    quantity: (remote['quantity'] as num).toDouble(),
                    unitPrice: (remote['unit_price'] as num).toDouble(),
                    subtotal: (remote['subtotal'] as num).toDouble(),
                ),
              );
        }
      }
    } catch (e) {
      await _logError('sale_items', storeId, 'PULL', e.toString());
    }
  }

  Future<void> _pullCustomers(String storeId) async {
    try {
      final remoteRows = await supabase.from('customers').select().eq('store_id', storeId);
      for (final remote in remoteRows as List) {
        await db.into(db.customers).insertOnConflictUpdate(
              CustomersCompanion.insert(
                id: remote['id'] as String,
                storeId: remote['store_id'] as String,
                name: remote['name'] as String,
                phone: Value(remote['phone'] as String? ?? ''),
                address: Value(remote['address'] as String? ?? ''),
                notes: Value(remote['notes'] as String? ?? ''),
                createdAt: Value(DateTime.tryParse(remote['created_at'] as String? ?? '') ?? DateTime.now()),
                synced: const Value(true),
              ),
            );
      }
    } catch (e) {
      await _logError('customers', storeId, 'PULL', e.toString());
    }
  }

  Future<void> _pullDebts(String storeId) async {
    try {
      final remoteRows = await supabase.from('customer_debts').select().eq('store_id', storeId);
      for (final remote in remoteRows as List) {
        await db.into(db.customerDebts).insertOnConflictUpdate(
              CustomerDebtsCompanion.insert(
                id: remote['id'] as String,
                storeId: remote['store_id'] as String,
                customerId: remote['customer_id'] as String,
                saleId: Value(remote['sale_id'] as String? ?? ''),
                totalAmount: (remote['total_amount'] as num).toDouble(),
                paidAmount: Value((remote['paid_amount'] as num?)?.toDouble() ?? 0),
                remainingAmount: (remote['remaining_amount'] as num).toDouble(),
                dueDate: Value(remote['due_date'] == null ? null : DateTime.tryParse(remote['due_date'] as String)),
                status: Value(remote['status'] as String? ?? 'UNPAID'),
                createdAt: Value(DateTime.tryParse(remote['created_at'] as String? ?? '') ?? DateTime.now()),
                synced: const Value(true),
              ),
            );
      }
    } catch (e) {
      await _logError('customer_debts', storeId, 'PULL', e.toString());
    }
  }

  Future<void> _pullDebtPayments(String storeId) async {
    try {
      final remoteRows = await supabase.from('debt_payments').select().eq('store_id', storeId);
      for (final remote in remoteRows as List) {
        await db.into(db.debtPayments).insertOnConflictUpdate(
              DebtPaymentsCompanion.insert(
                id: remote['id'] as String,
                storeId: remote['store_id'] as String,
                debtId: remote['debt_id'] as String,
                customerId: remote['customer_id'] as String,
                amount: (remote['amount'] as num).toDouble(),
                paymentMethod: Value(remote['payment_method'] as String? ?? 'cash'),
                note: Value(remote['note'] as String? ?? ''),
                createdAt: Value(DateTime.tryParse(remote['created_at'] as String? ?? '') ?? DateTime.now()),
                synced: const Value(true),
              ),
            );
      }
    } catch (e) {
      await _logError('debt_payments', storeId, 'PULL', e.toString());
    }
  }

  Future<void> _pullSuppliers(String storeId) async {
    try {
      final remoteRows = await supabase.from('suppliers').select().eq('store_id', storeId);
      for (final remote in remoteRows as List) {
        await db.into(db.suppliers).insertOnConflictUpdate(
              SuppliersCompanion.insert(
                id: remote['id'] as String,
                storeId: remote['store_id'] as String,
                name: remote['name'] as String,
                phone: Value(remote['phone'] as String? ?? ''),
                address: Value(remote['address'] as String? ?? ''),
                email: Value(remote['email'] as String? ?? ''),
                notes: Value(remote['notes'] as String? ?? ''),
                createdAt: Value(DateTime.tryParse(remote['created_at'] as String? ?? '') ?? DateTime.now()),
                synced: const Value(true),
              ),
            );
      }
    } catch (e) {
      await _logError('suppliers', storeId, 'PULL', e.toString());
    }
  }

  Future<void> _pullPurchases(String storeId) async {
    try {
      final remoteRows = await supabase.from('purchase_orders').select().eq('store_id', storeId);
      for (final remote in remoteRows as List) {
        await db.into(db.purchases).insertOnConflictUpdate(
              PurchasesCompanion.insert(
                id: remote['id'] as String,
                storeId: remote['store_id'] as String,
                supplierId: remote['supplier_id'] as String,
                createdBy: remote['created_by'] as String,
                total: (remote['total'] as num).toDouble(),
                paymentStatus: Value(remote['payment_status'] as String? ?? 'PAID'),
                createdAt: Value(DateTime.tryParse(remote['created_at'] as String? ?? '') ?? DateTime.now()),
                synced: const Value(true),
              ),
            );
      }
    } catch (e) {
      await _logError('purchase_orders', storeId, 'PULL', e.toString());
    }
  }

  Future<void> _pullProductUnits(String storeId) async {
    try {
      final remoteRows = await supabase.from('product_units').select().eq('store_id', storeId);
      for (final remote in remoteRows as List) {
        await db.into(db.productUnitConversions).insertOnConflictUpdate(
              ProductUnitConversionsCompanion.insert(
                id: remote['id'] as String,
                storeId: remote['store_id'] as String,
                productId: remote['product_id'] as String,
                unitName: remote['unit_name'] as String,
                conversionFactor: Value((remote['conversion_factor'] as num?)?.toDouble() ?? 1),
                sellingPrice: Value((remote['selling_price'] as num?)?.toDouble() ?? 0),
                synced: const Value(true),
              ),
            );
      }
    } catch (e) {
      await _logError('product_units', storeId, 'PULL', e.toString());
    }
  }

  Future<void> _pullProductVariants(String storeId) async {
    try {
      final remoteRows = await supabase.from('product_variants').select().eq('store_id', storeId);
      for (final remote in remoteRows as List) {
        await db.into(db.productVariants).insertOnConflictUpdate(
              ProductVariantsCompanion.insert(
                id: remote['id'] as String,
                storeId: remote['store_id'] as String,
                productId: remote['product_id'] as String,
                variantName: remote['variant_name'] as String,
                barcode: Value(remote['barcode'] as String? ?? ''),
                buyPrice: Value((remote['buy_price'] as num?)?.toDouble() ?? 0),
                sellPrice: Value((remote['sell_price'] as num?)?.toDouble() ?? 0),
                stockQuantity: Value((remote['stock_quantity'] as num?)?.toDouble() ?? 0),
                synced: const Value(true),
              ),
            );
      }
    } catch (e) {
      await _logError('product_variants', storeId, 'PULL', e.toString());
    }
  }
}
