import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'data/local/database.dart';
import 'services/sync_service.dart';
import 'features/scan/scan_screen.dart';
import 'features/dashboard/dashboard_screen.dart';

import 'features/add_product/add_product_screen.dart';
import 'features/cart/cart_provider.dart';
import 'features/cart/cart_screen.dart';
import 'features/inventory/inventory_screen.dart';
import 'features/sales/sales_screen.dart';
import 'features/qr_generator/qr_generator_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Replace with your real project values (Supabase dashboard > Settings > API).
  await Supabase.initialize(
    url: 'https://YOUR_PROJECT.supabase.co',
    publishableKey: 'YOUR_ANON_KEY',
  );

  final db = AppDatabase();
  final syncService = SyncService(db: db, supabase: Supabase.instance.client);

  runApp(
    MultiProvider(
      providers: [
        Provider<AppDatabase>.value(value: db),
        Provider<SyncService>.value(value: syncService),
        ChangeNotifierProvider<CartProvider>(create: (_) => CartProvider()),
      ],
      child: const QuincaillerieApp(),
    ),
  );
}

class QuincaillerieApp extends StatelessWidget {
  const QuincaillerieApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quincaillerie Stock',
      theme: ThemeData(
        colorSchemeSeed: Colors.blueGrey,
        useMaterial3: true,
      ),
      routes: {
        '/add-product': (context) {
          final barcode = ModalRoute.of(context)?.settings.arguments as String?;
          return AddProductScreen(
            storeId: 'demo-store',
            initialBarcode: barcode,
          );
        },
        '/cart': (context) => const CartScreen(
              storeId: 'demo-store',
              userId: 'demo-user',
            ),
        '/qr-generator': (context) {
          final product = ModalRoute.of(context)?.settings.arguments as Product?;
          return QrGeneratorScreen(product: product);
        },
      },
      // TODO Phase 1: real auth flow. Hardcoded ids below unblock scaffolding
      // and let you test the scan -> stock -> dashboard loop end to end.
      home: const _HomeShell(storeId: 'demo-store', userId: 'demo-user'),
    );
  }
}

class _HomeShell extends StatefulWidget {
  final String storeId;
  final String userId;
  const _HomeShell({required this.storeId, required this.userId});

  @override
  State<_HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<_HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      ScanScreen(storeId: widget.storeId, userId: widget.userId),
      InventoryScreen(storeId: widget.storeId),
      SalesScreen(storeId: widget.storeId),
      DashboardScreen(storeId: widget.storeId),
    ];

    return Scaffold(
      body: screens[_index],
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.sync),
        label: const Text('Synchroniser'),
        onPressed: () async {
          final syncService = context.read<SyncService>();
          final status = await syncService.syncNow();
          if (!context.mounted) return;
          final message = switch (status) {
            SyncStatus.success => 'Synchronisation réussie',
            SyncStatus.offline => 'Pas de connexion internet',
            SyncStatus.failed => 'Échec de la synchronisation',
            _ => 'Synchronisation en cours...',
          };
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
        },
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.qr_code_scanner), label: 'Scanner'),
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), label: 'Inventaire'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'Ventes'),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Tableau de bord'),
        ],
      ),
    );
  }
}
