enum Feature { dashboard, pos, inventory, sales, customers, suppliers, purchases, reports, settings, exports }

class Entitlements {
  final Set<Feature> enabled;
  final bool canCreateCommercialOperations;
  final int maxDevices;
  final int maxStores;

  const Entitlements({
    required this.enabled,
    required this.canCreateCommercialOperations,
    required this.maxDevices,
    required this.maxStores,
  });

  bool canUse(Feature feature) => enabled.contains(feature);

  static const unrestricted = Entitlements(
    enabled: {Feature.dashboard, Feature.pos, Feature.inventory, Feature.sales, Feature.customers, Feature.suppliers, Feature.purchases, Feature.reports, Feature.settings, Feature.exports},
    canCreateCommercialOperations: true,
    maxDevices: 1,
    maxStores: 1,
  );

  static const restricted = Entitlements(
    enabled: Set<Feature>{Feature.dashboard, Feature.sales, Feature.reports, Feature.exports, Feature.settings},
    canCreateCommercialOperations: false,
    maxDevices: 0,
    maxStores: 0,
  );
}
