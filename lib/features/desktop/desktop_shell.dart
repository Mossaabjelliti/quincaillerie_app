import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/auth/authorization_service.dart';
import '../../core/licensing/license_service.dart';
import '../../core/licensing/license_state.dart';
import '../../core/navigation/app_navigation.dart';
import '../../services/sync_service.dart';

class DesktopShell extends StatefulWidget {
  final String storeId;
  final String userId;
  const DesktopShell({super.key, required this.storeId, required this.userId});
  @override State<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends State<DesktopShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final authz = context.watch<AuthorizationService>();
    final license = context.watch<LicenseService>().state;
    final destinations = AppNavigation.visibleDestinations(
      authz,
      platform: AppNavPlatform.desktop,
    ).where((destination) {
      final feature = destination.licenseFeature;
      return feature == null || license.entitlements.canUse(feature);
    }).toList(growable: false);
    final selectedIndex = AppNavigation.clampIndex(_index, destinations.length);
    final navContext = NavScreenContext(
      storeId: widget.storeId,
      userId: widget.userId,
      authz: authz,
    );
    final selected = destinations.isEmpty ? null : destinations[selectedIndex];
    final licenseBlocked = selected != null &&
        selected.licenseFeature != null &&
        !license.entitlements.canUse(selected.licenseFeature!);

    return Shortcuts(
      shortcuts: const {SingleActivator(LogicalKeyboardKey.escape): _DismissIntent()},
      child: Actions(
        actions: {_DismissIntent: CallbackAction<_DismissIntent>(onInvoke: (_) { Navigator.of(context).maybePop(); return null; })},
        child: Focus(
          autofocus: true,
          child: Scaffold(
            body: Row(children: [
              NavigationRail(
                selectedIndex: selectedIndex,
                extended: true,
                minExtendedWidth: 210,
                leading: Padding(padding: const EdgeInsets.all(16), child: Text('QUINCAILLERIE', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold))),
                destinations: [
                  for (final destination in destinations)
                    NavigationRailDestination(
                      icon: Icon(destination.icon),
                      label: Text(destination.label),
                    ),
                ],
                onDestinationSelected: (index) => setState(() => _index = index),
              ),
              const VerticalDivider(width: 1),
              Expanded(child: Column(children: [
                _DesktopTopBar(storeName: auth.session?.currentStoreName ?? 'Quincaillerie', storeId: widget.storeId, license: license),
                if (license.shouldShowRenewalWarning) const MaterialBanner(content: Text('Abonnement expiré : fonctionnement hors-ligne temporairement autorisé.'), actions: [SizedBox()]),
                Expanded(
                  child: destinations.isEmpty
                      ? const Center(child: Text('Aucune section accessible pour votre compte.'))
                      : licenseBlocked
                          ? const _RestrictedMode()
                          : AppNavigation.buildDestination(selected!, navContext),
                ),
              ])),
            ]),
          ),
        ),
      ),
    );
  }
}

class _DesktopTopBar extends StatelessWidget {
  final String storeName; final String storeId; final LicenseState license;
  const _DesktopTopBar({required this.storeName, required this.storeId, required this.license});
  @override Widget build(BuildContext context) => Material(
    child: SizedBox(height: 64, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: Row(children: [
      Text(storeName, style: Theme.of(context).textTheme.titleLarge), const Spacer(),
      Chip(avatar: Icon(license.mode.name == 'active' ? Icons.verified_outlined : Icons.offline_bolt_outlined, size: 16), label: Text(license.mode.name == 'active' ? 'Licence active' : 'Mode hors ligne')),
      const SizedBox(width: 12), Consumer<SyncService>(builder: (_, sync, __) => OutlinedButton.icon(onPressed: () async { await sync.syncNow(storeId: storeId); }, icon: const Icon(Icons.sync, size: 18), label: Text(switch (sync.status) { SyncStatus.syncing => 'Synchronisation…', SyncStatus.offline => 'Hors ligne', _ => 'Synchroniser' }))),
    ]))),
  );
}

class _RestrictedMode extends StatelessWidget { const _RestrictedMode(); @override Widget build(BuildContext context) => const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.lock_outline, size: 48), SizedBox(height: 12), Text('Mode restreint'), Text('Les données restent consultables. Renouvelez la licence pour créer de nouvelles opérations.')])); }
class _DismissIntent extends Intent { const _DismissIntent(); }
