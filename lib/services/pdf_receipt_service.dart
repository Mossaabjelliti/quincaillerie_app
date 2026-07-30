import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../data/local/database.dart';

class PdfReceiptService {
  static String _getPaymentLabel(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cash:
        return 'Espèces';
      case PaymentMethod.check:
        return 'Chèque';
      case PaymentMethod.credit:
        return 'Crédit / Ardoise';
    }
  }

  static String _getUnitSuffix(ProductUnit unit) {
    switch (unit) {
      case ProductUnit.piece:
        return 'pc';
      case ProductUnit.meter:
        return 'm';
      case ProductUnit.kg:
        return 'kg';
      case ProductUnit.liter:
        return 'L';
    }
  }

  /// Generate and open PDF thermal print / preview sheet for a completed Sale
  static Future<void> printReceipt({
    required Sale sale,
    required List<SaleItem> items,
    required List<Product> products,
    String storeName = 'QUINCAILLERIE EXPRESS',
  }) async {
    final pdfBytes = await buildReceiptPdfBytes(
      sale: sale,
      items: items,
      products: products,
      storeName: storeName,
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Ticket_${sale.id.substring(0, 8)}.pdf',
    );
  }

  /// Builds PDF byte array for thermal 80mm format
  static Future<Uint8List> buildReceiptPdfBytes({
    required Sale sale,
    required List<SaleItem> items,
    required List<Product> products,
    required String storeName,
  }) async {
    final doc = pw.Document();
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final productMap = {for (var p in products) p.id: p};

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.all(12),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Store Header
              pw.Center(
                child: pw.Text(
                  storeName,
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Text(
                  'Ticket de caisse',
                  style: const pw.TextStyle(fontSize: 12),
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Divider(thickness: 1),

              // Sale Details
              pw.Text(
                'N° Vente: #${sale.id.substring(0, 8)}',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                'Date: ${dateFormat.format(sale.createdAt)}',
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.Text(
                'Paiement: ${_getPaymentLabel(sale.paymentMethod)}',
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.SizedBox(height: 8),
              pw.Divider(thickness: 1),

              // Items Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Article', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Total', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 4),

              // Items List
              ...items.map((item) {
                final product = productMap[item.productId];
                final prodName = product?.name ?? 'Produit #${item.productId.substring(0, 6)}';
                final unitSuffix = product != null ? _getUnitSuffix(product.unit) : '';

                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        prodName,
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            '  ${item.quantity} $unitSuffix x ${item.unitPrice.toStringAsFixed(3)}',
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                          pw.Text(
                            '${item.subtotal.toStringAsFixed(3)} TND',
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),

              pw.SizedBox(height: 8),
              pw.Divider(thickness: 1),

              // Total Amount
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'TOTAL À PAYER:',
                    style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    '${sale.total.toStringAsFixed(3)} TND',
                    style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
              pw.SizedBox(height: 16),

              // Footer
              pw.Center(
                child: pw.Text(
                  'Merci de votre confiance !',
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ),
            ],
          );
        },
      ),
    );

    return doc.save();
  }
}
