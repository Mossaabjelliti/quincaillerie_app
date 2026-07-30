# Quincaillerie Pro OS 🛠️🇹🇳

**Système d'Exploitation Digital Offline-First pour Quincailleries Tunisiennes**

Transformez votre quincaillerie grâce à un système complet de gestion d'inventaire, de ventes POS, de fournisseurs, de clients et d'ardoises.

---

## 🌟 Fonctionnalités Clés

* 🔐 **Multi-Magasins & Rôle (RBAC):** Supabase Auth avec isolation complète des données par magasin (`store_id`) et rôles (propriétaire, gérant, caissier, gestionnaire de stock).
* ⚡ **Offline-First Intégral:** Base de données SQLite locale ultra-rapide (Drift). Tout fonctionne hors-ligne.
* 🔄 **Sync Engine Bidirectionnel:** Synchronisation automatique local <-> cloud (Supabase) avec queue de sync, retentative automatique et traçabilité par appareil (`device_id`).
* 📦 **Inventaire Event-Driven:** Calcul du stock en temps réel basé sur l'historique des mouvements (`SUM(PURCHASE/SALE/ADJUSTMENT/RETURN)`).
* 📏 **Gestion des Unités & Variantes:** Prise en charge des conversions (Carton = 50 pièces ou mètres) et des variantes (Câble 1.5mm / 2.5mm / 4mm).
* 🚛 **Fournisseurs & Commandes:** Gestion des fournisseurs, bons de commande et entrées en stock.
* 📓 **Carnet des Clients & Ardoises:** Suivi rigoureux des crédits clients, historique des achats et versements partiels.
* 🧾 **Facturation & Thermal Receipts:** Génération instantanée de tickets thermiques 80mm et de factures officielles A4 en PDF.
* 📊 **Tableau de Bord Analytics:** Statistiques en temps réel (chiffre d'affaires, marge nette, produits les plus vendus, alertes stock bas).

---

## 🚀 Prise en main rapide

```bash
# 1. Cloner le projet
git clone https://github.com/Mossaabjelliti/quincaillerie_app.git
cd quincaillerie_app

# 2. Installer les dépendances
flutter pub get

# 3. Exécuter le générateur Drift / BuildRunner
dart run build_runner build --delete-conflicting-outputs

# 4. Lancer l'application
flutter run
```

---

## 📚 Documentation Complète
* 🏛️ [ARCHITECTURE.md](file:///c:/Users/mossa/Downloads/quincaillerie_app/quincaillerie_app/ARCHITECTURE.md) - Clean Architecture & Sync Engine
* 🗄️ [DATABASE.md](file:///c:/Users/mossa/Downloads/quincaillerie_app/quincaillerie_app/DATABASE.md) - Schéma SQLite & PostgreSQL RLS
* 🚀 [DEPLOYMENT.md](file:///c:/Users/mossa/Downloads/quincaillerie_app/quincaillerie_app/DEPLOYMENT.md) - Guide de déploiement Supabase & APK
* 📖 [USER_GUIDE.md](file:///c:/Users/mossa/Downloads/quincaillerie_app/quincaillerie_app/USER_GUIDE.md) - Manuel d'utilisation pour quincailliers
