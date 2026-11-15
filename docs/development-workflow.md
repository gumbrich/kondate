# Kondate development workflow

Use Codex to implement a small GitHub issue and Claude Code to independently review the resulting change. Keep the repository as the shared project memory; chats are supporting context.

1. Read `AGENTS.md`, `docs/project-status.md`, `docs/attempts.md`, and the task's acceptance criteria.
2. Start a task branch from current `main`. Use a separate worktree if more than one agent edits simultaneously. A reviewer can use the same working copy read-only while implementation is paused.
3. Reproduce the failure or identify concrete evidence. Write down what has and has not been verified.
4. Implement the smallest complete improvement. Run relevant automated checks and then the device test where available.
5. Ask Claude for a read-only review of the diff and new files. Record actual findings, fix them, and repeat affected checks. If authentication is unavailable, mark the review pending.
6. Update status and attempts with the outcome, then commit, push, and open a pull request. The user reviews the app behavior before merging/deploying.

## Local commands

From `apps/mobile/`:

```sh
flutter pub get
flutter analyze
flutter test
flutter run -d macos
```

Core and recipe-parser checks use `flutter analyze` and `flutter test` from their respective directories. Run them when changes affect those packages.

Claude Code sign-in is performed by the user with `claude auth login`. `claude auth status` checks availability without printing credentials. Never copy access tokens into a chat, repository, or log.

For a manual review in Claude Code, open the Kondate repository, ask it to read `CLAUDE.md`, and review the current branch against `origin/main` without editing. Require concrete findings and file/line references. Model availability depends on the signed-in account; do not claim another agent performed a review when it did not.

## Task completion record

Every pull request records:

- The user-visible behavior changed.
- Tests executed and exact outcome.
- Device and live-service checks, separately from unit tests.
- Remaining failures or unverified assumptions.
- Independent reviewer, findings, and resolution.

Keep configuration files and secrets local. Do not modify household data or saved recipes as part of a test without recording the intended change.
