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

  /// Print thermal 80mm ticket
  static Future<void> printReceipt({
    required Sale sale,
    required List<SaleItem> items,
    required List<Product> products,
    String storeName = 'QUINCAILLERIE PRO',
    String? customerName,
  }) async {
    final pdfBytes = await buildReceiptPdfBytes(
      sale: sale,
      items: items,
      products: products,
      storeName: storeName,
      customerName: customerName,
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Ticket_${sale.id.substring(0, 8)}.pdf',
    );
  }

  /// Print or share full A4 Invoice
  static Future<void> printA4Invoice({
    required Sale sale,
    required List<SaleItem> items,
    required List<Product> products,
    String storeName = 'QUINCAILLERIE PRO',
    String storePhone = '',
    String storeAddress = '',
    String? customerName,
    String? customerPhone,
    String? invoiceNumber,
  }) async {
    final pdfBytes = await buildA4InvoicePdfBytes(
      sale: sale,
      items: items,
      products: products,
      storeName: storeName,
      storePhone: storePhone,
      storeAddress: storeAddress,
      customerName: customerName,
      customerPhone: customerPhone,
      invoiceNumber: invoiceNumber,
    );

    final docName = invoiceNumber != null && invoiceNumber.isNotEmpty
        ? 'Facture_$invoiceNumber.pdf'
        : 'Facture_${sale.id.substring(0, 8)}.pdf';

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: docName,
    );
  }

  static Future<void> printQrLabel({
    required String data,
    required String title,
    String subtitle = '',
  }) async {
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(60 * PdfPageFormat.mm, 40 * PdfPageFormat.mm),
        margin: const pw.EdgeInsets.all(6),
        build: (context) {
          return pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(title, textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              if (subtitle.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Text(subtitle, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 7)),
              ],
              pw.SizedBox(height: 4),
              pw.BarcodeWidget(
                barcode: pw.Barcode.qrCode(),
                data: data,
                width: 80,
                height: 80,
              ),
              pw.SizedBox(height: 2),
              pw.Text(data, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 7)),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => doc.save(),
      name: 'Label_${data}.pdf',
    );
  }

  /// Builds PDF byte array for thermal 80mm format
  static Future<Uint8List> buildReceiptPdfBytes({
    required Sale sale,
    required List<SaleItem> items,
    required List<Product> products,
    required String storeName,
    String? customerName,
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
              pw.Center(
                child: pw.Text(
                  storeName,
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Text('Ticket de caisse', style: const pw.TextStyle(fontSize: 12)),
              ),
              pw.SizedBox(height: 8),
              pw.Divider(thickness: 1),

              pw.Text('N° Vente: #${sale.id.substring(0, 8)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              pw.Text('Date: ${dateFormat.format(sale.createdAt)}', style: const pw.TextStyle(fontSize: 10)),
              if (customerName != null && customerName.isNotEmpty)
                pw.Text('Client: $customerName', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              pw.Text('Paiement: ${_getPaymentLabel(sale.paymentMethod)}', style: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(height: 8),
              pw.Divider(thickness: 1),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Article', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Total', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 4),

              ...items.map((item) {
                final product = productMap[item.productId];
                final prodName = product?.name ?? 'Produit #${item.productId.substring(0, 6)}';
                final unitSuffix = product != null ? _getUnitSuffix(product.unit) : '';

                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(prodName, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('  ${item.quantity} $unitSuffix x ${item.unitPrice.toStringAsFixed(3)}', style: const pw.TextStyle(fontSize: 9)),
                          pw.Text('${item.subtotal.toStringAsFixed(3)} TND', style: const pw.TextStyle(fontSize: 9)),
                        ],
                      ),
                    ],
                  ),
                );
              }),

              pw.SizedBox(height: 8),
              pw.Divider(thickness: 1),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL À PAYER:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  pw.Text('${sale.total.toStringAsFixed(3)} TND', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Center(
                child: pw.Text('Merci de votre confiance !', style: const pw.TextStyle(fontSize: 10)),
              ),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  /// Builds A4 Invoice Format
  static Future<Uint8List> buildA4InvoicePdfBytes({
    required Sale sale,
    required List<SaleItem> items,
    required List<Product> products,
    required String storeName,
    required String storePhone,
    required String storeAddress,
    String? customerName,
    String? customerPhone,
    String? invoiceNumber,
  }) async {
    final doc = pw.Document();
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final productMap = {for (var p in products) p.id: p};
    final displayInvoiceNumber = invoiceNumber != null && invoiceNumber.isNotEmpty
        ? invoiceNumber
        : 'FAC-${sale.id.substring(0, 8).toUpperCase()}';

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header Row
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(storeName, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.amber800)),
                      if (storeAddress.isNotEmpty) pw.Text(storeAddress, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      if (storePhone.isNotEmpty) pw.Text('Tél: $storePhone', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('FACTURE', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900)),
                      pw.Text('N° $displayInvoiceNumber', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Date: ${dateFormat.format(sale.createdAt)}', style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 24),
              pw.Divider(),

              // Customer Info Block
              if (customerName != null && customerName.isNotEmpty) ...[
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Client:', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                      pw.Text(customerName, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                      if (customerPhone != null && customerPhone.isNotEmpty) pw.Text('Tél: $customerPhone', style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),
              ],

              // Table Header
              pw.TableHelper.fromTextArray(
                context: context,
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.amber800),
                headers: ['Désignation', 'Quantité', 'Prix Unitaire (TND)', 'Total (TND)'],
                data: items.map((item) {
                  final p = productMap[item.productId];
                  final name = p?.name ?? 'Produit #${item.productId.substring(0, 6)}';
                  final unitSuffix = p != null ? _getUnitSuffix(p.unit) : '';
                  return [
                    name,
                    '${item.quantity} $unitSuffix',
                    item.unitPrice.toStringAsFixed(3),
                    item.subtotal.toStringAsFixed(3),
                  ];
                }).toList(),
              ),

              pw.SizedBox(height: 20),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    width: 200,
                    child: pw.Column(
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Mode de Paiement:'),
                            pw.Text(_getPaymentLabel(sale.paymentMethod), style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          ],
                        ),
                        pw.Divider(),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('TOTAL NET:', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                            pw.Text('${sale.total.toStringAsFixed(3)} DT', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              pw.Spacer(),
              pw.Center(
                child: pw.Text('Arrêté la présente facture à la somme de ${sale.total.toStringAsFixed(3)} Dinars Tunisiens.', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
              ),
            ],
          );
        },
      ),
    );

    return doc.save();
  }
}
