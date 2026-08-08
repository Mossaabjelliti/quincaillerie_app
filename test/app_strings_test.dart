import 'package:flutter_test/flutter_test.dart';
import 'package:quincaillerie_app/core/l10n/app_strings.dart';

void main() {
  group('AppStrings i18n Foundation', () {
    test('core navigation strings are defined', () {
      expect(AppStrings.tabScanner, isNotEmpty);
      expect(AppStrings.tabInventory, isNotEmpty);
      expect(AppStrings.tabSales, isNotEmpty);
      expect(AppStrings.tabDashboard, isNotEmpty);
      expect(AppStrings.sync, isNotEmpty);
    });

    test('auth strings are defined', () {
      expect(AppStrings.signIn, isNotEmpty);
      expect(AppStrings.signUp, isNotEmpty);
      expect(AppStrings.appTitle, isNotEmpty);
      expect(AppStrings.loginSubtitle, isNotEmpty);
    });

    test('common action strings are defined', () {
      expect(AppStrings.save, equals('Enregistrer'));
      expect(AppStrings.cancel, equals('Annuler'));
      expect(AppStrings.delete, equals('Supprimer'));
      expect(AppStrings.search, isNotEmpty);
    });

    test('scanner strings are defined', () {
      expect(AppStrings.scanBarcode, isNotEmpty);
      expect(AppStrings.addToCart, isNotEmpty);
      expect(AppStrings.manualEntry, isNotEmpty);
    });

    test('sync status strings are unique and descriptive', () {
      expect(AppStrings.syncSuccess, isNot(equals(AppStrings.syncFailed)));
      expect(AppStrings.syncSuccess, contains('Synchronisation'));
      expect(AppStrings.noConnection, isNotEmpty);
      expect(AppStrings.syncInProgress, isNotEmpty);
    });

    test('all strings are non-empty', () {
      // Spot-check a representative set across all categories
      final strings = {
        AppStrings.appTitle,
        AppStrings.createStore,
        AppStrings.storeName,
        AppStrings.members,
        AppStrings.customers,
        AppStrings.suppliers,
        AppStrings.reports,
        AppStrings.settings,
        AppStrings.stockIn,
        AppStrings.stockOut,
        AppStrings.unknownProduct,
        AppStrings.cartTitle,
        AppStrings.cartEmpty,
        AppStrings.cash,
        AppStrings.check,
        AppStrings.credit,
        AppStrings.totalToPay,
        AppStrings.validateSale,
        AppStrings.saleSaved,
        AppStrings.printReceipt,
        AppStrings.newSale,
        AppStrings.inventoryTitle,
        AppStrings.searchProduct,
        AppStrings.newProduct,
        AppStrings.lowStockOnly,
        AppStrings.lowStock,
        AppStrings.inStock,
        AppStrings.physicalCount,
        AppStrings.dashboardTitle,
        AppStrings.monthlyActivity,
        AppStrings.monthlyRevenue,
        AppStrings.estMargin,
        AppStrings.purchases,
        AppStrings.offlineMode,
        AppStrings.lowStockProducts,
        AppStrings.customerDebtTitle,
        AppStrings.newCustomer,
        AppStrings.customerPayment,
        AppStrings.totalDebt,
        AppStrings.suppliersTitle,
        AppStrings.newSupplier,
        AppStrings.receiveGoods,
        AppStrings.memberTitle,
        AppStrings.addMember,
        AppStrings.newMember,
        AppStrings.memberEmail,
        AppStrings.role,
        AppStrings.removeMember,
        AppStrings.syncLogs,
        AppStrings.loading,
        AppStrings.logout,
        AppStrings.warning,
        AppStrings.error,
        AppStrings.success,
      };
      for (final s in strings) {
        expect(s, isNotEmpty, reason: 'String must not be empty');
      }
    });
  });
}