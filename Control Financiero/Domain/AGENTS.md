# App/Domain/AGENTS.md

Instructions for the domain and finance engine.

This is the most important part of the app. Financial correctness matters more than UI polish.

The domain layer must be deterministic, testable, and independent from SwiftUI, AI, cloud, and notifications.

## Core entities

Keep the model small.

### Account

Fields:

- id
- name
- type: bank, wallet, cash, pocket, foreign_wallet
- currency
- initialBalance
- currentBalance or derived balance
- includeInTotal

Default accounts:

- Lulo
- Lulo Pocket
- Nequi
- Global66
- Cash

### CreditCard

Fields:

- id
- name
- bank
- cutOffDay
- paymentDueDay
- limit optional
- currentBalance or derived balance

Default cards:

- Lulo
- Nu
- Davivienda
- RappiCard

### Transaction

Fields:

- id
- date
- type
- amount
- currency
- accountId optional
- toAccountId optional
- creditCardId optional
- categoryId optional
- subcategoryId optional
- merchant optional
- description optional
- paymentChannel optional
- installmentPlanId optional
- goalId optional
- debtId optional
- includeInBudget
- includeInReports
- source: manual, text, voice, ai, import
- createdAt
- updatedAt

### TransactionType

Required values:

- income
- expense
- transfer
- credit_card_purchase
- credit_card_payment
- savings_allocation
- debt_payment
- fee_or_interest

### Category

Fields:

- id
- name
- parentCategoryId optional
- budgetGroup: needs, wants, savings_debt, excluded

### BudgetPeriod

Fields:

- id
- startDate
- endDate
- incomePlanned
- needsLimit
- wantsLimit
- savingsDebtLimit
- rolloverAmount

### RecurringBill

Fields:

- id
- name
- amount
- currency
- dueDay
- accountId
- categoryId
- isActive
- reminderDaysBefore

### InstallmentPlan

Fields:

- id
- transactionId
- totalAmount
- numberOfInstallments
- remainingInstallments
- monthlyAmount
- cardId
- startDate

### Goal

Fields:

- id
- name
- targetAmount
- currentAmount or derived balance
- deadline optional
- linkedAccountId optional

### Debt

Fields:

- id
- name
- originalAmount
- currentBalance
- interestRate optional
- paymentAmount
- dueDay
- reminderDaysBefore

## Money rules

Use a Money type or equivalent value object.

Required behavior:

- Store amount as integer minor units.
- COP stores whole pesos.
- USD stores cents.
- Always store currency.
- Do not use floating point for money calculations.
- Rounding must be explicit.

COP formatting is a presentation concern, but the domain must not create decimal COP amounts.

## Balance rules

### Income

- Increases account balance.
- Counts as income in reports.
- Can count toward budget income.

### Expense

- Decreases account balance.
- Counts as spending.
- Counts against budget unless excluded.

### Transfer

- Decreases source account.
- Increases destination account.
- Does not count as income.
- Does not count as expense.
- Does not count against budget.

### Credit card purchase

- Increases credit card balance.
- Counts as spending on purchase date.
- Counts against budget category.
- Does not decrease bank account balance immediately.

### Credit card payment

- Decreases bank/account balance.
- Decreases credit card balance.
- Does not count as spending.
- Does not count against budget.

### Fee or interest

- Increases expense.
- Usually increases card or debt balance.
- Counts against the Debt category unless otherwise specified.

### Savings allocation

- Assigns money to a virtual goal.
- Counts toward savings/debt/investing group for 50/30/20.
- Should not be treated like ordinary consumption spending.
- May or may not move money between accounts, depending on user action.

### Debt payment

Split debt payment into:

- Principal: reduces debt, not an expense.
- Interest or fees: expense.

If the MVP does not yet support split payments, clearly mark debt payments and avoid double-counting them as ordinary spending.

## Quincenal budget rules

The user is paid quincenal.

Budget periods should support:

- 1st to 15th of month
- 16th to last day of month

Later, support custom payday-based periods.

50/30/20 calculation:

- Needs target = income * 0.50
- Wants target = income * 0.30
- Savings/debt/investing target = income * 0.20

Warnings:

- Warn when a group reaches 80 percent.
- Warn when a group reaches 100 percent.
- Do not block transactions.

Rollover:

- If implemented, unused budget can roll over.
- Rollover rules must be explicit and tested.

## Safe-to-spend rules

Safe-to-spend is not total balance.

Suggested calculation:

```text
safeToSpend =
  liquidAvailableMoney
  - upcomingFixedBills
  - upcomingCreditCardPayments
  - plannedSavings
  - plannedDebtPayments
  - reservedBudget
```

The calculation should be explainable. Provide a breakdown for UI use.

## Cuotas rules

When a card purchase has installments:

- Create one original purchase transaction.
- Store the installment plan.
- Calculate monthly installment amount deterministically.
- Track remaining installments.
- Show future obligations.

Rounding:

- If total does not divide evenly, distribute remainder predictably.
- Example: assign extra pesos to earliest installments.

Do not duplicate the original expense every month in spending reports unless the product intentionally changes the accounting view.

Default MVP approach:

- Spending is recognized on purchase date.
- Cash obligation is shown through future card payments.

## Card statement rules

A card needs:

- Cut-off day
- Payment due day

Use these to estimate:

- Purchases in current statement period
- Upcoming payment due date
- Expected payment amount

Keep first implementation simple and transparent. Do not attempt bank-grade statement reconciliation in MVP.

## Reports rules

Reports must be derived from transactions, not manually maintained totals.

Minimum derived outputs:

- Monthly income total
- Monthly expense total
- Net monthly result
- Spending by category
- Spending by budget group
- Credit card debt over time
- Savings progress

## Validation rules

Reject or request correction when:

- Amount is zero or negative where not allowed.
- Currency is missing.
- Expense has no source account unless it is a credit card purchase.
- Transfer source and destination are the same.
- Credit card payment has no source account or card.
- Installments are less than 2 for an installment plan.
- COP amount has decimals.

## Testing priority

Every rule above should be unit-testable without UI or persistence.
