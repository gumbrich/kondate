from __future__ import annotations

from fastapi import FastAPI

from importer import BackendRecipeImporter
from models import (
    ImportRecipeRequest,
    ImportRecipeResponse,
    RecipeSearchRequest,
    RecipeSearchResponse,
)
from providers.real_provider import RealSearchProvider

app = FastAPI(title="Kondate Search API", version="0.4.0")

provider = RealSearchProvider()
importer = BackendRecipeImporter()


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/search", response_model=RecipeSearchResponse)
def search_recipes(request: RecipeSearchRequest) -> RecipeSearchResponse:
    return provider.search(request)


@app.post("/import", response_model=ImportRecipeResponse)
def import_recipe(request: ImportRecipeRequest) -> ImportRecipeResponse:
    return importer.import_recipe(request.url)
