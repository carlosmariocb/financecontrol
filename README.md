# Finance Control (Control Financiero)

A local-first personal finance app for iPhone and Mac, designed around Colombian
banking realities: COP-first formatting, quincenal (biweekly) 50/30/20 budgeting,
credit-card *cuotas*, and four-card multi-bank tracking.

No backend. No cloud sync. No login. No bank integrations. Your data stays on
your device.

## Why this exists

Most finance apps assume a US-style monthly paycheck, decimal currencies, and a
single credit card. None of that matches how people in Colombia actually manage
money — you get paid on the 15th and the last day of the month, the peso has no
cents, and you juggle 3-4 cards with cuotas across them.

Control Financiero models those realities directly instead of forcing the user
to adapt to someone else's spreadsheet.

## Features

- **Five tabs**: Inicio (balances + recent activity), Agregar (transaction form),
  Presupuesto (50/30/20 + safe-to-spend), Tarjetas (card balances + next-payment
  cycle), Reportes (charts + upcoming payments).
- **Integer-precision money**. COP is stored as integer pesos, USD as integer
  cents. No floating-point rounding errors, ever.
- **Quincenal budget periods** (1–15, 16–end) with 50/30/20 group tracking and
  a deterministic safe-to-spend.
- **Credit-card cycle math**: cutoff and payment-due day per card, current-cycle
  spending, multi-cuota purchases automatically scheduled.
- **Local notifications** for upcoming bills, debt payments, and card statements.
- **Backup**: full JSON snapshot export + restore, CSV export of all transactions.
- **iPhone + Mac** from a single SwiftUI codebase.
- **Spanish (es-CO) first** via String Catalog, with English populated.

## Tech stack

- SwiftUI + SwiftData (iOS / macOS 26.5)
- Swift Charts
- UserNotifications
- Swift Testing (no XCTest), 80+ unit tests on the domain layer

## Architecture

The project follows a deliberately flat structure with a strict pure-Swift domain layer:

```
Control Financiero/
  Domain/
    Money/           Currency, Money, MoneyFormatter (deterministic, no locale variance)
    Enums/           AccountType, TransactionType, BudgetGroup, TransactionSource
    Models/          @Model classes: Account, CreditCard, TransactionCategory,
                     Transaction, InstallmentPlan, Goal, Debt, RecurringBill,
                     BudgetPeriod
    Services/        Pure functions for balances, budgets, card cycles, reports,
                     upcoming payments, CSV, backup, reminders
    Seed/            Colombian default accounts/cards/categories/goals
  UI/
    MainTabView.swift
    Tabs/            HomeView, AddTransactionView, BudgetView, CardsDebtsView,
                     ReportsView
    Forms/           Dual-mode (new + edit) views for every entity
    Settings/        Configuración hub: management screens, notifications, backup
  Resources/         Localizable.xcstrings (es-CO source, en target)
```

**Domain rules**:
- Domain layer imports only `Foundation` and `SwiftData` — never `SwiftUI`,
  never networking.
- Money is `Int64` minor units + `Currency` enum. Cross-currency arithmetic returns
  `Optional<Money>.none` (no implicit conversion).
- Account and card balances are **derived at query time** from transactions, never
  cached on the model.
- Service types are `nonisolated` so they can be called from any actor context.

## Building

Open `Control Financiero.xcodeproj` in Xcode 16+ on macOS 26.5+. Pick the
"Control Financiero" scheme.

- **iPhone**: any iOS 26.5 simulator (e.g. "iPhone 17 Pro").
- **Mac**: build for "My Mac".
- **Tests**: ⌘U runs the full Swift Testing suite. visionOS is left enabled by
  the template but not designed for explicitly.

CLI:

```sh
xcodebuild -scheme "Control Financiero" \
           -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

xcodebuild -scheme "Control Financiero" \
           -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
           test -only-testing:"Control FinancieroTests"
```

## Project status

| Milestone | Scope | State |
|---|---|---|
| M1 | Data models, Colombian seed, COP formatter, 5-tab shell | ✅ |
| M2 | Manual transaction entry, derived balances, transfer rules | ✅ |
| M3 | Credit-card purchases / payments, cuotas, card cycle | ✅ |
| M4 | Quincenal budget periods, 50/30/20, safe-to-spend | ✅ |
| M5 | Recurring bills, debts, reports, charts, CSV/JSON export, notifications | ✅ |
| M6 | Deterministic Spanish parser, optional local AI adapter | Planned |

## Privacy

- No analytics, no telemetry, no third-party SDKs.
- Notifications are local (`UNUserNotificationCenter`) — never sent over the network.
- Backups are written to user-chosen files via the system share sheet. Nothing
  is auto-uploaded.

## License

Not yet licensed. Treat as "all rights reserved" until a `LICENSE` file lands.
