# Continuity Brief

## Confirmed Stack

The app is a Flutter/Dart mobile app using Provider for state management, Drift with SQLite for the local offline database, and Supabase for auth plus remote Postgres sync. The current codebase also uses mobile_scanner for camera scanning, qr_flutter for QR generation, pdf and printing for receipt output, and connectivity_plus for connectivity checks. The live app path is wired through [lib/main.dart](lib/main.dart), with dependencies declared in [pubspec.yaml](pubspec.yaml).

One important nuance: there are two sync implementations in the repo. The app actually uses [lib/services/sync_service.dart](lib/services/sync_service.dart), which is manual push-only. [lib/core/sync/sync_manager.dart](lib/core/sync/sync_manager.dart) contains a broader push/pull design, but it is not wired into the running app.

## Feature Audit

| Fonctionnalité | Statut | Fichier(s) concerné(s) | Notes |
|---|---|---|---|
| App bootstrap, routing, bottom navigation | fait | [lib/main.dart](lib/main.dart), [lib/theme/app_theme.dart](lib/theme/app_theme.dart) | Initializes Supabase, registers providers, and exposes the main tab shell. |
| Authentification email/password + sélection de boutique | partiel | [lib/core/auth/auth_service.dart](lib/core/auth/auth_service.dart), [lib/core/auth/auth_provider.dart](lib/core/auth/auth_provider.dart), [lib/features/auth/login_screen.dart](lib/features/auth/login_screen.dart), [lib/features/auth/store_selection_screen.dart](lib/features/auth/store_selection_screen.dart) | Uses real Supabase Auth and store memberships now drive the active session role, but there is still no dedicated membership admin UI. |
| Ajout de produit | fait | [lib/features/add_product/add_product_screen.dart](lib/features/add_product/add_product_screen.dart) | Creates local products with barcode, category, unit, prices, stock, and low-stock threshold. Supports decimal quantities. |
| Scan caméra + saisie manuelle | fait | [lib/features/scan/scan_screen.dart](lib/features/scan/scan_screen.dart) | Scans a barcode, opens product creation for unknown items, or records stock movement / adds to cart for known items. |
| Panier multi-produits et vente | fait | [lib/features/cart/cart_provider.dart](lib/features/cart/cart_provider.dart), [lib/features/cart/cart_screen.dart](lib/features/cart/cart_screen.dart) | Supports multiple line items, quantity editing, checkout, stock decrement, and receipt printing. |
| Historique des ventes | fait | [lib/features/sales/sales_screen.dart](lib/features/sales/sales_screen.dart) | Read-only sales list with payment filter and PDF reprint. |
| Inventaire / catalogue | partiel | [lib/features/inventory/inventory_screen.dart](lib/features/inventory/inventory_screen.dart) | Lets users search, filter, edit, and delete products. This is inventory maintenance, not a physical count workflow. |
| Tableau de bord hors-ligne | fait | [lib/features/dashboard/dashboard_screen.dart](lib/features/dashboard/dashboard_screen.dart) | Computes monthly revenue, purchase estimates, and low-stock alerts from local SQLite only. |
| Génération QR | partiel | [lib/features/qr_generator/qr_generator_screen.dart](lib/features/qr_generator/qr_generator_screen.dart) | Generates a QR code on screen, but there is no dedicated print/export action for labels. |
| Fournisseurs | partiel | [lib/features/suppliers/supplier_management_screen.dart](lib/features/suppliers/supplier_management_screen.dart), [lib/data/local/database.dart](lib/data/local/database.dart) | Local supplier entry exists, but it is not wired into a full purchase order flow. |
| Clients et ardoise | partiel | [lib/features/customers/customer_debt_screen.dart](lib/features/customers/customer_debt_screen.dart), [lib/data/local/database.dart](lib/data/local/database.dart), [lib/features/cart/cart_screen.dart](lib/features/cart/cart_screen.dart) | The schema and a customer-debt screen exist, but checkout does not create debt records automatically. Credit is only a payment label right now. |
| Conversions d’unités et variantes | partiel | [lib/features/inventory/unit_variant_dialog.dart](lib/features/inventory/unit_variant_dialog.dart), [lib/data/local/database.dart](lib/data/local/database.dart) | The schema and dialog exist for unit conversions and variants, but they are not surfaced in the main app flow. |
| Synchronisation manuelle + quotidienne | fait | [lib/services/sync_service.dart](lib/services/sync_service.dart), [lib/services/sync_background.dart](lib/services/sync_background.dart), [lib/main.dart](lib/main.dart) | The live path now pushes and pulls across stores, logs failures to Drift, and the app registers a daily WorkManager task. |
| Synchronisation bidirectionnelle | fait | [lib/services/sync_service.dart](lib/services/sync_service.dart) | The live sync engine now performs push and pull, reconciles cached stock, and persists sync logs. |
| PDF ticket et facture | fait | [lib/services/pdf_receipt_service.dart](lib/services/pdf_receipt_service.dart) | Thermal receipt, A4 invoice, and printable QR label generation are implemented. |
| Modèle multi-utilisateur par boutique | partiel | [lib/data/local/database.dart](lib/data/local/database.dart), [lib/core/auth/auth_provider.dart](lib/core/auth/auth_provider.dart), [supabase_rls.sql](supabase_rls.sql), [lib/main.dart](lib/main.dart) | Roles now flow from store memberships into the active session and shell access, but there is still no membership management UI. |
| Backend schema and RLS | partiel | [supabase_schema.sql](supabase_schema.sql), [supabase_rls.sql](supabase_rls.sql) | The repo still contains both a secure RLS script and an older permissive schema script; only the secure path should be deployed. |
| Sync logs consultables | fait | [lib/features/sync/sync_logs_screen.dart](lib/features/sync/sync_logs_screen.dart), [lib/services/sync_service.dart](lib/services/sync_service.dart), [lib/main.dart](lib/main.dart) | Failure rows are persisted locally and exposed through a dedicated screen. |

## Non-Negotiable Constraints

| Contrainte | Statut | Evidence | Notes |
|---|---|---|---|
| Offline-first core | respectée pour les flux principaux | [lib/data/local/database.dart](lib/data/local/database.dart), [lib/features/scan/scan_screen.dart](lib/features/scan/scan_screen.dart), [lib/features/cart/cart_provider.dart](lib/features/cart/cart_provider.dart) | Reads and writes for stock, sales, and products happen locally first in Drift. Auth and sync still need Supabase when used. |
| Sync non temps réel | respectée | [lib/main.dart](lib/main.dart), [lib/services/sync_service.dart](lib/services/sync_service.dart), [lib/services/sync_background.dart](lib/services/sync_background.dart) | Sync remains non-realtime and now runs manually plus on a daily schedule. |
| Vente en vrac | respectée | [lib/data/local/database.dart](lib/data/local/database.dart), [lib/features/add_product/add_product_screen.dart](lib/features/add_product/add_product_screen.dart), [lib/features/cart/cart_screen.dart](lib/features/cart/cart_screen.dart) | Product units include piece, meter, kg, and liter, and the cart handles decimal quantities. |
| Pas de Stripe | respectée | [pubspec.yaml](pubspec.yaml) | No Stripe dependency or integration is present. I found no Stripe code in the repo. |

## Prochaine étape recommandée

Priorité unique: deploy only the secure Supabase RLS path and remove or quarantine the permissive schema script. This is the highest-risk gap because the repo currently contains both a safe policy set and an insecure one, and shipping the wrong SQL would expose cross-store data.