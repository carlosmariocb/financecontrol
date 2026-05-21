# Tests/AGENTS.md

Instructions for tests and quality checks.

Focus tests on domain correctness. This app can have simple UI, but the finance rules must be reliable.

## Test priorities

1. Money calculations
2. Transaction classification
3. Balance updates
4. Credit card rules
5. Cuotas/installments
6. Budget calculations
7. Safe-to-spend
8. Parser behavior
9. Reports derived from transactions
10. Export/backup integrity

## Required domain test cases

### Income

- Salary income increases Lulo balance.
- Income appears in income reports.
- Income can be assigned to a quincenal budget period.

### Expense

- Expense from Nequi decreases Nequi balance.
- Expense appears in spending reports.
- Expense counts against its budget group.

### Transfer

- Transfer from Lulo to Nequi decreases Lulo and increases Nequi.
- Transfer does not appear as spending.
- Transfer does not appear as income.
- Transfer does not affect 50/30/20 results.

### Cash withdrawal

- Moving money from Lulo to Cash is a transfer, not an expense.

### Credit card purchase

- Purchase with Nu increases Nu card balance.
- Purchase appears in spending on purchase date.
- Purchase counts against category budget.
- Purchase does not reduce bank account balance immediately.

### Credit card payment

- Payment from Lulo to RappiCard decreases Lulo balance.
- Payment decreases RappiCard balance.
- Payment does not appear as spending.
- Payment does not count against budget.

### Credit card fees and interest

- Interest charge counts as expense.
- Fee charge counts as expense.
- Both increase card/debt cost visibility.

### Cuotas

- Purchase of 320000 COP with 3 cuotas creates 3 installment obligations.
- Rounding is deterministic.
- Remaining installments decrease when paid or marked in statement flow.
- Original purchase is not duplicated as new spending every month.

### Savings goals

- Savings allocation increases goal progress.
- Savings allocation counts toward savings/debt/investing group.
- Savings allocation is not ordinary consumption spending.

### Debt payment

- Principal reduces debt balance.
- Interest or fee portion counts as expense.
- Payment reminder can be generated from due date.

### Quincenal budget

- Dates 1-15 belong to first quincena.
- Dates 16-last day belong to second quincena.
- Needs limit is 50 percent of budget income.
- Wants limit is 30 percent of budget income.
- Savings/debt/investing limit is 20 percent of budget income.
- Warnings trigger at 80 percent and 100 percent.

### Safe-to-spend

- Safe-to-spend subtracts upcoming bills.
- Safe-to-spend subtracts upcoming card payments.
- Safe-to-spend subtracts planned savings.
- Safe-to-spend is not equal to total balance when money is reserved.

## Parser tests

Test these inputs:

```text
Cafe 8 mil Nequi
Uber 22 mil cash
Mercado 320 mil Nu 3 cuotas
Compre ropa por 240 mil con RappiCard a 4 cuotas
Pago internet 120 mil desde Lulo
Transferi 500 mil de Lulo a Nequi
Pague la RappiCard con Lulo 450 mil
Me pagaron salario 3 millones en Lulo
Mande 300 mil al fondo de emergencia
```

Expected behavior:

- Amounts are parsed correctly.
- Known accounts are matched.
- Known cards are matched.
- Transfers are not expenses.
- Credit card payments are not expenses.
- Cuotas are recognized.
- Low-confidence outputs require confirmation.

## Report tests

Reports must be derived from transactions.

Test:

- Monthly income vs expenses
- Spending by category
- 50/30/20 group totals
- Month-over-month comparison
- Credit card debt over time
- Savings goal progress

## Export and backup tests

CSV export should include enough fields to reconstruct reports.

JSON backup should include:

- Accounts
- Credit cards
- Categories
- Transactions
- Installment plans
- Goals
- Debts
- Recurring bills
- Budget periods

Importing a backup should not change totals.

## Regression risks

Be especially careful with:

- Double-counting credit card payments
- Treating transfers as expenses
- Treating cash withdrawals as spending
- Losing COP integer precision
- Duplicating cuota spending across months
- Showing total balance as safe-to-spend
- Letting AI bypass validation
