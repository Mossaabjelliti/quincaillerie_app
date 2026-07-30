import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../data/local/database.dart';

class QrGeneratorScreen extends StatelessWidget {
  final Product? product;

  const QrGeneratorScreen({super.key, this.product});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String barcodeData = product?.barcode ?? '123456789';
    final String productName = product?.name ?? 'Code-barres personnalisé';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Générateur QR / Code-barres'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Text(
                        productName,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (product != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Catégorie: ${product!.category} | Prix: ${product!.sellPrice.toStringAsFixed(3)} TND',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      QrImageView(
                        data: barcodeData,
                        version: QrVersions.auto,
                        size: 220.0,
                        backgroundColor: Colors.white,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Code: $barcodeData',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontFamily: 'Monospace',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Card(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(Icons.print_outlined, color: theme.colorScheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Imprimez ou collez cette étiquette QR sur vos produits au mètre ou au kilo sans code-barres d\'usine.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
