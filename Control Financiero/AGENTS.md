# App/AGENTS.md

Instructions for SwiftUI app code.

This directory should contain the iPhone and Mac app implementation.

## UI architecture

Use a simple SwiftUI structure:

- App entry point
- MainTabView
- Home tab
- Add tab
- Budget tab
- Cards & Debts tab
- Reports tab
- Settings only if needed, not as a primary tab

Do not add more primary tabs in MVP.

## Main tabs

### Home

Show daily control information:

- Total balance
- Liquid balance
- Safe to spend
- Current quincena spending
- Remaining budget
- Credit card debt
- Upcoming bills
- Savings progress
- Recent transactions

### Add

This is the highest-priority screen.

Required input modes:

- Text entry
- Voice-to-text entry when available
- Quick buttons
- Manual form fallback

The Add flow should feel faster than opening a spreadsheet.

### Budget

Show:

- Current quincena period
- Needs, wants, and savings/debt progress
- Warnings when close to limits
- Monthly combined 50/30/20 result
- Rollover if implemented

### Cards & Debts

Show:

- Four credit cards
- Card balances
- Cut-off dates
- Due dates
- Upcoming payments
- Cuotas/installments
- Debts and reminders

### Reports

Show charts for:

- Monthly income vs expenses
- Net balance evolution
- Spending by category
- 50/30/20 monthly result
- Credit card debt over time
- Savings goal progress

## UI style rules

Keep screens calm and clear.

Prefer:

- Large key numbers
- Clear labels
- Few primary actions
- Simple cards or sections
- Inline warnings
- Empty states with examples

Avoid:

- Dense dashboards
- Deep menus
- Accounting terminology
- Too many charts on one screen
- Multi-step forms for common expenses

## Localization and copy

The app should support Colombian Spanish inputs and Colombian financial habits.

Initial UI copy can be English or Spanish, but keep strings centralized so localization is easy.

Use user-friendly language:

- Safe to spend
- Upcoming payments
- Cards
- Goals
- Bills
- Money in
- Money out

Avoid accounting language unless needed internally.

## Formatting

Use a shared formatter for money.

Requirements:

- COP displays like $120.000
- COP has no decimals
- USD may show cents
- Negative amounts should be visually clear

Do not hand-format money in individual views.

## Transaction confirmation

Parsed transactions must show a confirmation screen or inline editable draft before saving.

The user should be able to quickly edit:

- Amount
- Account or card
- Category
- Date
- Installments
- Whether it is a transfer, expense, income, or card payment

## Error handling

Use human messages.

Good:

```text
I could not identify the account. Choose one to continue.
```

Bad:

```text
ParserError.account.nil
```

## Accessibility

Support:

- Dynamic Type where practical
- VoiceOver labels for key amounts
- Sufficient touch targets
- Clear focus order in forms

## What not to implement here

Do not put business rules directly in SwiftUI views.

Views should call domain services/view models for:

- Balance calculations
- Safe-to-spend
- Budget progress
- Card obligations
- Installment schedules
- Report summaries
