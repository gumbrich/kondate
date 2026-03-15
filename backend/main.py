from __future__ import annotations

from typing import List

from fastapi import FastAPI
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


app = FastAPI(title="Kondate Search API", version="0.1.0")


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/search", response_model=RecipeSearchResponse)
def search_recipes(request: RecipeSearchRequest) -> RecipeSearchResponse:
    dish = request.dishIdea.strip()
    if not dish:
        return RecipeSearchResponse(results=[])

    # Temporary direct-result backend.
    # Important: these are DIRECT recipe pages, not Google/DuckDuckGo search URLs.
    # This gives you end-to-end wiring now. Later we replace this function with
    # real server-side search and ranking.
    mock_catalog = _mock_direct_results_for(dish)

    filtered: list[RecipeSearchResult] = []
    trusted = {site.lower() for site in request.trustedSites}

    for item in mock_catalog:
        if item.domain.lower() in trusted:
            filtered.append(item)

    return RecipeSearchResponse(results=filtered[: request.topN])


def _mock_direct_results_for(dish_idea: str) -> list[RecipeSearchResult]:
    dish = dish_idea.lower()

    if "ramen" in dish:
        return [
            RecipeSearchResult(
                title="Shoyu Ramen",
                domain="chefkoch.de",
                url="https://www.chefkoch.de/rezepte/ramen-shoyu.html",
                subtitle="Direktes Rezept auf chefkoch.de",
                score=9.4,
            ),
            RecipeSearchResult(
                title="Schnelle Ramen-Bowl",
                domain="springlane.de",
                url="https://www.springlane.de/magazin/rezeptideen/schnelle-ramen-bowl/",
                subtitle="Direktes Rezept auf springlane.de",
                score=8.9,
            ),
            RecipeSearchResult(
                title="Vegane Ramen",
                domain="eatsmarter.de",
                url="https://eatsmarter.de/rezepte/vegane-ramen",
                subtitle="Direktes Rezept auf eatsmarter.de",
                score=8.5,
            ),
        ]

    if "lasagne" in dish:
        return [
            RecipeSearchResult(
                title="Klassische Lasagne",
                domain="chefkoch.de",
                url="https://www.chefkoch.de/rezepte/klassische-lasagne.html",
                subtitle="Direktes Rezept auf chefkoch.de",
                score=9.5,
            ),
            RecipeSearchResult(
                title="Lasagne al Forno",
                domain="eatsmarter.de",
                url="https://eatsmarter.de/rezepte/lasagne-al-forno",
                subtitle="Direktes Rezept auf eatsmarter.de",
                score=8.8,
            ),
            RecipeSearchResult(
                title="Gemüselasagne",
                domain="springlane.de",
                url="https://www.springlane.de/magazin/rezeptideen/gemueselasagne/",
                subtitle="Direktes Rezept auf springlane.de",
                score=8.4,
            ),
        ]

    if "curry" in dish:
        return [
            RecipeSearchResult(
                title="Hähnchen-Curry",
                domain="chefkoch.de",
                url="https://www.chefkoch.de/rezepte/haehnchen-curry.html",
                subtitle="Direktes Rezept auf chefkoch.de",
                score=9.2,
            ),
            RecipeSearchResult(
                title="Rotes Thai-Curry",
                domain="springlane.de",
                url="https://www.springlane.de/magazin/rezeptideen/rotes-thai-curry/",
                subtitle="Direktes Rezept auf springlane.de",
                score=8.7,
            ),
            RecipeSearchResult(
                title="Gemüse-Curry",
                domain="eatsmarter.de",
                url="https://eatsmarter.de/rezepte/gemuese-curry",
                subtitle="Direktes Rezept auf eatsmarter.de",
                score=8.3,
            ),
        ]

    # Generic fallback: still return direct-looking pages per trusted site.
    # Later, replace with real backend search.
    return [
        RecipeSearchResult(
            title=f"{dish_idea} Rezept",
            domain="chefkoch.de",
            url=f"https://www.chefkoch.de/rezepte/{_slug(dish_idea)}.html",
            subtitle="Direktes Rezept auf chefkoch.de",
            score=7.5,
        ),
        RecipeSearchResult(
            title=f"{dish_idea} Rezept",
            domain="eatsmarter.de",
            url=f"https://eatsmarter.de/rezepte/{_slug(dish_idea)}",
            subtitle="Direktes Rezept auf eatsmarter.de",
            score=7.2,
        ),
        RecipeSearchResult(
            title=f"{dish_idea} Rezept",
            domain="springlane.de",
            url=f"https://www.springlane.de/magazin/rezeptideen/{_slug(dish_idea)}/",
            subtitle="Direktes Rezept auf springlane.de",
            score=7.0,
        ),
    ]


def _slug(text: str) -> str:
    return (
        text.strip()
        .lower()
        .replace("ä", "ae")
        .replace("ö", "oe")
        .replace("ü", "ue")
        .replace("ß", "ss")
        .replace(" ", "-")
        .replace("/", "-")
    )
