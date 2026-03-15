from __future__ import annotations

from models import RecipeSearchRequest, RecipeSearchResponse
from search_provider import SearchProvider


class RealSearchProvider(SearchProvider):
    def search(self, request: RecipeSearchRequest) -> RecipeSearchResponse:
        raise NotImplementedError(
            "RealSearchProvider is not implemented yet. "
            "Next step: connect a real search source that returns actual recipe URLs."
        )
