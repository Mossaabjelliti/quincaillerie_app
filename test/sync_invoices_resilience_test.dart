import 'package:flutter_test/flutter_test.dart';
import 'package:quincaillerie_app/data/local/database.dart';
import 'package:quincaillerie_app/services/sync_service.dart';

void main() {
  group('Sync Invoices Resilience & Manifest Tests', () {
    test('invoiceReconciliationUpdate safely returns null when server row has no invoice_number', () {
      final local = Invoice(
        id: 'inv-1',
        storeId: 'store-1',
        saleId: 'sale-1',
        invoiceNumber: 'INV-2026-0001',
        status: 'ISSUED',
        issuedAt: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
        synced: false,
      );

      final update = SyncService.invoiceReconciliationUpdate(
        serverInvoice: {'status': 'ISSUED'}, // missing invoice_number
        localInvoice: local,
      );

      expect(update, isNull);
    });

    test('invoiceReconciliationUpdate applies authoritative server number cleanly', () {
      final local = Invoice(
        id: 'inv-1',
        storeId: 'store-1',
        saleId: 'sale-1',
        invoiceNumber: 'INV-TEMP-99',
        status: 'ISSUED',
        issuedAt: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
        synced: false,
      );

      final update = SyncService.invoiceReconciliationUpdate(
        serverInvoice: {
          'invoice_number': 'INV-2026-0042',
          'status': 'PAID',
          'issued_at': '2026-08-17T12:00:00.000Z',
        },
        localInvoice: local,
      );

      expect(update, isNotNull);
      expect(update!.invoiceNumber.value, 'INV-2026-0042');
      expect(update.status.value, 'PAID');
      expect(update.synced.value, isTrue);
    });
  });
}
