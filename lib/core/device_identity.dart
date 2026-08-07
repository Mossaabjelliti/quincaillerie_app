import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// A stable identifier for this installation, used only for audit/sync metadata.
class DeviceIdentity {
  static const _storageKey = 'sync_device_id';

  static Future<String> get id async {
    final preferences = await SharedPreferences.getInstance();
    final existing = preferences.getString(_storageKey);
    if (existing != null && existing.isNotEmpty) return existing;

    final created = const Uuid().v4();
    await preferences.setString(_storageKey, created);
    return created;
  }
}
