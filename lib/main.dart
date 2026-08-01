import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workmanager/workmanager.dart';
import 'core/app_config.dart';
import 'data/local/database.dart';
import 'services/sync_background.dart';
import 'services/sync_service.dart';
import 'core/auth/auth_service.dart';
import 'core/auth/auth_provider.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/store_selection_screen.dart';
import 'features/scan/scan_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'theme/app_theme.dart';
import 'features/add_product/add_product_screen.dart';
import 'features/cart/cart_provider.dart';
import 'features/cart/cart_screen.dart';
import 'features/inventory/inventory_screen.dart';
import 'features/sales/sales_screen.dart';
import 'features/qr_generator/qr_generator_screen.dart';
import 'features/customers/customer_debt_screen.dart';
import 'features/suppliers/supplier_management_screen.dart';
import 'features/sync/sync_logs_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabaseAnonKey,
  );

  await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  await Workmanager().registerPeriodicTask(
    'daily-sync-unique',
    dailySyncTask,
    frequency: const Duration(hours: 24),
    constraints: Constraints(networkType: NetworkType.connected),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
  );

  final db = AppDatabase();
  final authService = AuthService(supabase: Supabase.instance.client);
  final syncService = SyncService(db: db, supabase: Supabase.instance.client);

  runApp(
    MultiProvider(
      providers: [
        Provider<AppDatabase>.value(value: db),
        Provider<AuthService>.value(value: authService),
        Provider<SyncService>.value(value: syncService),
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(authService: authService, db: db),
        ),
        ChangeNotifierProvider<CartProvider>(create: (_) => CartProvider()),
      ],
      child: const QuincaillerieApp(),
    ),
  );
}

class QuincaillerieApp extends StatelessWidget {
  const QuincaillerieApp({super.key});

  Widget _missingStoreScreen() {
    return const StoreSelectionScreen();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quincaillerie Pro OS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routes: {
        '/add-product': (context) {
          final session = context.read<AuthProvider>().session;
          final barcode = ModalRoute.of(context)?.settings.arguments as String?;
          if (session?.hasActiveStore != true) {
            return _missingStoreScreen();
          }
          return AddProductScreen(
            storeId: session!.currentStoreId!,
            initialBarcode: barcode,
          );
        },
        '/cart': (context) {
          final session = context.read<AuthProvider>().session;
          if (session?.hasActiveStore != true) {
            return _missingStoreScreen();
          }
          return CartScreen(
            storeId: session!.currentStoreId!,
            userId: session.userId,
          );
        },
        '/qr-generator': (context) {
          final product = ModalRoute.of(context)?.settings.arguments as Product?;
          return QrGeneratorScreen(product: product);
        },
        '/customers': (context) => const CustomerDebtScreen(),
        '/suppliers': (context) => const SupplierManagementScreen(),
        '/sync-logs': (context) => const SyncLogsScreen(),
      },
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    switch (auth.status) {
      case AuthStatus.authenticating:
        return const Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Colors.amber),
                SizedBox(height: 16),
                Text('Chargement de l\'espace Quincaillerie...'),
              ],
            ),
          ),
        );
      case AuthStatus.authenticated:
        if (auth.session != null && auth.session!.hasActiveStore) {
          return _HomeShell(
            storeId: auth.session!.currentStoreId!,
            userId: auth.session!.userId,
          );
        }
        return const StoreSelectionScreen();
      case AuthStatus.noStore:
        return const StoreSelectionScreen();
      case AuthStatus.uninitialized:
      case AuthStatus.error:
        return const LoginScreen();
    }
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
    final auth = context.watch<AuthProvider>();
    final session = auth.session;
    final canManageStock = session?.canManageStock ?? false;
    final canViewFinancials = session?.canViewFinancials ?? false;
    final screens = [
      ScanScreen(storeId: widget.storeId, userId: widget.userId, canManageStock: canManageStock),
      InventoryScreen(storeId: widget.storeId, canManageStock: canManageStock),
      SalesScreen(storeId: widget.storeId, canViewFinancials: canViewFinancials),
      DashboardScreen(storeId: widget.storeId),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(auth.session?.currentStoreName ?? 'Quincaillerie'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'customers':
                  Navigator.of(context).pushNamed('/customers');
                  break;
                case 'suppliers':
                  Navigator.of(context).pushNamed('/suppliers');
                  break;
                case 'logs':
                  Navigator.of(context).pushNamed('/sync-logs');
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'customers', child: Text('Clients & ardoises')),
              if (auth.session?.canManageStock ?? false)
                const PopupMenuItem(value: 'suppliers', child: Text('Fournisseurs')),
              const PopupMenuItem(value: 'logs', child: Text('Journaux de sync')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.swap_horiz_rounded),
            tooltip: 'Changer de magasin',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const StoreSelectionScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Déconnexion',
            onPressed: () => auth.signOut(),
          ),
        ],
      ),
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
