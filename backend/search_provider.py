from __future__ import annotations

from abc import ABC, abstractmethod

from models import RecipeSearchRequest, RecipeSearchResponse


class SearchProvider(ABC):
    @abstractmethod
    def search(self, request: RecipeSearchRequest) -> RecipeSearchResponse:
        raise NotImplementedError
