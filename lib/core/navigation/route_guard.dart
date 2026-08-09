import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth/authorization_service.dart';
import '../auth/permission.dart';

/// Maps routes and navigation destinations to required permissions.
class RouteProtection {
  RouteProtection._();

  static Permission permissionForDestination(String destinationId, Permission navPermission) =>
      switch (destinationId) {
        'employees' => Permission.employeesManage,
        _ => navPermission,
      };

  static Permission? permissionForRoute(String routeName) => switch (routeName) {
        '/sync-logs' => Permission.activityView,
        '/add-product' => Permission.inventoryCreate,
        '/cart' => Permission.salesCreate,
        '/customers' => Permission.customersView,
        '/suppliers' => Permission.suppliersView,
        _ => null,
      };

  static String? titleForRoute(String routeName) => switch (routeName) {
        '/sync-logs' => 'Journaux de synchronisation',
        '/add-product' => 'Ajouter un produit',
        '/cart' => 'Panier',
        '/customers' => 'Clients',
        '/suppliers' => 'Fournisseurs',
        _ => null,
      };
}

/// Blocks direct access to restricted screens when authorization fails.
class RouteGuard {
  RouteGuard._();

  static Widget guardScreen({
    required AuthorizationService authz,
    required Permission permission,
    required Widget child,
    String? title,
  }) {
    if (authz.can(permission)) return child;
    return AccessDeniedScreen(title: title);
  }

  static Widget guardedRoute(
    BuildContext context, {
    required String routeName,
    required Widget child,
  }) {
    final permission = RouteProtection.permissionForRoute(routeName);
    if (permission == null) return child;

    final authz = context.watch<AuthorizationService>();
    return guardScreen(
      authz: authz,
      permission: permission,
      title: RouteProtection.titleForRoute(routeName),
      child: child,
    );
  }
}

class AccessDeniedScreen extends StatelessWidget {
  final String? title;

  const AccessDeniedScreen({super.key, this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: title == null ? null : AppBar(title: Text(title!)),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Accès restreint: vous n\'avez pas la permission d\'accéder à cette section.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
