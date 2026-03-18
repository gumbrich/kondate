from pydantic import BaseModel, Field
from typing import Any, Dict, List, Optional


# ----------------------------
# Recipe search
# ----------------------------

class SearchRequest(BaseModel):
    dishIdea: str
    trustedSites: List[str]
    topN: int = 3


class SearchResult(BaseModel):
    title: str
    url: str
    source: str
    subtitle: Optional[str] = None
    domain: Optional[str] = None
    score: Optional[float] = None


class RecipeSearchRequest(BaseModel):
    dishIdea: str = Field(min_length=1)
    trustedSites: List[str] = Field(default_factory=list)
    topN: int = Field(default=3, ge=1, le=20)


class RecipeSearchResult(BaseModel):
    title: str
    domain: str
    url: str
    subtitle: Optional[str] = None
    score: Optional[float] = None


class RecipeSearchResponse(BaseModel):
    results: List[RecipeSearchResult]


# ----------------------------
# Recipe import
# ----------------------------

class ImportRecipeRequest(BaseModel):
    url: str


class ImportRecipeResponse(BaseModel):
    id: str = ""
    title: str
    sourceUrl: str = ""
    ingredients: List[Dict[str, Any]] = Field(default_factory=list)
    ingredientLines: List[str] = Field(default_factory=list)
    servings: Optional[float] = None


# ----------------------------
# Household creation / join
# ----------------------------

class CreateHouseholdResponse(BaseModel):
    householdId: str
    joinCode: str


class JoinHouseholdRequest(BaseModel):
    joinCode: str


class JoinHouseholdResponse(BaseModel):
    householdId: str
    joinCode: str


# ----------------------------
# Household state
# ----------------------------

class HouseholdState(BaseModel):
    recipes: List[Dict[str, Any]] = Field(default_factory=list)
    mealPlan: Dict[str, Any] = Field(default_factory=dict)
    trustedSites: List[str] = Field(default_factory=list)
    topN: int = 3
    targetServings: int = 2
    shoppingState: Dict[str, Any] = Field(default_factory=dict)


class HouseholdStateResponse(BaseModel):
    householdId: str = ""
    updatedAt: str
    state: Dict[str, Any]


class HouseholdStatePayload(BaseModel):
    householdId: str = ""
    updatedAt: str
    state: HouseholdState


class SaveHouseholdRequest(BaseModel):
    state: Dict[str, Any]
    lastSeenUpdatedAt: Optional[str] = None


class UpdateHouseholdStateRequest(BaseModel):
    state: Dict[str, Any]
    lastSeenUpdatedAt: Optional[str] = None
