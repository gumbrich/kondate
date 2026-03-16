from __future__ import annotations

import json
import random
import string
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

        data[household_id] = {
            "householdId": household_id,
            "joinCode": join_code,
            "state": {
                "recipes": [],
                "mealPlan": {"entries": []},
                "targetServings": 2.5,
                "trustedSites": ["chefkoch.de", "springlane.de", "eatsmarter.de"],
                "topN": 3,
            },
        }
        self._write(data)
        return {
            "householdId": household_id,
            "joinCode": join_code,
        }

    def join_household(self, join_code: str) -> dict[str, str] | None:
        data = self._read()
        for household in data.values():
            if household["joinCode"] == join_code:
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
        return household["state"]

    def set_state(self, household_id: str, state: dict[str, Any]) -> bool:
        data = self._read()
        household = data.get(household_id)
        if household is None:
            return False
        household["state"] = state
        self._write(data)
        return True

    def _read(self) -> dict[str, Any]:
        return json.loads(self.path.read_text(encoding="utf-8"))

    def _write(self, data: dict[str, Any]) -> None:
        self.path.write_text(
            json.dumps(data, indent=2, ensure_ascii=False),
            encoding="utf-8",
        )

    def _generate_id(self) -> str:
        return "".join(random.choices(string.ascii_lowercase + string.digits, k=12))

    def _generate_code(self) -> str:
        return "".join(random.choices(string.ascii_uppercase + string.digits, k=6))
