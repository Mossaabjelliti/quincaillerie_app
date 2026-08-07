import 'package:flutter/foundation.dart';
import 'license_repository.dart';
import 'license_state.dart';

abstract class LicenseRemoteSource {
  Future<LicenseRecord?> refresh({required String accountId, required String deviceId});
}

class LicenseService extends ChangeNotifier {
  final LicenseRepository repository;
  LicenseState _state = LicenseState(mode: LicenseMode.unverified, license: null, evaluatedAt: DateTime.now());
  LicenseState get state => _state;

  LicenseService({required this.repository});

  Future<void> load() async {
    _state = _evaluate(await repository.readCached(), DateTime.now());
    notifyListeners();
  }

  Future<void> refresh(LicenseRemoteSource source, {required String accountId, required String deviceId}) async {
    final remote = await source.refresh(accountId: accountId, deviceId: deviceId);
    if (remote != null) await repository.saveCached(remote);
    _state = _evaluate(remote ?? await repository.readCached(), DateTime.now());
    notifyListeners();
  }

  LicenseState _evaluate(LicenseRecord? license, DateTime now) {
    if (license == null) return LicenseState(license: null, mode: LicenseMode.unverified, evaluatedAt: now);
    if (license.status == LicenseStatus.active && !now.isAfter(license.expiresAt)) return LicenseState(license: license, mode: LicenseMode.active, evaluatedAt: now);
    if (license.status != LicenseStatus.revoked && !now.isAfter(license.offlineUntil)) return LicenseState(license: license, mode: LicenseMode.offlineGrace, evaluatedAt: now);
    return LicenseState(license: license, mode: LicenseMode.restricted, evaluatedAt: now);
  }
}
