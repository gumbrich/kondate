from __future__ import annotations

from fastapi import FastAPI

from models import RecipeSearchRequest, RecipeSearchResponse
from providers.mock_provider import MockSearchProvider
# from providers.real_provider import RealSearchProvider

app = FastAPI(title="Kondate Search API", version="0.2.0")

# Switch this later:
provider = MockSearchProvider()
# provider = RealSearchProvider()


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/search", response_model=RecipeSearchResponse)
def search_recipes(request: RecipeSearchRequest) -> RecipeSearchResponse:
    return provider.search(request)
