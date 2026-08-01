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
  TextColumn get role => text().withDefault(const Constant('owner'))(); // owner, manager, cashier, stock_manager
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

  @override
  Set<Column> get primaryKey => {id};
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
  Customers,
  CustomerDebts,
  DebtPayments,
  Suppliers,
  Purchases,
  PurchaseItems,
  SyncLogs,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(openDatabase());

  @override
  int get schemaVersion => 2;

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
}
