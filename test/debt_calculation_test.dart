import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Customer Debt & Ardoise Calculation Unit Tests', () {
    test('Calculates remaining debt balance after partial payments', () {
      double totalPurchasedDebt = 350.0;
      double paymentsReceived = 150.0;

      double remainingDebt = totalPurchasedDebt - paymentsReceived;
      expect(remainingDebt, equals(200.0));

      // Add payment of 200.0
      paymentsReceived += 200.0;
      remainingDebt = totalPurchasedDebt - paymentsReceived;
      expect(remainingDebt, equals(0.0));
    });
  });
}
