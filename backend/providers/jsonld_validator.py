from __future__ import annotations

import json
from typing import Any

import httpx
from bs4 import BeautifulSoup


class JsonLdRecipeValidator:
    def __init__(self, timeout: float = 8.0) -> None:
        self.timeout = timeout

    def has_recipe_jsonld(self, url: str) -> bool:
        try:
            html = self._fetch_html(url)
        except Exception:
            return False

        return self._html_has_recipe_jsonld(html)

    def _fetch_html(self, url: str) -> str:
        headers = {
            "User-Agent": (
                "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
                "AppleWebKit/537.36 (KHTML, like Gecko) "
                "Chrome/122.0.0.0 Safari/537.36"
            )
        }

        with httpx.Client(timeout=self.timeout, follow_redirects=True, headers=headers) as client:
            response = client.get(url)
            response.raise_for_status()
            return response.text

    def _html_has_recipe_jsonld(self, html: str) -> bool:
        soup = BeautifulSoup(html, "html.parser")
        scripts = soup.find_all("script", attrs={"type": "application/ld+json"})

        for script in scripts:
            raw = script.string or script.get_text() or ""
            raw = raw.strip()
            if not raw:
                continue

            try:
                data = json.loads(raw)
            except Exception:
                continue

            if self._contains_recipe(data):
                return True

        return False

    def _contains_recipe(self, node: Any) -> bool:
        if node is None:
            return False

        if isinstance(node, dict):
            if self._is_recipe_type(node.get("@type")):
                return True

            if "@graph" in node and self._contains_recipe(node["@graph"]):
                return True

            for value in node.values():
                if self._contains_recipe(value):
                    return True

            return False

        if isinstance(node, list):
            return any(self._contains_recipe(item) for item in node)

        return False

    def _is_recipe_type(self, type_value: Any) -> bool:
        if type_value is None:
            return False

        if isinstance(type_value, str):
            return self._normalize_type(type_value) == "recipe"

        if isinstance(type_value, list):
            return any(
                isinstance(item, str) and self._normalize_type(item) == "recipe"
                for item in type_value
            )

        return False

    def _normalize_type(self, value: str) -> str:
        lowered = value.strip().lower()
        if lowered.endswith("/recipe") or lowered.endswith("#recipe"):
            return "recipe"
        return lowered
