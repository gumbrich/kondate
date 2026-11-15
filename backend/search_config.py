"""Search configuration is resolved lazily; other routes need no search key."""
import os
from functools import lru_cache

from fastapi import HTTPException

from providers.mock_provider import MockSearchProvider
from providers.real_provider import RealSearchProvider
from recipe_search_graph import GraphRecipeSearchProvider


@lru_cache(maxsize=1)
def get_search_workflow() -> GraphRecipeSearchProvider:
    mode = os.environ.get("KONDATE_SEARCH_PROVIDER", "real").strip().lower()
    if mode == "mock":
        return GraphRecipeSearchProvider(MockSearchProvider())
    if mode != "real":
        raise HTTPException(503, "KONDATE_SEARCH_PROVIDER must be real or mock.")
    if not os.environ.get("SERPAPI_API_KEY", "").strip():
        raise HTTPException(503, "Search requires SERPAPI_API_KEY.")
    return GraphRecipeSearchProvider(RealSearchProvider())
