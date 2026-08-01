import 'package:flutter_test/flutter_test.dart';
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
  test('cart pricing multiplier affects total amount', () {
    final cart = CartProvider();
    cart.addItem(_product(id: '1', sellPrice: 10), 2);
    expect(cart.totalAmount, equals(20));

    cart.setCustomer(customerId: 'customer-1', customerName: 'Client', priceMultiplier: 0.95);
    expect(cart.customerId, equals('customer-1'));
    expect(cart.priceMultiplier, equals(0.95));
    expect(cart.totalAmount, closeTo(19, 0.0001));
  });

  test('cart clear resets pricing and customer state', () {
    final cart = CartProvider();
    cart.setCustomer(customerId: 'customer-1', customerName: 'Client', priceMultiplier: 0.95);
    cart.clear();

    expect(cart.customerId, isNull);
    expect(cart.customerName, isNull);
    expect(cart.priceMultiplier, equals(1.0));
    expect(cart.isEmpty, isTrue);
  });
}
