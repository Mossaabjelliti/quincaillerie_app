import 'entitlement.dart';

enum LicenseStatus { active, expired, revoked, unknown }
enum LicenseMode { active, offlineGrace, restricted, unverified }

class LicenseRecord {
  final String licenseId;
  final String accountId;
  final String plan;
  final LicenseStatus status;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final DateTime offlineUntil;
  final int maxDevices;
  final int maxStores;
  final Set<Feature> enabledFeatures;
  final String? signature;

  const LicenseRecord({required this.licenseId, required this.accountId, required this.plan, required this.status, required this.issuedAt, required this.expiresAt, required this.offlineUntil, required this.maxDevices, required this.maxStores, required this.enabledFeatures, this.signature});

  Map<String, dynamic> toJson() => {
        'licenseId': licenseId, 'accountId': accountId, 'plan': plan, 'status': status.name,
        'issuedAt': issuedAt.toIso8601String(), 'expiresAt': expiresAt.toIso8601String(),
        'offlineUntil': offlineUntil.toIso8601String(), 'maxDevices': maxDevices, 'maxStores': maxStores,
        'enabledFeatures': enabledFeatures.map((feature) => feature.name).toList(), 'signature': signature,
      };

  factory LicenseRecord.fromJson(Map<String, dynamic> json) => LicenseRecord(
        licenseId: json['licenseId'] as String, accountId: json['accountId'] as String,
        plan: json['plan'] as String, status: LicenseStatus.values.byName(json['status'] as String),
        issuedAt: DateTime.parse(json['issuedAt'] as String), expiresAt: DateTime.parse(json['expiresAt'] as String),
        offlineUntil: DateTime.parse(json['offlineUntil'] as String), maxDevices: json['maxDevices'] as int,
        maxStores: json['maxStores'] as int,
        enabledFeatures: (json['enabledFeatures'] as List).map((value) => Feature.values.byName(value as String)).toSet(),
        signature: json['signature'] as String?,
      );
}

class LicenseState {
  final LicenseRecord? license;
  final LicenseMode mode;
  final DateTime evaluatedAt;
  const LicenseState({required this.license, required this.mode, required this.evaluatedAt});

  Entitlements get entitlements => switch (mode) {
        LicenseMode.active || LicenseMode.offlineGrace => license == null
            ? Entitlements.unrestricted
            : Entitlements(enabled: license!.enabledFeatures, canCreateCommercialOperations: true, maxDevices: license!.maxDevices, maxStores: license!.maxStores),
        LicenseMode.restricted => Entitlements.restricted,
        LicenseMode.unverified => Entitlements.unrestricted,
      };

  bool get shouldShowRenewalWarning => mode == LicenseMode.offlineGrace;
}
