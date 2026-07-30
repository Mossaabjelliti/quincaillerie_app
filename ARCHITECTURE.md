# Architecture Guide - Quincaillerie Pro OS

## 1. Clean Architecture Layers

```
lib/
├── core/
│   ├── auth/           # AuthService, AuthProvider, UserSession
│   ├── inventory/      # StockEngine (Event sourcing SUM logic)
│   ├── sync/           # SyncManager (Bidirectional Push/Pull, Queue)
│   ├── theme/          # AppTheme, visual design tokens
│   └── utils/          # Currency formatters, date utilities
├── data/
│   └── local/          # Drift SQLite database & table definitions
├── features/
│   ├── add_product/    # Product creation & barcode scanner
│   ├── auth/           # LoginScreen, StoreSelectionScreen
│   ├── cart/           # POS CartProvider & checkout
│   ├── customers/      # CustomerDebtScreen & Ardoise payments
│   ├── dashboard/      # Analytics & financial metrics
│   ├── inventory/      # Product list & UnitVariantDialog
│   ├── qr_generator/   # Barcode/QR printer
│   ├── sales/          # Sales history & thermal/A4 printing
│   ├── scan/           # Quick scanner mode
│   └── suppliers/      # SupplierManagementScreen
└── main.dart
```

---

## 2. Event-Sourced Inventory Engine
Rather than mutating `Products.quantity` directly, every stock adjustment generates a record in `StockMovements`.

$$\text{Current Stock} = \sum (\text{PURCHASE} + \text{RETURN} + \text{stockIn}) - \sum (\text{SALE} + \text{stockOut}) + \sum (\text{ADJUSTMENT})$$

**Benefits:**
* Zero sync conflicts when multiple devices operate offline.
* Full audit trail for every single hardware piece.

---

## 3. Bidirectional Sync Strategy

```
Local SQLite (Drift) <---> Sync Queue <---> Supabase PostgreSQL
```

1. **Write Local First:** All operations write to SQLite instantly with `synced = false`.
2. **Push Queue:** `SyncManager` queries unsynced rows and upserts to Supabase with device identification (`device_id`).
3. **Pull Delta:** Fetches remote changes per `store_id` and updates local Drift SQLite database.
4. **Failure Recovery:** Errors are logged to local `SyncLogs` table with automatic retries on next connection state change.
