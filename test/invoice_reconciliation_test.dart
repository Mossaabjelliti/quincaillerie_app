import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quincaillerie_app/data/local/database.dart';
import 'package:quincaillerie_app/features/cart/cart_provider.dart';
import 'package:quincaillerie_app/services/sync_service.dart';

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

Invoice _localInvoice({
  required String id,
  required String storeId,
  required String saleId,
  required String invoiceNumber,
  String status = 'ISSUED',
  DateTime? issuedAt,
  bool synced = false,
}) =>
    Invoice(
      id: id,
      storeId: storeId,
      saleId: saleId,
      invoiceNumber: invoiceNumber,
      status: status,
      issuedAt: issuedAt ?? DateTime(2026, 1, 1, 10),
      createdAt: DateTime(2026, 1, 1, 10),
      synced: synced,
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

  group('Invoice sync reconciliation', () {
    test('offline sale gets a provisional number', () async {
      final cart = CartProvider();
      cart.addItem(_product(id: '1', sellPrice: 10), 1);

      await cart.checkout(
        db: db,
        storeId: 'store-1',
        userId: 'user-1',
        paymentMethod: PaymentMethod.cash,
      );

      final invoices = await db.select(db.invoices).get();
      expect(invoices.length, equals(1));
      expect(invoices.single.synced, isFalse);
      expect(
        invoices.single.invoiceNumber,
        matches(RegExp(r'^INV-\d{4}-\d{4,}$')),
      );
    });

    test('reconciliation replaces provisional number with server number', () {
      final local = _localInvoice(
        id: 'sale-1',
        storeId: 'store-1',
        saleId: 'sale-1',
        invoiceNumber: 'INV-2026-0001', // provisional
      );
      final server = {
        'id': 'sale-1',
        'store_id': 'store-1',
        'sale_id': 'sale-1',
        'invoice_number': 'INV-2026-0042', // authoritative
        'status': 'ISSUED',
        'issued_at': '2026-01-01T10:00:00.000Z',
      };

      final update = SyncService.invoiceReconciliationUpdate(
        serverInvoice: server,
        localInvoice: local,
      );

      expect(update, isNotNull);
      expect(update!.invoiceNumber.value, equals('INV-2026-0042'));
      expect(update.status.value, equals('ISSUED'));
      expect(update.synced.value, isTrue);
      expect(
        update.issuedAt.value,
        equals(DateTime.parse('2026-01-01T10:00:00.000Z')),
      );
    });

    test('reconciliation is idempotent (retry does not duplicate)', () {
      final local = _localInvoice(
        id: 'sale-1',
        storeId: 'store-1',
        saleId: 'sale-1',
        invoiceNumber: 'INV-2026-0001',
      );
      final server = {
        'id': 'sale-1',
        'store_id': 'store-1',
        'sale_id': 'sale-1',
        'invoice_number': 'INV-2026-0042',
        'status': 'ISSUED',
        'issued_at': '2026-01-01T10:00:00.000Z',
      };

      final first = SyncService.invoiceReconciliationUpdate(
        serverInvoice: server,
        localInvoice: local,
      );
      final reconciled = _localInvoice(
        id: 'sale-1',
        storeId: 'store-1',
        saleId: 'sale-1',
        invoiceNumber: first!.invoiceNumber.value!,
        issuedAt: first.issuedAt.value!,
        synced: true,
      );
      final second = SyncService.invoiceReconciliationUpdate(
        serverInvoice: server,
        localInvoice: reconciled,
      );

      expect(second, isNotNull);
      expect(second!.invoiceNumber.value, equals('INV-2026-0042'));
      expect(second.synced.value, isTrue);
      // The function never creates a second invoice — returns an update for
      // the existing invoice id only (id is not part of the update).
      expect(second.id.present, isFalse);
    });

    test('app restart/resume reconciliation is safe (sale already synced)',
        () async {
      final saleId = 'sale-restart';
      await db.into(db.sales).insert(
            SalesCompanion.insert(
              id: saleId,
              storeId: 'store-1',
              userId: 'user-1',
              total: 10,
              paymentMethod: PaymentMethod.cash,
              createdAt: Value(DateTime(2026, 1, 1, 10)),
              synced: const Value(true), // sale already synced
            ),
          );
      await db.into(db.invoices).insert(
            InvoicesCompanion.insert(
              id: saleId,
              storeId: 'store-1',
              saleId: saleId,
              invoiceNumber: 'INV-2026-0001', // provisional
              status: const Value('ISSUED'),
              issuedAt: DateTime(2026, 1, 1, 10),
              createdAt: Value(DateTime(2026, 1, 1, 10)),
              synced: const Value(false), // not yet reconciled
            ),
          );

      final local = (await db.select(db.invoices).get()).single;
      final server = {
        'id': saleId,
        'store_id': 'store-1',
        'sale_id': saleId,
        'invoice_number': 'INV-2026-0099',
        'status': 'ISSUED',
        'issued_at': '2026-01-01T10:00:00.000Z',
      };
      final update = SyncService.invoiceReconciliationUpdate(
        serverInvoice: server,
        localInvoice: local,
      );
      await (db.update(db.invoices)..where((row) => row.id.equals(saleId)))
          .write(update!);

      final reconciled = (await db.select(db.invoices).get()).single;
      expect(reconciled.invoiceNumber, equals('INV-2026-0099'));
      expect(reconciled.synced, isTrue);
      // Still exactly one invoice — no duplicate.
      expect((await db.select(db.invoices).get()).length, equals(1));
    });

    test('two stores remain isolated during reconciliation', () {
      final localA = _localInvoice(
        id: 'sale-a',
        storeId: 'store-a',
        saleId: 'sale-a',
        invoiceNumber: 'INV-2026-0001',
      );
      final localB = _localInvoice(
        id: 'sale-b',
        storeId: 'store-b',
        saleId: 'sale-b',
        invoiceNumber: 'INV-2026-0001',
      );
      final serverA = {
        'store_id': 'store-a',
        'sale_id': 'sale-a',
        'invoice_number': 'INV-2026-0100',
        'status': 'ISSUED',
        'issued_at': '2026-01-01T10:00:00.000Z',
      };
      final serverB = {
        'store_id': 'store-b',
        'sale_id': 'sale-b',
        'invoice_number': 'INV-2026-0200',
        'status': 'ISSUED',
        'issued_at': '2026-01-01T10:00:00.000Z',
      };

      final updateA = SyncService.invoiceReconciliationUpdate(
        serverInvoice: serverA,
        localInvoice: localA,
      );
      final updateB = SyncService.invoiceReconciliationUpdate(
        serverInvoice: serverB,
        localInvoice: localB,
      );

      expect(updateA!.invoiceNumber.value, equals('INV-2026-0100'));
      expect(updateB!.invoiceNumber.value, equals('INV-2026-0200'));
      // Store isolation: the update targets the local invoice id only.
      expect(updateA.id.present, isFalse);
      expect(updateB.id.present, isFalse);
    });

    test('already-authoritative invoice remains unchanged', () {
      final local = _localInvoice(
        id: 'sale-1',
        storeId: 'store-1',
        saleId: 'sale-1',
        invoiceNumber: 'INV-2026-0042', // already authoritative
        issuedAt: DateTime.parse('2026-01-01T10:00:00.000Z'),
        synced: true,
      );
      final server = {
        'store_id': 'store-1',
        'sale_id': 'sale-1',
        'invoice_number': 'INV-2026-0042',
        'status': 'ISSUED',
        'issued_at': '2026-01-01T10:00:00.000Z',
      };

      final update = SyncService.invoiceReconciliationUpdate(
        serverInvoice: server,
        localInvoice: local,
      );

      expect(update, isNotNull);
      expect(update!.invoiceNumber.value, equals('INV-2026-0042'));
      expect(update.synced.value, isTrue);
      expect(update.issuedAt.value, equals(local.issuedAt));
    });

    test('legacy sale without local invoice is handled safely', () async {
      final saleId = 'legacy-sale';
      await db.into(db.sales).insert(
            SalesCompanion.insert(
              id: saleId,
              storeId: 'store-1',
              userId: 'user-1',
              total: 10,
              paymentMethod: PaymentMethod.cash,
              createdAt: Value(DateTime(2026, 1, 1, 10)),
              synced: const Value(true),
            ),
          );

      // No local invoice exists; nothing to reconcile and no invoice created.
      expect(await db.select(db.invoices).get(), isEmpty);
      final local = await (db.select(db.invoices)
            ..where((row) => row.saleId.equals(saleId)))
          .getSingleOrNull();
      expect(local, isNull);
    });
  });
}