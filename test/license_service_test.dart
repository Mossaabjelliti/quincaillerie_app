import 'package:flutter_test/flutter_test.dart';
import 'package:quincaillerie_app/core/licensing/entitlement.dart';
import 'package:quincaillerie_app/core/licensing/license_repository.dart';
import 'package:quincaillerie_app/core/licensing/license_service.dart';
import 'package:quincaillerie_app/core/licensing/license_state.dart';
import 'package:quincaillerie_app/core/device_identity.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemoryRepository implements LicenseRepository {
  LicenseRecord? value;
  @override Future<void> clearCached() async => value = null;
  @override Future<LicenseRecord?> readCached() async => value;
  @override Future<void> saveCached(LicenseRecord license) async => value = license;
}

class _Remote implements LicenseRemoteSource {
  final LicenseRecord result;
  _Remote(this.result);
  @override Future<LicenseRecord?> refresh({required String accountId, required String deviceId}) async => result;
}

LicenseRecord _license({required DateTime expiresAt, required DateTime offlineUntil}) => LicenseRecord(
  licenseId: 'license-1', accountId: 'store-1', plan: 'pro', status: LicenseStatus.active,
  issuedAt: DateTime(2026), expiresAt: expiresAt, offlineUntil: offlineUntil,
  maxDevices: 2, maxStores: 1, enabledFeatures: {Feature.pos, Feature.inventory},
);

void main() {
  test('active license grants configured entitlements', () async {
    final service = LicenseService(repository: _MemoryRepository()..value = _license(expiresAt: DateTime.now().add(const Duration(days: 1)), offlineUntil: DateTime.now().add(const Duration(days: 2))));
    await service.load();
    expect(service.state.mode, LicenseMode.active);
    expect(service.state.entitlements.canUse(Feature.pos), isTrue);
  });

  test('expired license stays usable during offline grace', () async {
    final service = LicenseService(repository: _MemoryRepository()..value = _license(expiresAt: DateTime.now().subtract(const Duration(days: 1)), offlineUntil: DateTime.now().add(const Duration(days: 1))));
    await service.load();
    expect(service.state.mode, LicenseMode.offlineGrace);
    expect(service.state.entitlements.canCreateCommercialOperations, isTrue);
  });

  test('expired grace restricts new commercial operations', () async {
    final service = LicenseService(repository: _MemoryRepository()..value = _license(expiresAt: DateTime.now().subtract(const Duration(days: 2)), offlineUntil: DateTime.now().subtract(const Duration(days: 1))));
    await service.load();
    expect(service.state.mode, LicenseMode.restricted);
    expect(service.state.entitlements.canCreateCommercialOperations, isFalse);
    expect(service.state.entitlements.canUse(Feature.exports), isTrue);
  });

  test('device identity remains stable across reads', () async {
    SharedPreferences.setMockInitialValues({});
    final first = await DeviceIdentity.id;
    final second = await DeviceIdentity.id;
    expect(second, first);
  });

  test('online refresh replaces the cached license', () async {
    final repository = _MemoryRepository();
    final service = LicenseService(repository: repository);
    final fresh = _license(expiresAt: DateTime.now().add(const Duration(days: 30)), offlineUntil: DateTime.now().add(const Duration(days: 31)));
    await service.refresh(_Remote(fresh), accountId: 'store-1', deviceId: 'device-1');
    expect((await repository.readCached())?.licenseId, fresh.licenseId);
    expect(service.state.mode, LicenseMode.active);
  });
}
