import 'package:flutter_test/flutter_test.dart';

String? validateBarcode(String? val) {
  if (val == null || val.trim().isEmpty) {
    return 'Veuillez saisir un code-barres';
  }
  final trimmed = val.trim();
  final lower = trimmed.toLowerCase();
  if (lower.startsWith('http://') ||
      lower.startsWith('https://') ||
      lower.startsWith('www.') ||
      lower.contains('rawpixel') ||
      lower.contains('.com/') ||
      lower.contains('.shop/')) {
    return 'Le code-barres ne peut pas être un lien URL ou une adresse web';
  }
  return null;
}

void main() {
  group('Barcode Validator Unit Tests', () {
    test('accepts standard EAN-13, UPC, Code-128, and internal reference codes', () {
      expect(validateBarcode('1234567890123'), isNull);
      expect(validateBarcode('CAB-2.5-BLUE'), isNull);
      expect(validateBarcode('619123456789'), isNull);
      expect(validateBarcode('VIS-M4-40'), isNull);
      expect(validateBarcode('987654'), isNull);
    });

    test('rejects empty or whitespace-only values', () {
      expect(validateBarcode(null), 'Veuillez saisir un code-barres');
      expect(validateBarcode(''), 'Veuillez saisir un code-barres');
      expect(validateBarcode('   '), 'Veuillez saisir un code-barres');
    });

    test('rejects HTTP and HTTPS URLs', () {
      expect(
        validateBarcode('https://www.rawpixel.com/image/123'),
        'Le code-barres ne peut pas être un lien URL ou une adresse web',
      );
      expect(
        validateBarcode('http://10000articles.shop/item/456'),
        'Le code-barres ne peut pas être un lien URL ou une adresse web',
      );
      expect(
        validateBarcode('https://example.com/cable'),
        'Le code-barres ne peut pas être un lien URL ou une adresse web',
      );
    });

    test('rejects www URLs and domain paths', () {
      expect(
        validateBarcode('www.quincaillerie.tn/p/99'),
        'Le code-barres ne peut pas être un lien URL ou une adresse web',
      );
      expect(
        validateBarcode('cdn.rawpixel.com/photo.jpg'),
        'Le code-barres ne peut pas être un lien URL ou une adresse web',
      );
    });
  });
}
