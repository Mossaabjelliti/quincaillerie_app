import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart';
import '../core/activity/activity_entry.dart';
import '../core/auth/authorization_service.dart';
import '../core/auth/permission.dart';
import '../data/local/database.dart';

/// Centralized service for logging and querying Stocki activity trails.
///
/// Integrates with [AuthorizationService] to enforce RBAC permissions for
/// owner-wide ([Permission.activityView]) and employee-own ([Permission.activityViewOwn])
/// activity inspection.
class ActivityService {
  final AppDatabase db;
  final AuthorizationService? authz;

  ActivityService({required this.db, this.authz});

  /// Logs a new activity entry to the local database for offline tracking & sync.
  Future<ActivityEntry> logActivity({
    required String storeId,
    required String userId,
    required String action,
    required String entityType,
    required String entityId,
    Map<String, dynamic> metadata = const {},
    DateTime? timestamp,
  }) async {
    const uuid = Uuid();
    final entryId = uuid.v4();
    final entryTime = timestamp ?? DateTime.now();

    await db.into(db.activityLogs).insertOnConflictUpdate(
          ActivityLogsCompanion.insert(
            id: entryId,
            storeId: storeId,
            userId: userId,
            action: action,
            entityType: entityType,
            entityId: entityId,
            timestamp: Value(entryTime),
            metadata: Value(jsonEncode(metadata)),
            synced: const Value(false),
          ),
        );

    return ActivityEntry(
      id: entryId,
      storeId: storeId,
      userId: userId,
      action: action,
      entityType: entityType,
      entityId: entityId,
      timestamp: entryTime,
      metadata: metadata,
    );
  }

  /// Retrieves owner-wide activities for [storeId].
  /// Requires [Permission.activityView]. Throws [StateError] if unauthorized.
  Future<List<ActivityEntry>> getStoreActivities({
    required String storeId,
    int limit = 100,
  }) async {
    if (authz != null && !authz!.can(Permission.activityView)) {
      throw StateError('Permission denied: requires activity.view');
    }
    final rows = await db.getActivitiesForStore(storeId, limit: limit);
    return rows.map(_rowToEntry).toList();
  }

  /// Retrieves user-specific activities for [storeId] and [userId].
  ///
  /// - When querying own activity: requires [Permission.activityViewOwn] or [Permission.activityView].
  /// - When querying another employee's activity: requires [Permission.activityView].
  /// Throws [StateError] if unauthorized.
  Future<List<ActivityEntry>> getUserActivities({
    required String storeId,
    required String userId,
    int limit = 100,
  }) async {
    if (authz != null) {
      final currentUserId = authz?.session?.userId;
      final isOwn = currentUserId != null && currentUserId == userId;

      if (isOwn) {
        if (!authz!.can(Permission.activityViewOwn) && !authz!.can(Permission.activityView)) {
          throw StateError('Permission denied: requires activity.view_own or activity.view');
        }
      } else {
        if (!authz!.can(Permission.activityView)) {
          throw StateError('Permission denied: requires activity.view');
        }
      }
    }

    final rows = await db.getActivitiesForUser(storeId, userId, limit: limit);
    return rows.map(_rowToEntry).toList();
  }

  /// Converts a Drift [ActivityLog] row to an [ActivityEntry] model object.
  ActivityEntry _rowToEntry(ActivityLog row) {
    Map<String, dynamic> meta = const {};
    if (row.metadata.isNotEmpty) {
      try {
        meta = jsonDecode(row.metadata) as Map<String, dynamic>;
      } catch (_) {}
    }
    return ActivityEntry(
      id: row.id,
      storeId: row.storeId,
      userId: row.userId,
      action: row.action,
      entityType: row.entityType,
      entityId: row.entityId,
      timestamp: row.timestamp,
      metadata: meta,
    );
  }
}
