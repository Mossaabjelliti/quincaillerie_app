import '../../data/local/database.dart';

class UserSession {
  final String userId;
  final String userEmail;
  final String fullName;
  final String phone;
  final String? currentStoreId;
  final String? currentStoreName;
  final String currentRole; // 'owner' | 'manager' | 'cashier' | 'stock_manager'
  final List<Store> stores;
  final Map<String, String> storeRoles;

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

  bool get isOwner => currentRole == 'owner';
  bool get isManager => currentRole == 'manager' || isOwner;
  bool get canManageStock => currentRole == 'stock_manager' || isManager;
  bool get canPerformSales => true; // All roles can process sales
  bool get canViewFinancials => isOwner || isManager;

  String roleForStore(String storeId) => storeRoles[storeId] ?? currentRole;

  UserSession copyWith({
    String? userId,
    String? userEmail,
    String? fullName,
    String? phone,
    String? currentStoreId,
    String? currentStoreName,
    String? currentRole,
    List<Store>? stores,
    Map<String, String>? storeRoles,
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
