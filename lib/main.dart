import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
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
import 'core/licensing/license_repository.dart';
import 'core/licensing/license_service.dart';
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
import 'features/desktop/desktop_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabaseAnonKey,
    );
  } catch (e) {
    debugPrint('Supabase initialization error: $e');
  }

  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    try {
      await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
      await Workmanager().registerPeriodicTask(
        'daily-sync-unique',
        dailySyncTask,
        frequency: const Duration(hours: 24),
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      );
    } catch (e) {
      debugPrint('Workmanager background sync initialization error: $e');
    }
  }

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
        ChangeNotifierProvider<LicenseService>(
          create: (_) => LicenseService(repository: CachedLicenseRepository())..load(),
        ),
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
      title: 'Quincaillerie Pro OS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routes: {
        '/add-product': (context) {
          final session = context.read<AuthProvider>().session;
          final barcode = ModalRoute.of(context)?.settings.arguments as String?;
          return AddProductScreen(
            storeId: session?.currentStoreId ?? 'demo-store',
            userId: session?.userId ?? 'demo-user',
            initialBarcode: barcode,
          );
        },
        '/cart': (context) {
          final session = context.read<AuthProvider>().session;
          return CartScreen(
            storeId: session?.currentStoreId ?? 'demo-store',
            userId: session?.userId ?? 'demo-user',
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
          return !kIsWeb && Platform.isWindows
              ? DesktopShell(
                  storeId: auth.session!.currentStoreId!,
                  userId: auth.session!.userId,
                )
              : _HomeShell(
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
    final canManageStock = auth.session?.canManageStock ?? true;
    final canViewFinancials = auth.session?.canViewFinancials ?? true;

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
            icon: const Icon(Icons.sync_problem_rounded),
            tooltip: 'Logs de Synchronisation',
            onPressed: () {
              Navigator.of(context).pushNamed('/sync-logs');
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
          final status = await syncService.syncNow(storeId: widget.storeId);
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
