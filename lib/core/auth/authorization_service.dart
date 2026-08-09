import 'package:flutter/foundation.dart';
import 'auth_access.dart';
import 'auth_provider.dart';
import 'permission.dart';
import 'user_session.dart';

/// Centralized authorization API for permission checks.
///
/// Widgets and services should use [can] instead of scattering role comparisons
/// or reading [UserSession] permission getters directly.
class AuthorizationService extends ChangeNotifier {
  AuthorizationService({required AuthProvider authProvider})
      : _authProvider = authProvider,
        _sessionOverride = null {
    authProvider.addListener(_onAuthChanged);
  }

  /// Test-only constructor with a fixed session (no [AuthProvider] required).
  @visibleForTesting
  AuthorizationService.fromSession(UserSession? session)
      : _authProvider = null,
        _sessionOverride = session;

  final AuthProvider? _authProvider;
  final UserSession? _sessionOverride;

  UserSession? get _session =>
      _sessionOverride ?? _authProvider?.session;

  /// Active user session context; null when logged out.
  UserSession? get session => _session;

  void _onAuthChanged() => notifyListeners();

  /// Whether the current user has [permission].
  ///
  /// Returns false when unauthenticated or when the active store role does not
  /// grant the permission.
  bool can(Permission permission) =>
      AuthAccess.hasPermission(_session, permission);

  /// All permissions granted to the current user in the active store context.
  Set<Permission> get permissions => AuthAccess.permissions(_session);

  @override
  void dispose() {
    _authProvider?.removeListener(_onAuthChanged);
    super.dispose();
  }
}
