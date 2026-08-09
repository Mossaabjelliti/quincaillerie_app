import 'dart:convert';

/// Represents a recorded activity trail entry in Stocki.
///
/// Contains standard auditing attributes: [userId], [action], [entityType],
/// [entityId], [timestamp], and flexible [metadata].
class ActivityEntry {
  final String id;
  final String storeId;
  final String userId;
  final String action;
  final String entityType;
  final String entityId;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  const ActivityEntry({
    required this.id,
    required this.storeId,
    required this.userId,
    required this.action,
    required this.entityType,
    required this.entityId,
    required this.timestamp,
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'store_id': storeId,
        'user_id': userId,
        'action': action,
        'entity_type': entityType,
        'entity_id': entityId,
        'timestamp': timestamp.toIso8601String(),
        'metadata': metadata,
      };

  factory ActivityEntry.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> parsedMetadata = const {};
    final rawMeta = json['metadata'];
    if (rawMeta is Map<String, dynamic>) {
      parsedMetadata = rawMeta;
    } else if (rawMeta is String && rawMeta.isNotEmpty) {
      try {
        parsedMetadata = jsonDecode(rawMeta) as Map<String, dynamic>;
      } catch (_) {}
    }

    return ActivityEntry(
      id: json['id'] as String? ?? '',
      storeId: json['store_id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      action: json['action'] as String? ?? '',
      entityType: json['entity_type'] as String? ?? '',
      entityId: json['entity_id'] as String? ?? '',
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
      metadata: parsedMetadata,
    );
  }
}
