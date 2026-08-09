import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:quincaillerie_app/core/activity/activity_entry.dart';
import 'package:quincaillerie_app/core/auth/authorization_service.dart';
import 'package:quincaillerie_app/core/auth/user_role.dart';
import 'package:quincaillerie_app/core/auth/user_session.dart';
import 'package:quincaillerie_app/data/local/database.dart';
import 'package:quincaillerie_app/services/activity_service.dart';

UserSession _sessionForRole(UserRole role, String userId) => UserSession(
      userId: userId,
      userEmail: '$userId@store.com',
      fullName: 'Test User $userId',
      phone: '',
      currentStoreId: 'store-1',
      currentStoreName: 'Test Store',
      currentRole: role,
      stores: const [],
      storeRoles: {'store-1': role},
    );

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('ActivityEntry Model Tests', () {
    test('toJson and fromJson round-trip correctly with metadata map', () {
      final now = DateTime.now();
      final entry = ActivityEntry(
        id: 'act-1',
        storeId: 'store-1',
        userId: 'user-1',
        action: 'product.create',
        entityType: 'product',
        entityId: 'prod-100',
        timestamp: now,
        metadata: {'name': 'Vis 4x40', 'quantity': 50},
      );

      final json = entry.toJson();
      expect(json['id'], equals('act-1'));
      expect(json['action'], equals('product.create'));
      expect(json['entity_type'], equals('product'));

      final restored = ActivityEntry.fromJson(json);
      expect(restored.id, equals('act-1'));
      expect(restored.storeId, equals('store-1'));
      expect(restored.userId, equals('user-1'));
      expect(restored.action, equals('product.create'));
      expect(restored.entityType, equals('product'));
      expect(restored.entityId, equals('prod-100'));
      expect(restored.metadata['name'], equals('Vis 4x40'));
      expect(restored.metadata['quantity'], equals(50));
    });
  });

  group('ActivityService Integration & Authorization Tests', () {
    test('logActivity persists activity entry with required fields', () async {
      final service = ActivityService(db: db);
      final entry = await service.logActivity(
        storeId: 'store-1',
        userId: 'emp-1',
        action: 'sale.create',
        entityType: 'sale',
        entityId: 'sale-999',
        metadata: {'total': 150.5},
      );

      expect(entry.id, isNotEmpty);
      expect(entry.storeId, equals('store-1'));
      expect(entry.userId, equals('emp-1'));
      expect(entry.action, equals('sale.create'));
      expect(entry.entityType, equals('sale'));
      expect(entry.entityId, equals('sale-999'));
      expect(entry.metadata['total'], equals(150.5));

      final stored = await db.getActivitiesForStore('store-1');
      expect(stored.length, equals(1));
      expect(stored.first.action, equals('sale.create'));
    });

    test('owner can retrieve store-wide activities', () async {
      final ownerAuthz = AuthorizationService.fromSession(_sessionForRole(UserRole.owner, 'owner-1'));
      final service = ActivityService(db: db, authz: ownerAuthz);

      await service.logActivity(
        storeId: 'store-1',
        userId: 'emp-1',
        action: 'stock.adjust',
        entityType: 'product',
        entityId: 'p-1',
      );
      await service.logActivity(
        storeId: 'store-1',
        userId: 'emp-2',
        action: 'sale.create',
        entityType: 'sale',
        entityId: 's-1',
      );

      final activities = await service.getStoreActivities(storeId: 'store-1');
      expect(activities.length, equals(2));
    });

    test('employee without activity.view cannot retrieve store-wide activities', () async {
      final employeeAuthz = AuthorizationService.fromSession(_sessionForRole(UserRole.employee, 'emp-1'));
      final service = ActivityService(db: db, authz: employeeAuthz);

      await service.logActivity(
        storeId: 'store-1',
        userId: 'emp-1',
        action: 'sale.create',
        entityType: 'sale',
        entityId: 's-1',
      );

      expect(
        () => service.getStoreActivities(storeId: 'store-1'),
        throwsA(isA<StateError>()),
      );
    });

    test('employee with activity.view_own can retrieve own activities', () async {
      final employeeAuthz = AuthorizationService.fromSession(_sessionForRole(UserRole.employee, 'emp-1'));
      final service = ActivityService(db: db, authz: employeeAuthz);

      await service.logActivity(
        storeId: 'store-1',
        userId: 'emp-1',
        action: 'sale.create',
        entityType: 'sale',
        entityId: 's-1',
      );

      final ownActivities = await service.getUserActivities(
        storeId: 'store-1',
        userId: 'emp-1',
      );
      expect(ownActivities.length, equals(1));
      expect(ownActivities.first.userId, equals('emp-1'));
    });
  });
}
