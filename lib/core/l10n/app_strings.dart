/// Centralized application strings.
///
/// This file is the single source of truth for user-facing text. It provides
/// the foundation for future i18n (Arabic / French / English) without coupling
/// widgets to hardcoded strings.
///
/// To add a new locale in the future:
///   1. Create `AppStrings_ar` / `AppStrings_en` extending `AppStrings`
///   2. Switch on the app locale to pick the right implementation
library;

class AppStrings {
  // Auth
  static const appTitle = 'Quincaillerie Pro OS';
  static const signIn = 'Se Connecter';
  static const signUp = 'Créer ma Quincaillerie';
  static const createStore = 'Créer une nouvelle Quincaillerie';
  static const storeName = 'Nom de la Quincaillerie';
  static const storeNamePlaceholder = 'ex: Quincaillerie El Baraka';
  static const loginSubtitle = 'Système de gestion de stock offline-first';
  static const welcomeBack = 'Bienvenue,';

  // Navigation
  static const tabScanner = 'Scanner';
  static const tabInventory = 'Inventaire';
  static const tabSales = 'Ventes';
  static const tabDashboard = 'Tableau de bord';
  static const sync = 'Synchroniser';
  static const members = 'Membres';
  static const customers = 'Clients';
  static const suppliers = 'Fournisseurs';
  static const reports = 'Rapports';
  static const settings = 'Paramètres';

  // Scanner
  static const scanBarcode = 'Scanner de Code-barres';
  static const manualEntry = 'Saisie manuelle / Douchette Scanner';
  static const addToCart = 'Ajouter au panier (Vente)';
  static const stockIn = 'Entrée (achat)';
  static const stockOut = 'Sortie directe';
  static const unknownProduct = 'Produit inconnu. Demandez à un responsable de l’ajouter.';

  // Cart
  static const cartTitle = 'Panier & Caisse';
  static const cartEmpty = 'Votre panier est vide';
  static const checkouts = 'Panier en cours';
  static const cash = 'Espèces';
  static const check = 'Chèque';
  static const credit = 'Crédit / Ardoise';
  static const totalToPay = 'Total à payer';
  static const validateSale = 'Valider la vente';
  static const saleSaved = 'Vente enregistrée !';
  static const printReceipt = 'Imprimer le reçu (PDF)';
  static const newSale = 'Nouvelle vente';

  // Inventory
  static const inventoryTitle = 'Inventaire & Stock';
  static const searchProduct = 'Rechercher par nom ou code-barres';
  static const newProduct = 'Nouveau produit';
  static const lowStockOnly = 'Stock bas uniquement';
  static const lowStock = 'Stock bas';
  static const inStock = 'En stock';
  static const physicalCount = 'Comptage physique';

  // Dashboard
  static const dashboardTitle = 'Tableau de bord';
  static const monthlyActivity = 'Activité Mensuelle';
  static const monthlyRevenue = 'Chiffre d\'affaires du mois';
  static const estMargin = 'Marge estimée';
  static const purchases = 'Achats stock';
  static const offlineMode = 'Mode Hors-ligne';
  static const lowStockProducts = 'Produit(s) en stock bas';

  // Customers
  static const customerDebtTitle = 'Gestion des Clients & Ardoises';
  static const newCustomer = 'Nouveau Client';
  static const customerPayment = 'Règlement d\'Ardoise';
  static const totalDebt = 'Dette actuelle';

  // Suppliers
  static const suppliersTitle = 'Gestion des Fournisseurs';
  static const newSupplier = 'Nouveau Fournisseur';
  static const receiveGoods = 'Réception marchandise';

  // Members
  static const memberTitle = 'Gestion des Membres';
  static const addMember = 'Ajouter un Membre';
  static const newMember = 'Nouveau Membre';
  static const memberEmail = 'Email du membre *';
  static const role = 'Rôle';
  static const removeMember = 'Retirer le membre ?';

  // Sync
  static const syncLogs = 'Journaux de synchronisation';
  static const syncSuccess = 'Synchronisation réussie';
  static const syncFailed = 'Échec de la synchronisation';
  static const noConnection = 'Pas de connexion internet';
  static const syncInProgress = 'Synchronisation en cours...';

  // Common
  static const save = 'Enregistrer';
  static const cancel = 'Annuler';
  static const delete = 'Supprimer';
  static const validate = 'Valider';
  static const confirm = 'Confirmer';
  static const search = 'Rechercher';
  static const all = 'Tous';
  static const empty = 'Aucun élément';
  static const loading = 'Chargement...';
  static const logout = 'Déconnexion';
  static const warning = 'Attention';
  static const error = 'Erreur';
  static const success = 'Succès';
}