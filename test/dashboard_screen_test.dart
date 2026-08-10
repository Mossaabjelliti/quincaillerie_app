import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:drift/native.dart';
import 'package:quincaillerie_app/core/auth/auth_service.dart';
import 'package:quincaillerie_app/core/auth/authorization_service.dart';
import 'package:quincaillerie_app/core/auth/user_role.dart';
import 'package:quincaillerie_app/core/auth/user_session.dart';
import 'package:quincaillerie_app/data/local/database.dart';
import 'package:quincaillerie_app/features/dashboard/dashboard_provider.dart';
import 'package:quincaillerie_app/features/dashboard/dashboard_screen.dart';
import 'package:quincaillerie_app/services/dashboard_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

class FakeAuthService extends Fake implements AuthService {
  @override
  User? get currentUser => null;
}

UserSession _makeSession(UserRole role, String userId, {String storeId = 'store-1'}) => UserSession(
      userId: userId,
      userEmail: '$userId@stocki.app',
      fullName: 'Test User $userId',
      phone: '',
      currentStoreId: storeId,
      currentStoreName: 'Test Store',
      currentRole: role,
      stores: const [],
      storeRoles: {storeId: role},
    );

void main() {
  late AppDatabase db;
  late FakeAuthService authService;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    authService = FakeAuthService();
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildTestableWidget({
    required UserSession session,
    required DashboardProvider dashboardProvider,
    required AuthorizationService authorizationService,
  }) {
    return MultiProvider(
      providers: [
        Provider<AppDatabase>.value(value: db),
        Provider<AuthService>.value(value: authService),
        ChangeNotifierProvider<AuthorizationService>.value(value: authorizationService),
        ChangeNotifierProvider<DashboardProvider>.value(value: dashboardProvider),
      ],
      child: const MaterialApp(
        home: DashboardScreen(storeId: 'store-1'),
      ),
    );
  }

  group('DashboardScreen UI & RBAC Integration Tests', () {
    testWidgets('Owner view renders today revenue, stock valuation, customer debt, and store activity', (tester) async {
      final session = _makeSession(UserRole.owner, 'owner-1');
      final authz = AuthorizationService.fromSession(session);
      final service = DashboardService(db: db, authorizationService: authz);
      final dashboardProvider = DashboardProvider(
        dashboardService: service,
        authorizationService: authz,
      );

      await tester.pumpWidget(buildTestableWidget(
        session: session,
        dashboardProvider: dashboardProvider,
        authorizationService: authz,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Tableau de bord (Propriétaire)'), findsOneWidget);
      expect(find.text('Revenu du Jour'), findsOneWidget);
      expect(find.text('Valeur du Stock'), findsOneWidget);
      expect(find.text('Créances Clients'), findsOneWidget);
      expect(find.text('Activité Récente de la Boutique'), findsOneWidget);
    });

    testWidgets('Employee view renders personal sales, quick actions, own activity, and NO owner financial metrics', (tester) async {
      final session = _makeSession(UserRole.cashier, 'emp-1');
      final authz = AuthorizationService.fromSession(session);
      final service = DashboardService(db: db, authorizationService: authz);
      final dashboardProvider = DashboardProvider(
        dashboardService: service,
        authorizationService: authz,
      );

      await tester.pumpWidget(buildTestableWidget(
        session: session,
        dashboardProvider: dashboardProvider,
        authorizationService: authz,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Tableau de bord (Employé)'), findsOneWidget);
      expect(find.text('Activité Personnelle'), findsOneWidget);
      expect(find.text('Actions Rapides'), findsOneWidget);
      expect(find.text('Nouvelle Vente'), findsOneWidget);
      expect(find.text('Scanner'), findsOneWidget);
      expect(find.text('Vos Dernières Actions'), findsOneWidget);

      // Verify owner-only metrics are strictly hidden
      expect(find.text('Revenu du Jour'), findsNothing);
      expect(find.text('Valeur du Stock'), findsNothing);
      expect(find.text('Créances Clients'), findsNothing);
      expect(find.text('Activité Récente de la Boutique'), findsNothing);
    });
  });
}
