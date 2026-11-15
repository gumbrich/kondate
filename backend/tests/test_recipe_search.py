import os
import unittest
from concurrent.futures import ThreadPoolExecutor
from tempfile import TemporaryDirectory
from unittest.mock import patch

from fastapi import HTTPException
from fastapi.testclient import TestClient

from models import RecipeSearchRequest, RecipeSearchResponse, RecipeSearchResult
from providers.real_provider import RealSearchProvider
from recipe_search_graph import GraphRecipeSearchProvider
from search_provider import SearchProvider


def result(url, title="Recipe"):
    return RecipeSearchResult(title=title, url=url, domain="example.com")


class StubProvider(SearchProvider):
    def __init__(self, catalog=None):
        self.catalog = catalog or {}
        self.calls = []

    def search(self, request):
        self.calls.append(request)
        return RecipeSearchResponse(
            results=self.catalog.get(request.trustedSites[0], [])
        )


class RecipeSearchGraphTests(unittest.TestCase):
    def test_normalization_priority_deduplication_and_early_stop(self):
        first = result("https://a.example/1")
        second = result("https://b.example/2")
        provider = StubProvider({
            "a.example": [first, first],
            "b.example": [first, second, result("https://b.example/3")],
        })
        request = RecipeSearchRequest(
            dishIdea="  Ramen  ",
            trustedSites=[" A.EXAMPLE ", "", "a.example", "b.example", "c.example"],
            topN=2,
        )
        response = GraphRecipeSearchProvider(provider).search(request)
        self.assertEqual(response.results, [first, second])
        self.assertEqual([r.trustedSites for r in provider.calls],
                         [["a.example"], ["b.example"]])
        self.assertTrue(all(r.dishIdea == "Ramen" for r in provider.calls))
        self.assertEqual(request.dishIdea, "  Ramen  ")  # Input is not mutated.

    def test_empty_requests_skip_provider(self):
        for dish, sites in [(" ", ["a.example"]), ("Ramen", []), ("Ramen", [" "])]:
            with self.subTest(dish=dish, sites=sites):
                provider = StubProvider()
                response = GraphRecipeSearchProvider(provider).search(
                    RecipeSearchRequest(dishIdea=dish, trustedSites=sites)
                )
                self.assertEqual(response.results, [])
                self.assertEqual(provider.calls, [])

    def test_no_results_exhausts_sites_without_default_recursion_failure(self):
        provider = StubProvider()
        sites = [f"site{i}.example" for i in range(20)]
        response = GraphRecipeSearchProvider(provider).search(
            RecipeSearchRequest(dishIdea="Ramen", trustedSites=sites)
        )
        self.assertEqual(response.results, [])
        self.assertEqual(len(provider.calls), 20)

    def test_empty_site_falls_through_and_partial_results_are_returned(self):
        item = result("https://b.example/1")
        provider = StubProvider({"b.example": [item]})
        response = GraphRecipeSearchProvider(provider).search(RecipeSearchRequest(
            dishIdea="Ramen", trustedSites=["a.example", "b.example"], topN=3,
        ))
        self.assertEqual(response.results, [item])
        self.assertEqual(len(provider.calls), 2)

    def test_provider_errors_are_not_silently_replaced_with_mock_results(self):
        provider = StubProvider()
        with patch.object(provider, "search", side_effect=HTTPException(502, "Unavailable")):
            with self.assertRaises(HTTPException) as caught:
                GraphRecipeSearchProvider(provider).search(RecipeSearchRequest(
                    dishIdea="Ramen", trustedSites=["a.example"],
                ))
        self.assertEqual(caught.exception.status_code, 502)

    def test_reused_graph_has_no_state_leak_between_requests(self):
        provider = StubProvider({"a.example": [result("https://a.example/1")]})
        workflow = GraphRecipeSearchProvider(provider)
        with ThreadPoolExecutor(max_workers=4) as executor:
            responses = list(executor.map(workflow.search, [
                RecipeSearchRequest(dishIdea="Ramen", trustedSites=[site])
                for site in ["a.example", "b.example"] * 5
            ]))
        self.assertEqual([len(r.results) for r in responses], [1, 0] * 5)

    def test_real_provider_still_validates_recipe_jsonld(self):
        with patch.dict(os.environ, {"SERPAPI_API_KEY": "test-only"}):
            provider = RealSearchProvider()
        with patch("providers.real_provider.httpx.Client") as client:
            response = client.return_value.__enter__.return_value.get.return_value
            response.status_code = 200
            response.json.return_value = {"organic_results": [
                {"title": "Not a recipe", "link": "https://chefkoch.de/no-recipe"},
                {"title": "Ramen", "link": "https://chefkoch.de/ramen"},
            ]}
            with patch.object(provider.validator, "has_recipe_jsonld", side_effect=[False, True]):
                found = GraphRecipeSearchProvider(provider).search(RecipeSearchRequest(
                    dishIdea="Ramen", trustedSites=["chefkoch.de"], topN=1,
                ))
        self.assertEqual([r.title for r in found.results], ["Ramen"])


class ApiTests(unittest.TestCase):
    def setUp(self):
        # Keep household fixtures away from the checked-in household data.
        self.temp = TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        previous_cwd = os.getcwd()
        try:
            os.chdir(self.temp.name)
            import main
        finally:
            os.chdir(previous_cwd)
        from household_store import HouseholdStore
        from search_config import get_search_workflow
        self.main = main
        self.get_workflow = get_search_workflow
        self.get_workflow.cache_clear()
        self.addCleanup(self.get_workflow.cache_clear)
        env = patch.dict(os.environ, {
            "KONDATE_SEARCH_PROVIDER": "mock", "SERPAPI_API_KEY": "",
        })
        env.start()
        self.addCleanup(env.stop)
        store = patch.object(main, "households", HouseholdStore(f"{self.temp.name}/households.json"))
        store.start()
        self.addCleanup(store.stop)
        self.client = TestClient(main.app)
        self.addCleanup(self.client.close)

    def test_existing_search_contract(self):
        response = self.client.post("/search", json={
            "dishIdea": "Ramen", "trustedSites": ["chefkoch.de", "eatsmarter.de"], "topN": 2,
        })
        self.assertEqual(response.status_code, 200)
        self.assertEqual(set(response.json()), {"results"})
        items = response.json()["results"]
        self.assertEqual(len(items), 2)
        self.assertEqual(set(items[0]), {"title", "domain", "url", "subtitle", "score"})
        self.assertEqual(items[0]["domain"], "chefkoch.de")

    def test_request_validation_preserved(self):
        for payload in [{"dishIdea": ""}, {"dishIdea": "Ramen", "topN": 0},
                        {"dishIdea": "Ramen", "topN": 21}]:
            with self.subTest(payload=payload):
                self.assertEqual(self.client.post("/search", json=payload).status_code, 422)

    def test_missing_key_only_disables_search(self):
        os.environ.pop("KONDATE_SEARCH_PROVIDER")  # Real is the default.
        self.assertEqual(self.client.get("/health").json(), {"status": "ok"})
        response = self.client.post("/search", json={"dishIdea": "Ramen"})
        self.assertEqual(response.status_code, 503)
        self.assertIn("SERPAPI_API_KEY", response.json()["detail"])
        self.assertEqual(self.client.post("/households").status_code, 200)

    def test_unknown_provider_is_an_explicit_configuration_error(self):
        os.environ["KONDATE_SEARCH_PROVIDER"] = "typo"
        self.assertEqual(self.client.post("/search", json={"dishIdea": "Ramen"}).status_code, 503)

    def test_upstream_error_reaches_client(self):
        provider = StubProvider()
        workflow = GraphRecipeSearchProvider(provider)
        self.main.app.dependency_overrides[self.get_workflow] = lambda: workflow
        self.addCleanup(self.main.app.dependency_overrides.clear)
        with patch.object(provider, "search", side_effect=HTTPException(502, "Unavailable")):
            response = self.client.post("/search", json={
                "dishIdea": "Ramen", "trustedSites": ["a.example"],
            })
        self.assertEqual(response.status_code, 502)
        self.assertEqual(response.json(), {"detail": "Unavailable"})

    def test_import_still_returns_ingredients_and_servings_without_search_key(self):
        os.environ["KONDATE_SEARCH_PROVIDER"] = "real"
        html = '''<script type="application/ld+json">
            {"@type": "Recipe", "name": "Ramen", "recipeYield": "2 portions",
             "recipeIngredient": ["200 g noodles", "1 l stock"]}</script>'''
        with patch.object(self.main.importer, "_fetch_html", return_value=html):
            response = self.client.post("/import", json={"url": "https://example.com/ramen"})
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["ingredientLines"], ["200 g noodles", "1 l stock"])
        self.assertEqual(response.json()["servings"], 2.0)

    def test_household_round_trip_and_conflict(self):
        created = self.client.post("/households").json()
        joined = self.client.post("/households/join", json={"joinCode": created["joinCode"]})
        self.assertEqual(joined.json(), created)
        url = f'/households/{created["householdId"]}/state'
        initial = self.client.get(url).json()
        payload = {"state": initial["state"], "lastSeenUpdatedAt": initial["updatedAt"]}
        payload["state"]["topN"] = 2
        self.assertEqual(self.client.put(url, json=payload).status_code, 200)
        self.assertEqual(self.client.get(url).json()["state"]["topN"], 2)
        self.assertEqual(self.client.put(url, json=payload).status_code, 409)


if __name__ == "__main__":
    unittest.main()
