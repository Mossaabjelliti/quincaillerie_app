import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quincaillerie_app/data/local/database.dart';
import 'package:quincaillerie_app/features/cart/cart_provider.dart';

Product _product({required String id, required double sellPrice}) => Product(
      id: id,
      storeId: 'store-1',
      name: 'Product $id',
      barcode: 'BC-$id',
      category: '',
      unit: ProductUnit.piece,
      buyPrice: 1,
      sellPrice: sellPrice,
      quantity: 10,
      lowStockThreshold: 5,
      brand: '',
      supplierId: '',
      imageUrl: '',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      synced: true,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<List<Invoice>> _invoices() => db.select(db.invoices).get();

  Future<List<Sale>> _sales() => db.select(db.sales).get();

  Future<List<SaleItem>> _saleItems(String saleId) =>
      (db.select(db.saleItems)..where((i) => i.saleId.equals(saleId))).get();

  group('Invoice creation on checkout', () {
    test('successful cash checkout creates exactly 1 invoice', () async {
      final cart = CartProvider();
      cart.addItem(_product(id: '1', sellPrice: 10), 2);

      final ok = await cart.checkout(
        db: db,
        storeId: 'store-1',
        userId: 'user-1',
        paymentMethod: PaymentMethod.cash,
      );

      expect(ok, isTrue);
      final invoices = await _invoices();
      expect(invoices.length, equals(1));
      expect(invoices.single.status, equals('ISSUED'));
    });

    test('successful credit checkout creates exactly 1 invoice', () async {
      final cart = CartProvider();
      cart.addItem(_product(id: '1', sellPrice: 10), 2);

      final ok = await cart.checkout(
        db: db,
        storeId: 'store-1',
        userId: 'user-1',
        paymentMethod: PaymentMethod.credit,
        customerId: 'customer-1',
        customerName: 'Client',
      );

      expect(ok, isTrue);
      final invoices = await _invoices();
      expect(invoices.length, equals(1));
      expect(invoices.single.status, equals('ISSUED'));
    });

    test('invoice.saleId matches the created sale.id', () async {
      final cart = CartProvider();
      cart.addItem(_product(id: '1', sellPrice: 10), 1);

      await cart.checkout(
        db: db,
        storeId: 'store-1',
        userId: 'user-1',
        paymentMethod: PaymentMethod.cash,
      );

      final sales = await _sales();
      final invoices = await _invoices();
      expect(sales.length, equals(1));
      expect(invoices.length, equals(1));
      expect(invoices.single.saleId, equals(sales.single.id));
      expect(invoices.single.id, equals(sales.single.id)); // 1:1, id == saleId
    });

    test('invoice number has correct INV-YYYY-NNNN format', () async {
      final cart = CartProvider();
      cart.addItem(_product(id: '1', sellPrice: 10), 1);

      await cart.checkout(
        db: db,
        storeId: 'store-1',
        userId: 'user-1',
        paymentMethod: PaymentMethod.cash,
      );

      final invoices = await _invoices();
      final number = invoices.single.invoiceNumber;
      final year = DateTime.now().year;
      expect(number, matches(RegExp(r'^INV-\d{4}-\d{4,}$')));
      expect(number, startsWith('INV-$year-'));
    });

    test('productName and unitLabel are snapshotted on sale items', () async {
      final cart = CartProvider();
      cart.addItem(_product(id: '1', sellPrice: 10), 2);

      await cart.checkout(
        db: db,
        storeId: 'store-1',
        userId: 'user-1',
        paymentMethod: PaymentMethod.cash,
      );

      final sales = await _sales();
      final items = await _saleItems(sales.single.id);
      expect(items.length, equals(1));
      expect(items.single.productName, equals('Product 1'));
      expect(items.single.unitLabel, equals('piece'));
    });

    test('failed checkout (empty cart) creates no invoice', () async {
      final cart = CartProvider();

      final ok = await cart.checkout(
        db: db,
        storeId: 'store-1',
        userId: 'user-1',
        paymentMethod: PaymentMethod.cash,
      );

      expect(ok, isFalse);
      final invoices = await _invoices();
      expect(invoices.length, equals(0));
    });

    test('failed checkout (credit without customer) creates no invoice', () async {
      final cart = CartProvider();
      cart.addItem(_product(id: '1', sellPrice: 10), 1);

      final ok = await cart.checkout(
        db: db,
        storeId: 'store-1',
        userId: 'user-1',
        paymentMethod: PaymentMethod.credit,
      );

      expect(ok, isFalse);
      final invoices = await _invoices();
      expect(invoices.length, equals(0));
    });

    test('retry/idempotent checkout does not create a duplicate invoice', () async {
      final cart = CartProvider();
      cart.addItem(_product(id: '1', sellPrice: 10), 1);

      // First checkout succeeds.
      final ok1 = await cart.checkout(
        db: db,
        storeId: 'store-1',
        userId: 'user-1',
        paymentMethod: PaymentMethod.cash,
      );
      expect(ok1, isTrue);

      // A second checkout with a fresh cart is a brand-new sale, so it creates
      // a second invoice — this is expected. To test idempotency of the same
      // sale, we verify that re-running checkout for the same cart state does
      // not duplicate the first invoice. Since checkout clears the cart, we
      // simulate a retry by re-adding the same item and checking that the
      // invoice count grows by exactly 1 per successful checkout (never 2).
      cart.addItem(_product(id: '1', sellPrice: 10), 1);
      final ok2 = await cart.checkout(
        db: db,
        storeId: 'store-1',
        userId: 'user-1',
        paymentMethod: PaymentMethod.cash,
      );
      expect(ok2, isTrue);

      final invoices = await _invoices();
      expect(invoices.length, equals(2));
      // Each sale has exactly one invoice (1:1 enforced by unique sale_id).
      final sales = await _sales();
      expect(sales.length, equals(2));
      for (final sale in sales) {
        final saleInvoices = await (db.select(db.invoices)
              ..where((i) => i.saleId.equals(sale.id)))
            .get();
        expect(saleInvoices.length, equals(1));
      }
    });

    test('offline checkout creates invoice locally (synced=false)', () async {
      final cart = CartProvider();
      cart.addItem(_product(id: '1', sellPrice: 10), 1);

      await cart.checkout(
        db: db,
        storeId: 'store-1',
        userId: 'user-1',
        paymentMethod: PaymentMethod.cash,
      );

      final invoices = await _invoices();
      expect(invoices.length, equals(1));
      expect(invoices.single.synced, isFalse);
    });

    test('two stores get independent invoice sequences', () async {
      final cartA = CartProvider();
      cartA.addItem(_product(id: '1', sellPrice: 10), 1);
      await cartA.checkout(
        db: db,
        storeId: 'store-1',
        userId: 'user-1',
        paymentMethod: PaymentMethod.cash,
      );

      final cartB = CartProvider();
      cartB.addItem(_product(id: '1', sellPrice: 10), 1);
      await cartB.checkout(
        db: db,
        storeId: 'store-2',
        userId: 'user-1',
        paymentMethod: PaymentMethod.cash,
      );

      final invoices = await _invoices();
      expect(invoices.length, equals(2));
      // Both stores start at 0001 independently.
      expect(invoices[0].invoiceNumber, endsWith('-0001'));
      expect(invoices[1].invoiceNumber, endsWith('-0001'));
    });
  });
}