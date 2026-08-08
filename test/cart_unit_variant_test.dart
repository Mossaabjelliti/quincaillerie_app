import 'package:flutter_test/flutter_test.dart';
import 'package:quincaillerie_app/data/local/database.dart';
import 'package:quincaillerie_app/features/cart/cart_provider.dart';

Product _product({required String id, required double sellPrice}) => Product(
      id: id,
      storeId: 'store-1',
      name: 'Câble $id',
      barcode: 'BC-$id',
      category: 'Électricité & Éclairage',
      unit: ProductUnit.meter,
      buyPrice: 1,
      sellPrice: sellPrice,
      quantity: 100,
      lowStockThreshold: 5,
      brand: '',
      supplierId: '',
      imageUrl: '',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      synced: true,
    );

ProductUnitConversion _unit({
  required String productId,
  required String unitName,
  required double factor,
  required double price,
}) =>
    ProductUnitConversion(
      id: 'unit-$productId-$unitName',
      storeId: 'store-1',
      productId: productId,
      unitName: unitName,
      conversionFactor: factor,
      sellingPrice: price,
      synced: true,
    );

ProductVariant _variant({
  required String productId,
  required String variantName,
  required double price,
}) =>
    ProductVariant(
      id: 'var-$productId-$variantName',
      storeId: 'store-1',
      productId: productId,
      variantName: variantName,
      barcode: 'V-$variantName',
      buyPrice: 0,
      sellPrice: price,
      stockQuantity: 10,
      synced: true,
    );

void main() {
  group('CartItem unit & variant pricing', () {
    test('base product uses its own sell price', () {
      final product = _product(id: '1', sellPrice: 10.0);
      final item = CartItem(product: product, quantity: 2);

      expect(item.effectiveUnitPrice, equals(10.0));
      expect(item.subtotal, equals(20.0));
      expect(item.unitLabel, equals('meter'));
    });

    test('unit conversion overrides base price', () {
      final product = _product(id: '1', sellPrice: 10.0);
      final unit = _unit(
        productId: '1',
        unitName: 'Carton',
        factor: 50,
        price: 450.0,
      );
      final item = CartItem(product: product, quantity: 1, unitConversion: unit);

      expect(item.effectiveUnitPrice, equals(450.0));
      expect(item.subtotal, equals(450.0));
      expect(item.unitLabel, equals('Carton'));
    });

    test('variant overrides both base and unit conversion price', () {
      final product = _product(id: '1', sellPrice: 10.0);
      final unit = _unit(
        productId: '1',
        unitName: 'Carton',
        factor: 50,
        price: 450.0,
      );
      final variant = _variant(
        productId: '1',
        variantName: '2.5mm / 50m',
        price: 850.0,
      );
      final item = CartItem(
        product: product,
        quantity: 3,
        unitConversion: unit,
        variant: variant,
      );

      expect(item.effectiveUnitPrice, equals(850.0));
      expect(item.subtotal, equals(2550.0));
      expect(item.unitLabel, equals('2.5mm / 50m'));
    });
  });

  group('CartProvider with units and variants', () {
    test('addItem with unit/variant stores effective pricing', () {
      final cart = CartProvider();
      final product = _product(id: '1', sellPrice: 10.0);
      final unit = _unit(
        productId: '1',
        unitName: 'Rouleau',
        factor: 10,
        price: 90.0,
      );
      cart.addItem(product, 2, unit);

      expect(cart.itemCount, equals(1));
      expect(cart.totalAmount, equals(180.0)); // 90 * 2

      cart.addItem(product, 1, unit);
      expect(cart.totalAmount, equals(270.0)); // 90 * 3
    });

    test('addItem with variant computes total correctly', () {
      final cart = CartProvider();
      final product = _product(id: '1', sellPrice: 10.0);
      final variant = _variant(
        productId: '1',
        variantName: '1.5mm / 10m',
        price: 25.0,
      );
      cart.addItem(product, 4, null, variant);

      expect(cart.itemCount, equals(1));
      expect(cart.totalAmount, equals(100.0)); // 25 * 4
    });

    test('clear resets cart and customer state with units', () {
      final cart = CartProvider();
      final product = _product(id: '1', sellPrice: 10.0);
      final variant = _variant(
        productId: '1',
        variantName: '4mm / 100m',
        price: 120.0,
      );
      cart.addItem(product, 1, null, variant);
      cart.setCustomer(customerId: 'customer-1', customerName: 'Client', priceMultiplier: 0.95);

      cart.clear();

      expect(cart.isEmpty, isTrue);
      expect(cart.customerId, isNull);
      expect(cart.priceMultiplier, equals(1.0));
    });
  });
}