"""Run from backend/: python example_search.py (no credentials or network)."""
from models import RecipeSearchRequest
from providers.mock_provider import MockSearchProvider
from recipe_search_graph import GraphRecipeSearchProvider


if __name__ == "__main__":
    workflow = GraphRecipeSearchProvider(MockSearchProvider())
    response = workflow.search(RecipeSearchRequest(
        dishIdea="Ramen",
        trustedSites=["chefkoch.de", "springlane.de", "eatsmarter.de"],
        topN=3,
    ))
    print(response.model_dump_json(indent=2))
