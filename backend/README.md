# Kondate backend

Python 3.10+ (CI uses 3.13). Run the commands below from `backend/`.

```sh
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt
python example_search.py
python -m unittest discover -s tests -v
```

The example and all tests run without credentials or external requests. Tests use
temporary household files and leave `households.json` alone.

## Run the API

Offline demo:

```sh
KONDATE_SEARCH_PROVIDER=mock python -m uvicorn main:app --reload --port 8000
```

Then, in another terminal:

```sh
curl http://127.0.0.1:8000/health
curl -X POST http://127.0.0.1:8000/search \
  -H 'Content-Type: application/json' \
  -d '{"dishIdea":"Ramen","trustedSites":["chefkoch.de","springlane.de","eatsmarter.de"],"topN":3}'
```

Mock search returns clearly labeled synthetic recipe links; these are for exercising
the suggestion flow and are not guaranteed to be importable. `/import` still fetches
real recipe URLs. There is no automatic fallback from real search to mock data.

For real search, copy `.env.example` to `.env`, fill in your SerpAPI key, then:

```sh
set -a
source .env
set +a
python -m uvicorn main:app --reload --port 8000
```

`.env` is ignored by Git and is not loaded automatically. Alternatively, set the
environment variables in your hosting service. `KONDATE_SEARCH_PROVIDER` defaults
to `real`; only `real` and `mock` are supported. Restart the server after changing
configuration. No model-provider key, LangSmith account, graph server, or new
database is required. LangGraph runs inside the existing FastAPI process.

Without `SERPAPI_API_KEY`, real `/search` returns HTTP 503; health, import, and
household routes can still run. Provider failures retain their existing HTTP error
responses. This fixes the previous startup failure when a search key was absent.
The existing household store remains `households.json` relative to the working
directory, so keep starting the server from `backend/`.

## Connect the Flutter app

From `apps/mobile/`, with the mock or real backend running:

```sh
flutter pub get
flutter run --dart-define=KONDATE_BACKEND_URL=http://127.0.0.1:8000
```

Use `http://10.0.2.2:8000` on the Android emulator. For a physical device, use your
computer's LAN address and start Uvicorn with `--host 0.0.0.0`; device network
policies must allow that development address. Omit the define to keep using the
existing `https://kondate-backend.onrender.com` deployment. A local code change
does not update that deployed service.

In Kondate, add a dish idea to a day in the weekly plan, configure trusted sites,
then choose **Rezepte vorschlagen**. The existing weekly suggestion service calls
`POST /search`, which now invokes the graph. Recipe selection, import, meal-plan
updates, shopping-list generation, household sync, and Coop flows retain their
existing interfaces.

## Why recipe discovery is the first graph

The Flutter client already owns the meal plan, ingredient aggregation, shopping
list, and Coop assistant. The Python backend owns external recipe search and
JSON-LD validation. Orchestrating that existing boundary makes LangGraph useful
immediately without duplicating the Dart domain logic or adding an LLM dependency.

`recipe_search_graph.py` defines a typed state and compiles this workflow:

```text
START -> normalize_request
           | blank idea / no sites ------------------------> finish -> END
           v
        search_site -> collect_results
           ^                 | enough results / sites exhausted -> finish
           +-----------------+ otherwise: next trusted site
```

- **State:** request, normalized sites, current site index, current candidates,
  accumulated results, and the final `RecipeSearchResponse`.
- **normalize_request:** trims the dish idea, lowercases/trims domains, removes
  blank/duplicate domains, and initializes fresh request state.
- **search_site:** calls the injected `SearchProvider` for one site. The real
  provider retains SerpAPI lookup and JSON-LD Recipe validation.
- **collect_results:** merges unique URLs in provider/site order and enforces
  `topN`. Each loop advances the site index; no retries or unbounded loops.
- **finish:** returns the same `{"results": [...]}` response used by Flutter.

The compiled graph is reused, but state is isolated per invocation. There is no
checkpointer or conversational memory. The recursion limit is sized to the number
of requested sites so valid long site lists do not hit LangGraph's default limit.
Search stops early once `topN` is satisfied. A site can be asked for up to `topN`
candidates even when fewer slots remain, so previously seen URLs do not consume
the remaining quota. Empty searches return an empty results list; errors propagate.

`search_config.py` selects the provider lazily and exposes the workflow through
FastAPI dependency injection. Tests can supply a provider without network access.
Future ranking or query-refinement steps can be added as nodes here. See the
[LangGraph Graph API documentation](https://docs.langchain.com/oss/python/langgraph/graph-api)
for the state, node, and conditional-edge APIs.

## Verification

The backend suite covers site ordering/normalization, URL deduplication, early
stopping, empty/partial results, long site lists, concurrent request isolation,
real-provider JSON-LD validation, upstream errors, configuration errors, the
existing HTTP response shape, recipe import, and household sync/conflicts.
GitHub Actions runs these tests and the offline example alongside the existing
Flutter checks.
