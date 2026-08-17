import 'package:drift/drift.dart';
import 'connection/connection.dart';

part 'database.g.dart';

enum ProductUnit { piece, meter, kg, liter }
enum MovementType { stockIn, stockOut, adjustment, purchase, sale, returnItem }
enum PaymentMethod { cash, check, credit }

// -----------------------------------------------------------------------
// MULTI-TENANT & AUTH TABLES
// -----------------------------------------------------------------------

class Profiles extends Table {
  TextColumn get id => text()();
  TextColumn get fullName => text().withDefault(const Constant(''))();
  TextColumn get phone => text().withDefault(const Constant(''))();
  TextColumn get role => text().withDefault(const Constant('owner'))(); // UserRole wire values
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class Stores extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get address => text().withDefault(const Constant(''))();
  TextColumn get phone => text().withDefault(const Constant(''))();
  TextColumn get ownerId => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class StoreMembers extends Table {
  TextColumn get id => text()();
  TextColumn get storeId => text()();
  TextColumn get userId => text()();
  TextColumn get role => text().withDefault(const Constant('cashier'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

// -----------------------------------------------------------------------
// CATALOG & INVENTORY TABLES
// -----------------------------------------------------------------------

class Products extends Table {
  TextColumn get id => text()();
  TextColumn get storeId => text()();
  TextColumn get name => text()();
  TextColumn get barcode => text()();
  TextColumn get category => text().withDefault(const Constant(''))();
  IntColumn get unit => intEnum<ProductUnit>()();
  RealColumn get buyPrice => real().withDefault(const Constant(0))();
  RealColumn get sellPrice => real().withDefault(const Constant(0))();
  RealColumn get quantity => real().withDefault(const Constant(0))();
  RealColumn get lowStockThreshold => real().withDefault(const Constant(5))();
  TextColumn get brand => text().withDefault(const Constant(''))();
  TextColumn get supplierId => text().withDefault(const Constant(''))();
  TextColumn get imageUrl => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class StockMovements extends Table {
  TextColumn get id => text()();
  TextColumn get productId => text().references(Products, #id)();
  TextColumn get storeId => text()();
  TextColumn get userId => text()();
  TextColumn get deviceId => text().withDefault(const Constant(''))();
  IntColumn get type => intEnum<MovementType>()();
  RealColumn get quantity => real()();
  TextColumn get note => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class ProductUnitConversions extends Table {
  TextColumn get id => text()();
  TextColumn get storeId => text()();
  TextColumn get productId => text().references(Products, #id)();
  TextColumn get unitName => text()();
  RealColumn get conversionFactor => real().withDefault(const Constant(1))();
  RealColumn get sellingPrice => real().withDefault(const Constant(0))();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class ProductVariants extends Table {
  TextColumn get id => text()();
  TextColumn get storeId => text()();
  TextColumn get productId => text().references(Products, #id)();
  TextColumn get variantName => text()();
  TextColumn get barcode => text().withDefault(const Constant(''))();
  RealColumn get buyPrice => real().withDefault(const Constant(0))();
  RealColumn get sellPrice => real().withDefault(const Constant(0))();
  RealColumn get stockQuantity => real().withDefault(const Constant(0))();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

// -----------------------------------------------------------------------
// SALES & CUSTOMER DEBT TABLES
// -----------------------------------------------------------------------

class Sales extends Table {
  TextColumn get id => text()();
  TextColumn get storeId => text()();
  TextColumn get userId => text()();
  TextColumn get customerId => text().withDefault(const Constant(''))();
  RealColumn get total => real()();
  IntColumn get paymentMethod => intEnum<PaymentMethod>()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class SaleItems extends Table {
  TextColumn get id => text()();
  TextColumn get saleId => text().references(Sales, #id)();
  TextColumn get productId => text().references(Products, #id)();
  RealColumn get quantity => real()();
  RealColumn get unitPrice => real()();
  RealColumn get subtotal => real()();
  // Historical snapshots so receipts/invoices survive product renames.
  TextColumn get productName => text().withDefault(const Constant(''))();
  TextColumn get unitLabel => text().withDefault(const Constant(''))();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(name: 'invoices_store_id_idx', columns: {#storeId})
@TableIndex(name: 'invoices_sale_id_idx', columns: {#saleId}, unique: true)
@TableIndex(name: 'invoices_store_number_idx', columns: {#storeId, #invoiceNumber}, unique: true)
class Invoices extends Table {
  TextColumn get id => text()();
  TextColumn get storeId => text()();
  TextColumn get saleId => text().unique().references(Sales, #id)();
  TextColumn get invoiceNumber => text()();
  TextColumn get status => text().withDefault(const Constant('ISSUED'))(); // DRAFT | ISSUED | PAID | VOID
  DateTimeColumn get issuedAt => dateTime()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Local per-store, per-year invoice counter used to allocate a provisional
/// invoice number (INV-YYYY-NNNN) during offline checkout. The authoritative
/// number is always allocated server-side by `next_invoice_number()` when the
/// sale is pushed; this local counter only guarantees a unique, non-MAX()+1
/// provisional number while offline.
class LocalInvoiceSequences extends Table {
  TextColumn get storeId => text()();
  IntColumn get year => integer()();
  IntColumn get lastValue => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {storeId, year};
}

class Customers extends Table {
  TextColumn get id => text()();
  TextColumn get storeId => text()();
  TextColumn get name => text()();
  TextColumn get phone => text().withDefault(const Constant(''))();
  TextColumn get address => text().withDefault(const Constant(''))();
  TextColumn get notes => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class CustomerDebts extends Table {
  TextColumn get id => text()();
  TextColumn get storeId => text()();
  TextColumn get customerId => text().references(Customers, #id)();
  TextColumn get saleId => text().withDefault(const Constant(''))();
  RealColumn get totalAmount => real()();
  RealColumn get paidAmount => real().withDefault(const Constant(0))();
  RealColumn get remainingAmount => real()();
  DateTimeColumn get dueDate => dateTime().nullable()();
  TextColumn get status => text().withDefault(const Constant('UNPAID'))(); // UNPAID, PARTIAL, PAID
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class DebtPayments extends Table {
  TextColumn get id => text()();
  TextColumn get storeId => text()();
  TextColumn get debtId => text().references(CustomerDebts, #id)();
  TextColumn get customerId => text().references(Customers, #id)();
  RealColumn get amount => real()();
  TextColumn get paymentMethod => text().withDefault(const Constant('cash'))();
  TextColumn get note => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

// -----------------------------------------------------------------------
// SUPPLIER & PURCHASES TABLES
// -----------------------------------------------------------------------

class Suppliers extends Table {
  TextColumn get id => text()();
  TextColumn get storeId => text()();
  TextColumn get name => text()();
  TextColumn get phone => text().withDefault(const Constant(''))();
  TextColumn get address => text().withDefault(const Constant(''))();
  TextColumn get email => text().withDefault(const Constant(''))();
  TextColumn get notes => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class Purchases extends Table {
  TextColumn get id => text()();
  TextColumn get storeId => text()();
  TextColumn get supplierId => text().references(Suppliers, #id)();
  TextColumn get createdBy => text()();
  RealColumn get total => real()();
  TextColumn get paymentStatus => text().withDefault(const Constant('PAID'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class PurchaseItems extends Table {
  TextColumn get id => text()();
  TextColumn get purchaseId => text().references(Purchases, #id)();
  TextColumn get productId => text().references(Products, #id)();
  RealColumn get quantity => real()();
  RealColumn get buyPrice => real()();
  RealColumn get subtotal => real()();

  @override
  Set<Column> get primaryKey => {id};
}

// -----------------------------------------------------------------------
// SYNC LOGS TABLE
// -----------------------------------------------------------------------

class SyncLogs extends Table {
  TextColumn get id => text()();
  TextColumn get targetTable => text()();
  TextColumn get rowId => text()();
  TextColumn get action => text()(); // PUSH, PULL
  TextColumn get errorMessage => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class ActivityLogs extends Table {
  TextColumn get id => text()();
  TextColumn get storeId => text()();
  TextColumn get userId => text()();
  TextColumn get action => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
  TextColumn get metadata => text().withDefault(const Constant('{}'))();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [
  Profiles,
  Stores,
  StoreMembers,
  Products,
  StockMovements,
  ProductUnitConversions,
  ProductVariants,
  Sales,
  SaleItems,
  Invoices,
  LocalInvoiceSequences,
  Customers,
  CustomerDebts,
  DebtPayments,
  Suppliers,
  Purchases,
  PurchaseItems,
  SyncLogs,
  ActivityLogs,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(openDatabase());
  AppDatabase.forTesting(QueryExecutor executor) : super(executor);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (migrator, from, to) async {
          // v1 shipped schemaVersion 1. v2 added multi-tenant/auth/sales tables.
          // For installations still at v1, create the full v2 baseline first,
          // then apply the v3 changes below (idempotent per step).
          if (from < 2) {
            await migrator.createAll();
          }
          // v3: add historical snapshot columns to sale_items and create the
          // invoices table. addColumn/createTable are no-ops if the object
          // already exists, so replaying the migration is safe.
          if (from < 3) {
            await migrator.addColumn(saleItems, saleItems.productName);
            await migrator.addColumn(saleItems, saleItems.unitLabel);
            await migrator.createTable(invoices);
          }
          // v4: add the local invoice counter table used to allocate a unique
          // provisional invoice number during offline checkout.
          if (from < 4) {
            await migrator.createTable(localInvoiceSequences);
          }
        },
      );

  // Convenience queries
  Future<List<Product>> allProducts(String storeId) =>
      (select(products)..where((p) => p.storeId.equals(storeId))).get();

  Stream<List<Product>> watchProducts(String storeId) =>
      (select(products)..where((p) => p.storeId.equals(storeId))).watch();

  Future<List<Product>> lowStockProducts(String storeId) => (select(products)
        ..where((p) =>
            (p.storeId.equals(storeId)) &
            (p.quantity.isSmallerOrEqual(p.lowStockThreshold))))
      .get();

  // Calculated stock via movements SUM(quantity)
  Future<double> getCalculatedProductStock(String storeId, String productId) async {
    final movements = await (select(stockMovements)
          ..where((m) => m.storeId.equals(storeId) & m.productId.equals(productId)))
        .get();

    double total = 0;
    for (final m in movements) {
      if (m.type == MovementType.stockIn ||
          m.type == MovementType.purchase ||
          m.type == MovementType.returnItem) {
        total += m.quantity;
      } else if (m.type == MovementType.stockOut || m.type == MovementType.sale) {
        total -= m.quantity;
      } else if (m.type == MovementType.adjustment) {
        total += m.quantity; // positive or negative delta
      }
    }
    return total;
  }

  // Unsynced queries
  Future<List<Product>> unsyncedProducts() =>
      (select(products)..where((p) => p.synced.equals(false))).get();

  Future<List<StockMovement>> unsyncedMovements() =>
      (select(stockMovements)..where((m) => m.synced.equals(false))).get();

  Future<List<Sale>> unsyncedSales() =>
      (select(sales)..where((s) => s.synced.equals(false))).get();

  Future<List<Customer>> unsyncedCustomers() =>
      (select(customers)..where((c) => c.synced.equals(false))).get();

  Future<List<CustomerDebt>> unsyncedDebts() =>
      (select(customerDebts)..where((d) => d.synced.equals(false))).get();

  Future<List<DebtPayment>> unsyncedDebtPayments() =>
      (select(debtPayments)..where((p) => p.synced.equals(false))).get();

  Future<List<Supplier>> unsyncedSuppliers() =>
      (select(suppliers)..where((s) => s.synced.equals(false))).get();

  Future<List<Purchase>> unsyncedPurchases() =>
      (select(purchases)..where((p) => p.synced.equals(false))).get();

  Future<List<Profile>> unsyncedProfiles() =>
      (select(profiles)..where((p) => p.synced.equals(false))).get();

  Future<List<Store>> unsyncedStores() =>
      (select(stores)..where((s) => s.synced.equals(false))).get();

  Future<List<StoreMember>> unsyncedStoreMembers() =>
      (select(storeMembers)..where((m) => m.synced.equals(false))).get();

  // Activity log queries
  Future<List<ActivityLog>> getActivitiesForStore(String storeId, {int limit = 100}) =>
      (select(activityLogs)
        ..where((a) => a.storeId.equals(storeId))
        ..orderBy([(a) => OrderingTerm.desc(a.timestamp)])
        ..limit(limit))
      .get();

  Future<List<ActivityLog>> getActivitiesForUser(String storeId, String userId, {int limit = 100}) =>
      (select(activityLogs)
        ..where((a) => a.storeId.equals(storeId) & a.userId.equals(userId))
        ..orderBy([(a) => OrderingTerm.desc(a.timestamp)])
        ..limit(limit))
      .get();

  Future<List<ActivityLog>> unsyncedActivityLogs() =>
      (select(activityLogs)..where((a) => a.synced.equals(false))).get();

  // -----------------------------------------------------------------------
  // DASHBOARD AGGREGATE QUERIES
  // -----------------------------------------------------------------------

  /// Today's total sales revenue for [storeId].
  Future<double> getTodaySalesRevenue(String storeId) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final sumTotal = sales.total.sum();
    final row = await (selectOnly(sales)
          ..where(sales.storeId.equals(storeId) & sales.createdAt.isBiggerOrEqualValue(startOfDay))
          ..addColumns([sumTotal]))
        .getSingle();
    return row.read(sumTotal) ?? 0.0;
  }

  /// Current week's total sales revenue for [storeId].
  Future<double> getWeeklySalesRevenue(String storeId) async {
    final now = DateTime.now();
    final startOfWeek = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    final sumTotal = sales.total.sum();
    final row = await (selectOnly(sales)
          ..where(sales.storeId.equals(storeId) & sales.createdAt.isBiggerOrEqualValue(startOfWeek))
          ..addColumns([sumTotal]))
        .getSingle();
    return row.read(sumTotal) ?? 0.0;
  }

  /// Current month's total sales revenue for [storeId].
  Future<double> getMonthlySalesRevenue(String storeId) async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final sumTotal = sales.total.sum();
    final row = await (selectOnly(sales)
          ..where(sales.storeId.equals(storeId) & sales.createdAt.isBiggerOrEqualValue(startOfMonth))
          ..addColumns([sumTotal]))
        .getSingle();
    return row.read(sumTotal) ?? 0.0;
  }

  /// Total count of completed sales transactions for [storeId].
  Future<int> getSalesTransactionCount(String storeId) async {
    final countExpr = sales.id.count();
    final row = await (selectOnly(sales)
          ..where(sales.storeId.equals(storeId))
          ..addColumns([countExpr]))
        .getSingle();
    return row.read(countExpr) ?? 0;
  }

  /// Sales revenue breakdown grouped by payment method (cash, check, credit) for [storeId].
  Future<Map<PaymentMethod, double>> getPaymentMethodBreakdown(String storeId) async {
    final sumTotal = sales.total.sum();
    final rows = await (selectOnly(sales)
          ..where(sales.storeId.equals(storeId))
          ..addColumns([sales.paymentMethod, sumTotal])
          ..groupBy([sales.paymentMethod]))
        .get();

    final breakdown = <PaymentMethod, double>{};
    for (final row in rows) {
      final rawMethod = row.read(sales.paymentMethod);
      final total = row.read(sumTotal) ?? 0.0;
      if (rawMethod != null && rawMethod >= 0 && rawMethod < PaymentMethod.values.length) {
        final method = PaymentMethod.values[rawMethod];
        breakdown[method] = total;
      }
    }
    return breakdown;
  }

  /// Total count of sales completed by an individual employee for [storeId].
  Future<int> getEmployeeSalesCount(String storeId, String userId) async {
    final countExpr = sales.id.count();
    final row = await (selectOnly(sales)
          ..where(sales.storeId.equals(storeId) & sales.userId.equals(userId))
          ..addColumns([countExpr]))
        .getSingle();
    return row.read(countExpr) ?? 0;
  }

  /// Total count of products registered in store catalog for [storeId].
  Future<int> getProductCount(String storeId) async {
    final countExpr = products.id.count();
    final row = await (selectOnly(products)
          ..where(products.storeId.equals(storeId))
          ..addColumns([countExpr]))
        .getSingle();
    return row.read(countExpr) ?? 0;
  }

  /// Estimated catalog valuation (quantity * sell_price) for [storeId].
  Future<double> getStockValuation(String storeId) async {
    final valuationExpr = CustomExpression<double>('SUM(quantity * sell_price)');
    final row = await (selectOnly(products)
          ..where(products.storeId.equals(storeId))
          ..addColumns([valuationExpr]))
        .getSingle();
    return row.read(valuationExpr) ?? 0.0;
  }

  /// Count of products with stock <= lowStockThreshold for [storeId].
  Future<int> getLowStockCount(String storeId) async {
    final countExpr = products.id.count();
    final row = await (selectOnly(products)
          ..where(products.storeId.equals(storeId) &
              products.quantity.isSmallerOrEqual(products.lowStockThreshold))
          ..addColumns([countExpr]))
        .getSingle();
    return row.read(countExpr) ?? 0;
  }

  /// Count of products with quantity == 0 for [storeId].
  Future<int> getOutOfStockCount(String storeId) async {
    final countExpr = products.id.count();
    final row = await (selectOnly(products)
          ..where(products.storeId.equals(storeId) & products.quantity.equals(0))
          ..addColumns([countExpr]))
        .getSingle();
    return row.read(countExpr) ?? 0;
  }

  /// Total outstanding customer debt balance for [storeId].
  Future<double> getTotalOutstandingDebt(String storeId) async {
    final sumRemaining = customerDebts.remainingAmount.sum();
    final row = await (selectOnly(customerDebts)
          ..where(customerDebts.storeId.equals(storeId))
          ..addColumns([sumRemaining]))
        .getSingle();
    return row.read(sumRemaining) ?? 0.0;
  }

  /// Total count of unpaid/partially-paid customer debts for [storeId].
  Future<int> getUnpaidDebtCount(String storeId) async {
    final countExpr = customerDebts.id.count();
    final row = await (selectOnly(customerDebts)
          ..where(customerDebts.storeId.equals(storeId) &
              customerDebts.remainingAmount.isBiggerThanValue(0))
          ..addColumns([countExpr]))
        .getSingle();
    return row.read(countExpr) ?? 0;
  }
}
