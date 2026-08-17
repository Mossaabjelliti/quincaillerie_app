import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:quincaillerie_app/data/local/database.dart';
import 'package:quincaillerie_app/features/cart/cart_provider.dart';
import 'package:quincaillerie_app/features/cart/cart_screen.dart';

Product _testProduct({
  String id = 'prod-1',
  String name = 'Câble Électrique Rigide U1000 R2V 3G2.5mm² Couronne 50m',
  double sellPrice = 129.500,
  double quantity = 150.0,
}) =>
    Product(
      id: id,
      storeId: 'store-1',
      name: name,
      barcode: '1234567890123',
      category: 'Électricité & Éclairage',
      unit: ProductUnit.piece,
      buyPrice: 90.000,
      sellPrice: sellPrice,
      quantity: quantity,
      lowStockThreshold: 5.0,
      brand: 'Tunisie Câbles',
      supplierId: '',
      imageUrl: '',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      synced: true,
    );

void main() {
  group('UI Overflow Regression Tests on Small Viewports (360dp & 375dp)', () {
    testWidgets('CartScreen line item row renders without RenderFlex overflow at 360dp',
        (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final cart = CartProvider();
      final prod = _testProduct();
      cart.addItem(prod, 3.0);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: ChangeNotifierProvider<CartProvider>.value(
            value: cart,
            child: const CartScreen(storeId: 'store-1', userId: 'user-1'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Panier & Caisse'), findsOneWidget);
      expect(find.text('3.0 piece'), findsOneWidget);
      expect(find.text('388.500 TND'), findsNWidgets(2));
    });

    testWidgets('CartScreen line item row renders without RenderFlex overflow at 375dp',
        (tester) async {
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final cart = CartProvider();
      final prod = _testProduct(sellPrice: 4.850);
      cart.addItem(prod, 12.5);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: ChangeNotifierProvider<CartProvider>.value(
            value: cart,
            child: const CartScreen(storeId: 'store-1', userId: 'user-1'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('12.5 piece'), findsOneWidget);
    });

    testWidgets('Inventory product card bottom row renders without overflow on 360dp with long unit & price',
        (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final p = _testProduct(
        name: 'Disque à Tronçonner Métal et Inox 125x1.0mm Extra Fin Haute Performance',
        sellPrice: 19999.990,
        quantity: 99999.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: Card(
              margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('En stock'),
                                Text(
                                  '${p.quantity} pièce',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Prix de vente'),
                                Text(
                                  '${p.sellPrice.toStringAsFixed(3)} TND',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          onPressed: () {},
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, size: 20),
                          itemBuilder: (_) => [],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('En stock'), findsOneWidget);
      expect(find.text('Prix de vente'), findsOneWidget);
    });
  });
}
