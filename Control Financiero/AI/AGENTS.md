# App/AI/AGENTS.md

Instructions for text, voice, and local AI features.

AI is an assistant for input and explanation. It is not the finance engine.

The app must remain useful without AI.

## AI goals

Use AI for:

- Parsing natural language transaction input
- Suggesting categories and subcategories
- Recognizing Colombian shorthand
- Explaining monthly changes
- Detecting unusual spending patterns
- Suggesting corrections based on history

Do not use AI for:

- Moving money
- Paying bills
- Connecting to banks in MVP
- Investment recommendations
- Tax calculations
- Final balance calculations
- Overriding deterministic finance rules
- Saving transactions without validation

## Parser pipeline

Use this order:

1. Normalize input text.
2. Try deterministic rule-based parsing.
3. If uncertain, call local AI parser adapter.
4. Validate parsed result with domain rules.
5. Show editable confirmation to user.
6. Save only after confirmation.

## Voice flow

For MVP, voice should be:

1. Speech-to-text using platform capability.
2. Text passed into the same parser pipeline.
3. User confirms transaction draft.

Do not build direct audio-to-transaction parsing in MVP.

## Supported input examples

The parser should eventually understand:

```text
Cafe 8 mil Nequi
Gasté 8 mil en cafe con Nequi
Uber 22 mil cash
Yango 25 mil Nequi
Mercado 320 mil Nu 3 cuotas
Compre ropa por 240 mil con RappiCard a 4 cuotas
Pago internet 120 mil desde Lulo
Transferi 500 mil de Lulo a Nequi
Saque 100 mil de Lulo para efectivo
Pague la RappiCard con Lulo 450 mil
Me pagaron salario 3 millones en Lulo
Mande 300 mil al fondo de emergencia
```

The parser should understand Colombian amount shorthand:

- 8 mil = 8000
- 120 mil = 120000
- 1 millon = 1000000
- 3 millones = 3000000

Avoid requiring accents for Spanish input.

## Transaction draft schema

AI and parser output should map to a draft similar to this:

```json
{
  "type": "expense",
  "amount": 8000,
  "currency": "COP",
  "date": "2026-05-20",
  "accountName": "Nequi",
  "toAccountName": null,
  "creditCardName": null,
  "categoryName": "Food",
  "subcategoryName": "Coffee",
  "merchant": "Cafe",
  "description": "Cafe 8 mil Nequi",
  "installments": null,
  "goalName": null,
  "debtName": null,
  "confidence": 0.94,
  "needsConfirmation": true
}
```

Rules:

- Output JSON only from the model adapter.
- Do not let the model directly create SwiftData records.
- Validate all fields against known accounts, cards, categories, goals, and debts.
- Unknown values should become suggestions requiring user confirmation.

## Confidence rules

Suggested thresholds:

- 0.90 or higher: show quick confirmation.
- 0.70 to 0.89: show editable confirmation with highlighted uncertain fields.
- Below 0.70: open manual form with suggestions filled in.

Never autosave an AI-created transaction in MVP.

## Deterministic parser first

Implement simple rules before calling AI.

The deterministic parser should handle:

- Amounts with mil/millon/millones
- Known account names
- Known card names
- Transfer patterns: de X a Y, from X to Y
- Credit card payment patterns: pague card with account
- Installment patterns: a N cuotas, N cuotas
- Common merchants: Cafe, Uber, Yango, Rappi
- Common categories and subcategories

## Local model adapter

Design an abstraction such as:

```text
TransactionDraftParser
  parse(input: String, context: ParserContext) -> TransactionDraft
```

Implementations can include:

- RuleBasedTransactionParser
- LocalModelTransactionParser
- MockTransactionParser for tests

The local model can be Gemma small model family or any local model selected later. Do not hard-code one provider into the domain.

## Privacy rules

- Do not send financial inputs to external APIs in MVP.
- Do not log raw transaction text in production logs.
- Do not include private financial data in crash reports.
- Keep AI context minimal.
- Prefer on-device or local Mac inference.

## Monthly explanation rules

AI can generate explanations from already computed summaries.

Good input to AI:

```json
{
  "month": "2026-05",
  "income": 5000000,
  "expenses": 3600000,
  "topIncreases": [
    { "category": "Restaurants", "delta": 280000 },
    { "category": "Transport", "delta": 120000 }
  ],
  "savingsRate": 0.16,
  "targetSavingsRate": 0.20
}
```

Do not pass full raw transaction history unless required.

AI explanations must be factual and based on computed data. Do not fabricate insights.
