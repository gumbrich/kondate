from __future__ import annotations

from fastapi import FastAPI, HTTPException

from household_store import HouseholdStore
from importer import BackendRecipeImporter
from models import (
    CreateHouseholdResponse,
    ImportRecipeRequest,
    ImportRecipeResponse,
    JoinHouseholdRequest,
    JoinHouseholdResponse,
    RecipeSearchRequest,
    RecipeSearchResponse,
    HouseholdStateResponse,
    UpdateHouseholdStateRequest,
)
from providers.real_provider import RealSearchProvider

app = FastAPI(title="Kondate Search API", version="0.5.0")

provider = RealSearchProvider()
importer = BackendRecipeImporter()
households = HouseholdStore()


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/search", response_model=RecipeSearchResponse)
def search_recipes(request: RecipeSearchRequest) -> RecipeSearchResponse:
    return provider.search(request)


@app.post("/import", response_model=ImportRecipeResponse)
def import_recipe(request: ImportRecipeRequest) -> ImportRecipeResponse:
    return importer.import_recipe(request.url)


@app.post("/households", response_model=CreateHouseholdResponse)
def create_household() -> CreateHouseholdResponse:
    result = households.create_household()
    return CreateHouseholdResponse(**result)


@app.post("/households/join", response_model=JoinHouseholdResponse)
def join_household(request: JoinHouseholdRequest) -> JoinHouseholdResponse:
    result = households.join_household(request.joinCode.strip().upper())
    if result is None:
      raise HTTPException(status_code=404, detail="Household code not found.")
    return JoinHouseholdResponse(**result)


@app.get("/households/{household_id}/state", response_model=HouseholdStateResponse)
def get_household_state(household_id: str) -> HouseholdStateResponse:
    state = households.get_state(household_id)
    if state is None:
        raise HTTPException(status_code=404, detail="Household not found.")
    return HouseholdStateResponse(state=state)


@app.put("/households/{household_id}/state")
def update_household_state(
    household_id: str,
    request: UpdateHouseholdStateRequest,
) -> dict[str, str]:
    ok = households.set_state(household_id, request.state)
    if not ok:
        raise HTTPException(status_code=404, detail="Household not found.")
    return {"status": "ok"}
