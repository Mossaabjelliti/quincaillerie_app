/// Centralized user role definitions for Stocki.
///
/// Primary roles: [owner], [employee].
/// Legacy granular roles ([manager], [cashier], [stockManager]) are preserved
/// for backward compatibility with existing store memberships.
/// [accountant] is reserved for future use.
enum UserRole {
  owner,
  employee,
  manager,
  cashier,
  stockManager,
  accountant;

  /// Default role when no role is specified (e.g. new invited members).
  static const UserRole defaultRole = UserRole.employee;

  /// Primary Stocki roles.
  static const List<UserRole> primaryRoles = [owner, employee];

  /// Roles assignable in store member management (legacy set preserved).
  static const List<UserRole> storeAssignableRoles = [
    owner,
    manager,
    cashier,
    stockManager,
  ];

  /// Wire/storage representation used by Drift and Supabase.
  String get wireValue => switch (this) {
        UserRole.owner => 'owner',
        UserRole.employee => 'employee',
        UserRole.manager => 'manager',
        UserRole.cashier => 'cashier',
        UserRole.stockManager => 'stock_manager',
        UserRole.accountant => 'accountant',
      };

  /// Parses a wire value from local DB or Supabase into a [UserRole].
  static UserRole fromWire(String? value) => switch (value) {
        'owner' => UserRole.owner,
        'employee' => UserRole.employee,
        'manager' => UserRole.manager,
        'cashier' => UserRole.cashier,
        'stock_manager' => UserRole.stockManager,
        'accountant' => UserRole.accountant,
        _ => defaultRole,
      };

  /// French display label for UI.
  String get displayLabel => switch (this) {
        UserRole.owner => 'Propriétaire',
        UserRole.employee => 'Employé',
        UserRole.manager => 'Gérant',
        UserRole.cashier => 'Caissier',
        UserRole.stockManager => 'Gestionnaire de stock',
        UserRole.accountant => 'Comptable',
      };

  bool get isOwner => this == UserRole.owner;
  bool get isEmployeeRole => this == UserRole.employee;
}
