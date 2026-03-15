from __future__ import annotations

from typing import List

from pydantic import BaseModel, Field


class RecipeSearchRequest(BaseModel):
    dishIdea: str = Field(min_length=1)
    trustedSites: List[str] = Field(default_factory=list)
    topN: int = Field(default=3, ge=1, le=20)


class RecipeSearchResult(BaseModel):
    title: str
    domain: str
    url: str
    subtitle: str | None = None
    score: float | None = None


class RecipeSearchResponse(BaseModel):
    results: List[RecipeSearchResult]


class ImportRecipeRequest(BaseModel):
    url: str = Field(min_length=1)


class ImportRecipeResponse(BaseModel):
    title: str
    servings: float | None = None
    ingredientLines: List[str]
