import '../../data/local/database.dart';
import 'permission.dart';
import 'role_permissions.dart';
import 'user_role.dart';

class UserSession {
  final String userId;
  final String userEmail;
  final String fullName;
  final String phone;
  final String? currentStoreId;
  final String? currentStoreName;
  final UserRole currentRole;
  final List<Store> stores;
  final Map<String, UserRole> storeRoles;

  const UserSession({
    required this.userId,
    required this.userEmail,
    required this.fullName,
    required this.phone,
    this.currentStoreId,
    this.currentStoreName,
    required this.currentRole,
    required this.stores,
    this.storeRoles = const {},
  });

  bool get hasActiveStore => currentStoreId != null && currentStoreId!.isNotEmpty;

  /// All permissions granted to the active store role.
  Set<Permission> get permissions => RolePermissions.forRole(currentRole);

  bool hasPermission(Permission permission) =>
      RolePermissions.has(currentRole, permission);

  bool get isOwner => currentRole.isOwner;
  bool get isManager => currentRole == UserRole.manager || isOwner;
  bool get canManageStock => hasPermission(Permission.inventoryUpdate);
  bool get canPerformSales => hasPermission(Permission.salesCreate);
  bool get canViewFinancials => hasPermission(Permission.reportsFinancial);

  UserRole roleForStore(String storeId) => storeRoles[storeId] ?? currentRole;

  UserSession copyWith({
    String? userId,
    String? userEmail,
    String? fullName,
    String? phone,
    String? currentStoreId,
    String? currentStoreName,
    UserRole? currentRole,
    List<Store>? stores,
    Map<String, UserRole>? storeRoles,
  }) {
    return UserSession(
      userId: userId ?? this.userId,
      userEmail: userEmail ?? this.userEmail,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      currentStoreId: currentStoreId ?? this.currentStoreId,
      currentStoreName: currentStoreName ?? this.currentStoreName,
      currentRole: currentRole ?? this.currentRole,
      stores: stores ?? this.stores,
      storeRoles: storeRoles ?? this.storeRoles,
    );
  }
}
