# Kondate agent instructions

## Start and finish

- Read `docs/project-status.md`, `docs/attempts.md`, and the relevant acceptance test before changing code.
- Primary device is Mac. Check Android after substantial improvements.
- Keep work on a task branch. Use isolated worktrees for concurrent edits.
- Run relevant tests, record their results, and update project status before committing.
- Distinguish verified behavior, implemented-but-unverified behavior, known defects, and missing functionality. A commit or passing unit test is not proof that a live retailer flow works.
- Record failed tools/approaches and why they failed in `docs/attempts.md`.

## Reviews

- Use Claude Code for an independent read-only review when available and authorized. Do not claim a Claude review without an actual report.
- Reviewers must not modify the working copy. Report actionable findings with file/line references. Implementation agents resolve findings and rerun affected checks.
- Commit and push reviewable changes and open a pull request when requested as part of the task. Keep merge/deployment decisions with the user unless explicitly delegated.

## Coop

- Never treat a click or an optimistic counter as proof of a successful basket mutation.
- Scope actions and quantity evidence to the exact product SKU, then verify persisted quantity after a page reload.
- Targets are total packs in the basket, including existing packs. Do not infer package counts from ingredient weights without known package data.
- Stop on ambiguous results; do not automatically repeat uncertain writes.
- Do not submit checkout, payment, or an order as part of development testing.
- Never print, commit, or send credentials, cookies, tokens, private household data, or delivery details to a reviewer.

## Architecture and checks

- Flutter UI: `apps/mobile`; domain logic: `packages/core`; parser: `packages/recipe_parser`; Python API: `backend`.
- From the affected Flutter package: `flutter analyze` and `flutter test`.
- Mac smoke test: `flutter run -d macos` from `apps/mobile`.
- Preserve existing recipes and household state. Do not include generated platform-file churn in feature commits.
