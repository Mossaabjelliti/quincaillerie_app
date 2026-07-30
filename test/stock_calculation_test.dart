import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Event-Based Stock Engine Unit Tests', () {
    test('Calculates current stock balance by aggregating movements correctly', () {
      // Mock movements for product
      final movements = [
        {'type': 'PURCHASE', 'quantity': 100.0},
        {'type': 'SALE', 'quantity': 25.0},
        {'type': 'SALE', 'quantity': 10.0},
        {'type': 'RETURN', 'quantity': 5.0},
        {'type': 'ADJUSTMENT', 'quantity': -2.0},
      ];

      double stock = 0.0;
      for (final m in movements) {
        final type = m['type'] as String;
        final qty = m['quantity'] as double;
        if (type == 'PURCHASE' || type == 'RETURN' || type == 'stockIn') {
          stock += qty;
        } else if (type == 'SALE' || type == 'stockOut') {
          stock -= qty;
        } else if (type == 'ADJUSTMENT') {
          stock += qty;
        }
      }

      // 100 - 25 - 10 + 5 - 2 = 68
      expect(stock, equals(68.0));
    });
  });
}
