import 'permission.dart';
import 'user_role.dart';
import 'user_session.dart';

/// Safe resolution of auth session → role → permissions.
///
/// Used by [AuthProvider] so unauthenticated or invalid contexts never grant
/// permissions implicitly.
class AuthAccess {
  AuthAccess._();

  /// Active signed-in user, or null when logged out.
  static UserSession? currentUser(UserSession? session) => session;

  /// Role for the active store, or null when logged out.
  static UserRole? currentRole(UserSession? session) => session?.currentRole;

  /// Permissions for the active store role; empty when logged out.
  static Set<Permission> permissions(UserSession? session) =>
      session?.permissions ?? const {};

  /// Whether [session] grants [permission]; false when logged out.
  static bool hasPermission(UserSession? session, Permission permission) =>
      session?.hasPermission(permission) ?? false;
}
