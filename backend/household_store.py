from __future__ import annotations

import json
import random
import string
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


class HouseholdStore:
    def __init__(self, filepath: str = "households.json") -> None:
        self.path = Path(filepath)
        if not self.path.exists():
            self.path.write_text("{}", encoding="utf-8")

    def create_household(self) -> dict[str, str]:
        data = self._read()

        household_id = self._generate_id()
        join_code = self._generate_code()

        while household_id in data:
            household_id = self._generate_id()

        while any(h["joinCode"] == join_code for h in data.values()):
            join_code = self._generate_code()

        now = self._now_iso()

        data[household_id] = {
            "householdId": household_id,
            "joinCode": join_code,
            "updatedAt": now,
            "state": {
                "recipes": [],
                "mealPlan": {"entries": []},
                "trustedSites": ["chefkoch.de", "springlane.de", "eatsmarter.de"],
                "topN": 3,
                "targetServings": 2,
                "shoppingState": {
                    "checkedGeneratedItemIds": [],
                    "removedGeneratedItemIds": [],
                    "manualItems": [],
                },
            },
        }

        self._write(data)

        return {
            "householdId": household_id,
            "joinCode": join_code,
        }

    def join_household(self, join_code: str) -> dict[str, str] | None:
        data = self._read()

        normalized = join_code.strip().upper()

        for household in data.values():
            if household["joinCode"] == normalized:
                return {
                    "householdId": household["householdId"],
                    "joinCode": household["joinCode"],
                }

        return None

    def get_state(self, household_id: str) -> dict[str, Any] | None:
        data = self._read()
        household = data.get(household_id)

        if household is None:
            return None

        self._ensure_household_shape(household)

        self._write(data)

        return {
            "householdId": household["householdId"],
            "updatedAt": household["updatedAt"],
            "state": household["state"],
        }

    def set_state(
        self,
        household_id: str,
        state: dict[str, Any],
        last_seen_updated_at: str | None,
    ) -> tuple[bool, str | None]:
        data = self._read()
        household = data.get(household_id)

        if household is None:
            return False, None

        self._ensure_household_shape(household)

        current_updated_at = household["updatedAt"]

        if (
            last_seen_updated_at is not None
            and last_seen_updated_at.strip() != ""
            and last_seen_updated_at != current_updated_at
        ):
            return False, current_updated_at

        household["state"] = state
        self._ensure_state_shape(household["state"])
        household["updatedAt"] = self._now_iso()

        self._write(data)

        return True, household["updatedAt"]

    def _ensure_household_shape(self, household: dict[str, Any]) -> None:
        if "updatedAt" not in household:
            household["updatedAt"] = self._now_iso()

        if "state" not in household or not isinstance(household["state"], dict):
            household["state"] = {}

        self._ensure_state_shape(household["state"])

    def _ensure_state_shape(self, state: dict[str, Any]) -> None:
        state.setdefault("recipes", [])
        state.setdefault("mealPlan", {"entries": []})
        state.setdefault(
            "trustedSites",
            ["chefkoch.de", "springlane.de", "eatsmarter.de"],
        )
        state.setdefault("topN", 3)
        state.setdefault("targetServings", 2)

        if "shoppingState" not in state or not isinstance(state["shoppingState"], dict):
            state["shoppingState"] = {}

        shopping_state = state["shoppingState"]
        shopping_state.setdefault("checkedGeneratedItemIds", [])
        shopping_state.setdefault("removedGeneratedItemIds", [])
        shopping_state.setdefault("manualItems", [])

    def _read(self) -> dict[str, Any]:
        try:
            return json.loads(self.path.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            return {}

    def _write(self, data: dict[str, Any]) -> None:
        self.path.write_text(
            json.dumps(data, indent=2, ensure_ascii=False),
            encoding="utf-8",
        )

    def _generate_id(self) -> str:
        return "".join(
            random.choices(string.ascii_lowercase + string.digits, k=12)
        )

    def _generate_code(self) -> str:
        return "".join(
            random.choices(string.ascii_uppercase + string.digits, k=6)
        )

    def _now_iso(self) -> str:
        return datetime.now(timezone.utc).isoformat()
