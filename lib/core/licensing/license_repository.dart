import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'license_state.dart';

abstract class LicenseRepository {
  Future<LicenseRecord?> readCached();
  Future<void> saveCached(LicenseRecord license);
  Future<void> clearCached();
}

/// Cache adapter only. A production implementation may replace this with OS
/// secure storage without affecting feature or business code.
class CachedLicenseRepository implements LicenseRepository {
  static const _key = 'signed_license_cache';
  @override
  Future<LicenseRecord?> readCached() async {
    final value = (await SharedPreferences.getInstance()).getString(_key);
    return value == null ? null : LicenseRecord.fromJson(jsonDecode(value) as Map<String, dynamic>);
  }
  @override
  Future<void> saveCached(LicenseRecord license) async =>
      (await SharedPreferences.getInstance()).setString(_key, jsonEncode(license.toJson()));
  @override
  Future<void> clearCached() async => (await SharedPreferences.getInstance()).remove(_key);
}

abstract class DeviceActivationGateway {
  Future<void> registerDevice({required String deviceId, required String accountId});
  Future<bool> validateDevice({required String deviceId, required String accountId});
  Future<void> deactivateDevice({required String deviceId, required String accountId});
}
