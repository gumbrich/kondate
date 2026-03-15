from __future__ import annotations

from models import RecipeSearchRequest, RecipeSearchResponse, RecipeSearchResult
from search_provider import SearchProvider


class MockSearchProvider(SearchProvider):
    def search(self, request: RecipeSearchRequest) -> RecipeSearchResponse:
        dish = request.dishIdea.strip()
        if not dish:
            return RecipeSearchResponse(results=[])

        mock_catalog = _mock_direct_results_for(dish)

        trusted = {site.lower() for site in request.trustedSites}
        filtered: list[RecipeSearchResult] = []

        for item in mock_catalog:
            if item.domain.lower() in trusted:
                filtered.append(item)

        return RecipeSearchResponse(results=filtered[: request.topN])


def _mock_direct_results_for(dish_idea: str) -> list[RecipeSearchResult]:
    dish = dish_idea.lower()

    if "ramen" in dish:
        return [
            RecipeSearchResult(
                title="MOCK: Shoyu Ramen",
                domain="chefkoch.de",
                url="https://www.chefkoch.de/rezepte/ramen-shoyu.html",
                subtitle="Mock direct result on chefkoch.de",
                score=9.4,
            ),
            RecipeSearchResult(
                title="MOCK: Schnelle Ramen-Bowl",
                domain="springlane.de",
                url="https://www.springlane.de/magazin/rezeptideen/schnelle-ramen-bowl/",
                subtitle="Mock direct result on springlane.de",
                score=8.9,
            ),
            RecipeSearchResult(
                title="MOCK: Vegane Ramen",
                domain="eatsmarter.de",
                url="https://eatsmarter.de/rezepte/vegane-ramen",
                subtitle="Mock direct result on eatsmarter.de",
                score=8.5,
            ),
        ]

    if "lasagne" in dish:
        return [
            RecipeSearchResult(
                title="MOCK: Klassische Lasagne",
                domain="chefkoch.de",
                url="https://www.chefkoch.de/rezepte/klassische-lasagne.html",
                subtitle="Mock direct result on chefkoch.de",
                score=9.5,
            ),
            RecipeSearchResult(
                title="MOCK: Lasagne al Forno",
                domain="eatsmarter.de",
                url="https://eatsmarter.de/rezepte/lasagne-al-forno",
                subtitle="Mock direct result on eatsmarter.de",
                score=8.8,
            ),
            RecipeSearchResult(
                title="MOCK: Gemüselasagne",
                domain="springlane.de",
                url="https://www.springlane.de/magazin/rezeptideen/gemueselasagne/",
                subtitle="Mock direct result on springlane.de",
                score=8.4,
            ),
        ]

    if "curry" in dish:
        return [
            RecipeSearchResult(
                title="MOCK: Hähnchen-Curry",
                domain="chefkoch.de",
                url="https://www.chefkoch.de/rezepte/haehnchen-curry.html",
                subtitle="Mock direct result on chefkoch.de",
                score=9.2,
            ),
            RecipeSearchResult(
                title="MOCK: Rotes Thai-Curry",
                domain="springlane.de",
                url="https://www.springlane.de/magazin/rezeptideen/rotes-thai-curry/",
                subtitle="Mock direct result on springlane.de",
                score=8.7,
            ),
            RecipeSearchResult(
                title="MOCK: Gemüse-Curry",
                domain="eatsmarter.de",
                url="https://eatsmarter.de/rezepte/gemuese-curry",
                subtitle="Mock direct result on eatsmarter.de",
                score=8.3,
            ),
        ]

    return [
        RecipeSearchResult(
            title=f"MOCK: {dish_idea} Rezept",
            domain="chefkoch.de",
            url=f"https://www.chefkoch.de/rezepte/{_slug(dish_idea)}.html",
            subtitle="Mock direct result on chefkoch.de",
            score=7.5,
        ),
        RecipeSearchResult(
            title=f"MOCK: {dish_idea} Rezept",
            domain="eatsmarter.de",
            url=f"https://eatsmarter.de/rezepte/{_slug(dish_idea)}",
            subtitle="Mock direct result on eatsmarter.de",
            score=7.2,
        ),
        RecipeSearchResult(
            title=f"MOCK: {dish_idea} Rezept",
            domain="springlane.de",
            url=f"https://www.springlane.de/magazin/rezeptideen/{_slug(dish_idea)}/",
            subtitle="Mock direct result on springlane.de",
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
