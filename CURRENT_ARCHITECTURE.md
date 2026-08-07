# Current Architecture Audit & Technical Debt Report
**Project:** Quincaillerie App (Tunisian Hardware Store Management System)  
**Date:** July 2026  
**Auditor:** Senior Flutter + Supabase Architect

---

## 1. Overview
The current `quincaillerie_app` codebase serves as an MVP/prototype for an offline-first stock scanner app. It uses **Flutter**, **Drift SQLite** for local storage, **Supabase** for cloud storage, **Provider** for state management, and **pdf/printing** packages for thermal receipt printing.

This report evaluates the current state of the codebase across 5 pillars: Strengths, Weaknesses, Technical Debt, Security Issues, and Scalability/Sync Issues.

---

## 2. Structural Analysis

### 2.1 Directory Structure (`lib/`)
```
lib/
├── data/
│   └── local/
│       ├── database.dart       # Drift table definitions & raw SQL queries
│       └── database.g.dart     # Generated code
├── features/
│   ├── add_product/
│   ├── cart/
│   ├── dashboard/
│   ├── inventory/
│   ├── qr_generator/
│   ├── sales/
│   └── scan/
├── services/
│   ├── pdf_receipt_service.dart
│   └── sync_service.dart
├── theme/
│   └── app_theme.dart
└── main.dart
```

### 2.2 Database Schema Overview
* **Local (Drift SQLite):** `Products`, `StockMovements`, `Sales`, `SaleItems`.
* **Remote (Supabase PostgreSQL):** `stores`, `products`, `stock_movements`, `sales`, `sale_items`.

---

## 3. Evaluation Findings

### 3.1 Strengths
1. **Offline-First Foundation:** SQLite (via Drift) allows local read and write operations without requiring active internet connectivity.
2. **Deterministic Schemas:** Primary keys are UUID strings generated client-side, avoiding ID collisions during offline row creation.
3. **Receipt Generation:** Thermal 80mm PDF ticket generation is already functional via `PdfReceiptService`.
4. **Clean UI Theme & Navigation:** Base UI styling with Material 3 and basic bottom navigation shell.

### 3.2 Weaknesses & Missing Features
1. **No Real Authentication:** The app relies on hardcoded string IDs (`storeId = 'demo-store'`, `userId = 'demo-user'`).
2. **Single-Tenant Hardcoding:** Multi-tenancy structures (`profiles`, `stores`, `store_members`) are absent from client state and database relations.
3. **Missing Core Quincaillerie Modules:**
   * No **Supplier** & **Purchase Order** management.
   * No **Customer** & **Debt/Ardoise** tracking.
   * No **Product Units & Conversions** (e.g. buying in cartons, selling in meters/pieces).
   * No **Product Variants** (e.g. cable thickness 1.5mm / 2.5mm / 4mm, length 10m / 50m).
   * No **Product Categories** model (currently just a plain string field).
4. **Monolithic Architecture:** Lack of Clean Architecture separation (Data / Domain / Presentation layers). Business logic is embedded in widgets and stateful views.
5. **No Multilingual / Arabic Support:** Hardcoded French strings in UI without `easy_localization` or i18n support.

### 3.3 Technical Debt
1. **Direct Quantity Mutation:** Stock quantity is updated via direct write to `Products.quantity` instead of relying on an event-driven stock calculation (`SUM(stock_movements)`).
2. **God Class Database File:** `database.dart` contains table definitions, database connection logic, and application queries in one file.
3. **Incomplete Cart Provider:** `CartProvider` does not support customer assignment, debt sales, or discounts.

### 3.4 Security Issues
1. **Insecure Supabase RLS:** `supabase_schema.sql` sets policies to `USING (true) WITH CHECK (true)`, meaning any connected client can read, update, or delete data belonging to any store.
2. **Missing Role-Based Access Control (RBAC):** No roles defined (`owner`, `manager`, `cashier`, `stock_manager`) to enforce permissions for sensitive operations like price edits or financial dashboards.

### 3.5 Scalability & Sync Engine Deficiencies
1. **Synchronization:** `SyncService` is the single push/pull implementation. It synchronizes one store at a time from the foreground and reconciles the local stock cache after each pull.
2. **No Conflict Resolution:** Last-write-wins without timestamp checking or vector clocks.
3. **No Sync Log / Failure Diagnostics:** Errors during sync are caught silently without persisting to a local `sync_logs` table for retry or debugging.
4. **No Device Tracking:** `device_id` is missing from `stock_movements` and sync operations.

---

## 4. Architectural Transformation Plan Summary
To transform `quincaillerie_app` into a production-ready multi-tenant SaaS OS for Tunisian quincailleries, the system will undergo refactoring across 6 major milestones:

1. **Authentication & Multi-Tenant RBAC:** Supabase Auth, `profiles`, `stores`, `store_members`, and strict Row Level Security policies.
2. **Domain-Driven Database & Event-Based Stock Engine:** Refactoring Drift and Supabase schemas for `stock_movements`, `product_units`, `product_variants`, `suppliers`, `purchases`, `customers`, and `customer_debts`. Stock balance = `SUM(movements)`.
3. **Reliable Offline Sync:** Evolve `SyncService` with a durable queue, delta pull/push, conflict handling, retry mechanisms, and `sync_logs`.
4. **Quincaillerie Core Modules:** Complete Product Catalog, Unit Conversions, Variant Matrix, Supplier Purchases, Customer Debt System, Upgraded POS Cart & PDF Invoices (A4 + Thermal 80mm).
5. **Analytics & Multilingual UI/UX:** Responsive Dashboard, Low Stock Alerts, Arabic/French/English localization (`easy_localization`), and clean hardware-store friendly layout.
6. **Code Quality, Testing & Production Docs:** Clean Architecture refactoring (`core/`, `features/`), Unit & Widget test coverage, and deployment guides.
