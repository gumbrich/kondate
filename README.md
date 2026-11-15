# Kondate

Kondate (献立) = meal plan.

Cross-platform Flutter app for:
- Weekly meal planning
- Recipe import
- Automatic shopping list generation

## Repo structure

- apps/mobile → Flutter app
- packages/core → domain models
- packages/recipe_parser → recipe extraction logic
- backend → FastAPI recipe search/import and household sync; LangGraph orchestrates recipe discovery

## Backend and LangGraph

See [backend setup and workflow documentation](backend/README.md) for installation,
an offline example, tests, real-search configuration, and connecting the Flutter app.
