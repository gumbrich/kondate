"""Request-scoped recipe discovery; existing providers own search and validation."""
from __future__ import annotations

from typing import Literal, TypedDict

from langgraph.graph import END, START, StateGraph

from models import RecipeSearchRequest, RecipeSearchResponse, RecipeSearchResult
from search_provider import SearchProvider


class RecipeSearchState(TypedDict, total=False):
    request: RecipeSearchRequest
    sites: list[str]
    site_index: int
    candidates: list[RecipeSearchResult]
    results: list[RecipeSearchResult]
    response: RecipeSearchResponse


def build_recipe_search_graph(provider: SearchProvider):
    """Compile once; each invocation gets independent state (no checkpointer)."""
    def normalize_request(state: RecipeSearchState) -> dict:
        request = state["request"]
        sites = list(dict.fromkeys(
            site.strip().lower() for site in request.trustedSites if site.strip()
        ))
        return {
            "request": request.model_copy(update={
                "dishIdea": request.dishIdea.strip(), "trustedSites": sites,
            }),
            "sites": sites,
            "site_index": 0,
            "candidates": [],
            "results": [],
        }

    def route(state: RecipeSearchState) -> Literal["search_site", "finish"]:
        if (
            state["request"].dishIdea
            and state["site_index"] < len(state["sites"])
            and len(state["results"]) < state["request"].topN
        ):
            return "search_site"
        return "finish"

    def search_site(state: RecipeSearchState) -> dict:
        # Ask for topN so duplicates from earlier sites don't consume the quota.
        request = state["request"].model_copy(update={
            "trustedSites": [state["sites"][state["site_index"]]],
        })
        response = provider.search(request)
        return {"candidates": response.results}

    def collect_results(state: RecipeSearchState) -> dict:
        results = list(state["results"])
        seen = {result.url for result in results}
        for candidate in state["candidates"]:
            if candidate.url not in seen:
                seen.add(candidate.url)
                results.append(candidate)
            if len(results) >= state["request"].topN:
                break
        return {"results": results, "site_index": state["site_index"] + 1}

    def finish(state: RecipeSearchState) -> dict:
        return {"response": RecipeSearchResponse(results=state["results"])}

    builder = StateGraph(RecipeSearchState)
    builder.add_node("normalize_request", normalize_request)
    builder.add_node("search_site", search_site)
    builder.add_node("collect_results", collect_results)
    builder.add_node("finish", finish)
    builder.add_edge(START, "normalize_request")
    builder.add_conditional_edges("normalize_request", route)
    builder.add_edge("search_site", "collect_results")
    builder.add_conditional_edges("collect_results", route)
    builder.add_edge("finish", END)
    return builder.compile()


class GraphRecipeSearchProvider(SearchProvider):
    """Keep the existing provider contract at the API boundary."""

    def __init__(self, provider: SearchProvider) -> None:
        self.graph = build_recipe_search_graph(provider)

    def search(self, request: RecipeSearchRequest) -> RecipeSearchResponse:
        state = self.graph.invoke(
            {"request": request},
            # Two steps per site plus normalize/finish. Support > 12 sites too.
            config={"recursion_limit": 2 * len(request.trustedSites) + 5},
        )
        return state["response"]
