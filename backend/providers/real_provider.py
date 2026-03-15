from __future__ import annotations

import os

import httpx
from fastapi import HTTPException

from models import RecipeSearchRequest, RecipeSearchResponse, RecipeSearchResult
from search_provider import SearchProvider
from providers.jsonld_validator import JsonLdRecipeValidator


class RealSearchProvider(SearchProvider):
    def __init__(self) -> None:
        self.api_key = os.environ.get("SERPAPI_API_KEY", "").strip()
        if not self.api_key:
            raise RuntimeError(
                "SERPAPI_API_KEY is not set. "
                "Set it before starting the backend."
            )
        self.validator = JsonLdRecipeValidator()

    def search(self, request: RecipeSearchRequest) -> RecipeSearchResponse:
        results: list[RecipeSearchResult] = []
        seen_urls: set[str] = set()

        for domain in request.trustedSites:
            if len(results) >= request.topN:
                break

            domain_results = self._search_domain(
                dish_idea=request.dishIdea,
                domain=domain,
                wanted=request.topN - len(results),
            )

            for item in domain_results:
                if item.url in seen_urls:
                    continue
                seen_urls.add(item.url)
                results.append(item)
                if len(results) >= request.topN:
                    break

        return RecipeSearchResponse(results=results)

    def _search_domain(
        self,
        dish_idea: str,
        domain: str,
        wanted: int,
    ) -> list[RecipeSearchResult]:
        query = f"site:{domain} {dish_idea} rezept"

        try:
            with httpx.Client(timeout=10.0) as client:
                response = client.get(
                    "https://serpapi.com/search.json",
                    params={
                        "engine": "google",
                        "q": query,
                        "num": max(wanted * 3, 6),
                        "api_key": self.api_key,
                    },
                )
        except httpx.HTTPError as e:
            raise HTTPException(
                status_code=502,
                detail=f"Search backend request failed: {e}",
            )

        if response.status_code == 401:
            raise HTTPException(
                status_code=500,
                detail="SERPAPI_API_KEY is invalid or unauthorized.",
            )

        if response.status_code >= 400:
            raise HTTPException(
                status_code=502,
                detail=f"Search backend returned status {response.status_code}.",
            )

        payload = response.json()
        organic_results = payload.get("organic_results", [])
        out: list[RecipeSearchResult] = []

        for rank, item in enumerate(organic_results, start=1):
            link = str(item.get("link", "")).strip()
            title = str(item.get("title", "")).strip()
            snippet = str(item.get("snippet", "")).strip()

            if not link or not title:
                continue
            if not self._matches_domain(link, domain):
                continue
            if self._is_clearly_non_recipe(link):
                continue
            if not self.validator.has_recipe_jsonld(link):
                continue

            out.append(
                RecipeSearchResult(
                    title=title,
                    domain=domain,
                    url=link,
                    subtitle=snippet or f"Recipe on {domain}",
                    score=float(max(wanted - rank + 1, 1)),
                )
            )

            if len(out) >= wanted:
                break

        return out

    def _matches_domain(self, url: str, domain: str) -> bool:
        url_lower = url.lower()
        domain_lower = domain.lower()
        return (
            f"https://{domain_lower}/" in url_lower
            or f"http://{domain_lower}/" in url_lower
            or f"https://www.{domain_lower}/" in url_lower
            or f"http://www.{domain_lower}/" in url_lower
        )

    def _is_clearly_non_recipe(self, url: str) -> bool:
        lower = url.lower()
        bad_parts = [
            "/search",
            "/suche",
            "/tag/",
            "/tags/",
            "/category/",
            "/categories/",
            "/kategorie/",
            "/kategorien/",
            "/author/",
            "/page/",
        ]
        return any(part in lower for part in bad_parts)
