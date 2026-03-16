from __future__ import annotations

from typing import Any, List

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


class CreateHouseholdResponse(BaseModel):
    householdId: str
    joinCode: str


class JoinHouseholdRequest(BaseModel):
    joinCode: str = Field(min_length=1)


class JoinHouseholdResponse(BaseModel):
    householdId: str
    joinCode: str


class HouseholdStateResponse(BaseModel):
    updatedAt: str
    state: dict[str, Any]


class UpdateHouseholdStateRequest(BaseModel):
    state: dict[str, Any]
    lastSeenUpdatedAt: str | None = None
