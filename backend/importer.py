from __future__ import annotations

import json
import re
from typing import Any

import httpx
from fastapi import HTTPException

from models import ImportRecipeResponse


class BackendRecipeImporter:
    def __init__(self, timeout: float = 12.0) -> None:
        self.timeout = timeout

    def import_recipe(self, url: str) -> ImportRecipeResponse:
        html = self._fetch_html(url)
        recipe_obj = self._extract_recipe_jsonld(html)

        title = self._read_title(recipe_obj)
        if not title:
            raise HTTPException(status_code=422, detail="Recipe name missing.")

        ingredient_lines = self._read_ingredients(recipe_obj)
        if not ingredient_lines:
            raise HTTPException(
                status_code=422,
                detail="Recipe ingredients missing.",
            )

        servings = self._parse_servings(recipe_obj.get("recipeYield"))

        return ImportRecipeResponse(
            title=title,
            servings=servings,
            ingredientLines=ingredient_lines,
        )

    def _fetch_html(self, url: str) -> str:
        headers = {
            "User-Agent": (
                "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
                "AppleWebKit/537.36 (KHTML, like Gecko) "
                "Chrome/122.0.0.0 Safari/537.36"
            )
        }

        try:
            with httpx.Client(
                timeout=self.timeout,
                follow_redirects=True,
                headers=headers,
            ) as client:
                response = client.get(url)
                response.raise_for_status()
                return response.text
        except httpx.HTTPError as e:
            raise HTTPException(
                status_code=502,
                detail=f"Could not fetch recipe page: {e}",
            )

    def _extract_recipe_jsonld(self, html: str) -> dict[str, Any]:
        scripts = re.findall(
            r'<script[^>]+type=["\']application/ld\+json["\'][^>]*>(.*?)</script>',
            html,
            flags=re.IGNORECASE | re.DOTALL,
        )

        blobs: list[Any] = []
        for raw in scripts:
            cleaned = raw.strip()
            if not cleaned:
                continue

            cleaned = re.sub(r"^\s*<!--", "", cleaned)
            cleaned = re.sub(r"-->\s*$", "", cleaned)

            try:
                blobs.append(json.loads(cleaned))
            except Exception:
                continue

        recipe = self._find_recipe_object(blobs)
        if recipe is None:
            raise HTTPException(status_code=422, detail="No JSON-LD Recipe found.")

        return recipe

    def _find_recipe_object(self, nodes: list[Any]) -> dict[str, Any] | None:
        recipe: dict[str, Any] | None = None

        def visit(node: Any) -> None:
            nonlocal recipe
            if node is None or recipe is not None:
                return

            if isinstance(node, dict):
                mapped = {str(k): v for k, v in node.items()}

                if self._is_recipe_type(mapped.get("@type")):
                    recipe = mapped
                    return

                if "@graph" in mapped:
                    visit(mapped["@graph"])

                for value in mapped.values():
                    visit(value)

            elif isinstance(node, list):
                for item in node:
                    visit(item)
                    if recipe is not None:
                        return

        for blob in nodes:
            visit(blob)
            if recipe is not None:
                break

        return recipe

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

    def _read_title(self, obj: dict[str, Any]) -> str | None:
        name = obj.get("name")
        if isinstance(name, str):
            value = name.strip()
            return value or None
        return None

    def _read_ingredients(self, obj: dict[str, Any]) -> list[str]:
        raw = obj.get("recipeIngredient")
        if not isinstance(raw, list):
            return []

        out: list[str] = []
        for item in raw:
            text = str(item).strip() if item is not None else ""
            if text:
                out.append(text)
        return out

    def _parse_servings(self, recipe_yield: Any) -> float | None:
        if isinstance(recipe_yield, (int, float)):
            return float(recipe_yield)

        text: str | None = None
        if isinstance(recipe_yield, str):
            text = recipe_yield
        elif isinstance(recipe_yield, list) and recipe_yield:
            first = recipe_yield[0]
            if isinstance(first, (int, float)):
                return float(first)
            if isinstance(first, str):
                text = first

        if text is None:
            return None

        match = re.search(r"(\d+(?:[.,]\d+)?)", text)
        if not match:
            return None

        try:
            return float(match.group(1).replace(",", "."))
        except ValueError:
            return None
