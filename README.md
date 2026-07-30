# Quincaillerie Stock App — Scaffold

## Ce qui est déjà construit
- **Schéma offline (Drift/SQLite)** — `lib/data/local/database.dart`. Produits, mouvements de stock, ventes. Chaque table a un flag `synced` — c'est toute la stratégie offline-first en une colonne.
- **Service de synchro** — `lib/services/sync_service.dart`. Pousse tout ce qui n'est pas encore synchronisé vers Supabase. Appelable manuellement (bouton) ou via une tâche planifiée quotidienne (à brancher avec `workmanager` en Phase 2).
- **Écran Scanner** — `lib/features/scan/scan_screen.dart`. Scan caméra → trouve le produit → dialogue Entrée/Sortie → écrit en local instantanément.
- **Tableau de bord** — `lib/features/dashboard/dashboard_screen.dart`. CA, achats, marge, stock bas — calculés 100% depuis la base locale, fonctionne sans internet.
- **Schéma Supabase** — `supabase_schema.sql`. À exécuter dans l'éditeur SQL de ton projet Supabase.

## Setup (à faire sur la machine de dev)
```bash
flutter create --project-name quincaillerie_app . --overwrite   # génère les fichiers de plateforme (android/, ios/) qu'on ne peut pas créer ici
flutter pub get
dart run build_runner build --delete-conflicting-outputs        # génère database.g.dart depuis database.dart
```
Puis dans `lib/main.dart`, remplace `YOUR_PROJECT` / `YOUR_ANON_KEY` par tes vraies valeurs Supabase.

## Ce qui manque encore (dans l'ordre)
1. **`add_product_screen.dart`** — créer un produit à la volée quand un code scanné est inconnu (référencé dans `scan_screen.dart` mais pas encore écrit).
2. **Auth réelle** — actuellement `storeId`/`userId` sont en dur dans `main.dart` pour débloquer les tests. Remplacer par Supabase Auth (email/téléphone + mot de passe) avant tout test terrain.
3. **Génération de code-barres/QR à imprimer** — pour les produits qui n'ont pas de code d'origine (vis, boulons en vrac). `qr_flutter` est déjà dans les dépendances.
4. **Écran de vente multi-produits** — actuellement chaque scan traite un produit à la fois. Pour un vrai ticket de caisse avec plusieurs articles, il faut un écran panier avant validation.
5. **RLS Supabase** — les tables sont activées mais sans policies. Sans ça, personne ne peut lire/écrire une fois RLS activé — il faut écrire les policies (`store_id = auth.uid()'s store` etc.) avant la sync.
6. **Sync automatique quotidienne** — le bouton manuel marche, mais la tâche planifiée en arrière-plan (`workmanager` sur Android) reste à implémenter pour Phase 2.

## Pourquoi ces choix
- **Provider plutôt que Riverpod/Bloc** : moins de boilerplate, plus simple à onboarder pour une équipe mixte.
- **Drift plutôt que sqflite brut** : typage fort, migrations gérées, requêtes réactives (`watch()`) sans SQL écrit à la main.
- **Un seul flag `synced` par ligne** plutôt qu'une queue séparée : plus simple à raisonner et suffisant tant qu'un seul appareil actif par boutique (le cas pour 95% des quincailleries au démarrage).
