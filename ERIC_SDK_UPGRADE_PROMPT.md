# ERIC SDK Upgrade Prompt

Use this prompt for future upgrades, replacing `<VERSION>` with the complete ERIC release version.

```text
Upgrade this repository to ERIC SDK <VERSION> end to end.

1. Inspect the repository, its current git status, release history, SDK installer, supported-version configuration, FFI declarations, wrappers, tests, README, changelog, and gem version before editing. Preserve unrelated worktree changes.
2. Set the installer release to <VERSION> and run `ERIC_VERSION=<VERSION> bundle exec rake eric:install`. Do not guess when a download fails: verify ELSTER's current `eric_<major>` directory and exact SDK, documentation, and schema-documentation artifact names, update the installer and its tests, then rerun the task.
3. Treat the downloaded SDK headers as the source of truth. Compare `ericapi.h`, `eric_types.h`, and `eric_fehlercodes.h` with all Ruby FFI functions, parameter and return types, callbacks, enum values, struct members, struct versions, and error-code mappings. Check exported symbols by loading the gem against the real shared library. Keep compatibility constants only where existing gem consumers may rely on them.
4. Make the smallest compatible gem changes. Pay special attention to native handle widths, pointer fields, callback fields, alignment, and struct size; an unchanged struct version does not guarantee that an old Ruby layout is complete.
5. Improve tests so the next upgrade detects drift automatically. Keep fast tests independent of an SDK, and add installed-SDK tests that load every attached symbol, call safe native functions such as `EricVersion` and `EricSystemCheck`, compare every header error code with the Ruby map, and compile a small C layout probe to compare `sizeof`/`offsetof` with FFI struct sizes and offsets. Tests requiring the SDK should skip clearly when it is absent.
6. Run the installer a second time to verify idempotence. Run the full specs against the installed SDK, build the gem, and inspect the packaged file list. Resolve all failures and warnings caused by the upgrade.
7. Update installation documentation, the changelog, and the reusable upgrade prompt with generic lessons only. Bump the gem version according to semantic versioning; normally use a minor bump for support for a new ERIC release unless compatibility requires a major bump.
8. Before committing, inspect `git status`, the complete diff, and recent commits. Stage only intended files, excluding downloaded SDK files and unrelated changes. Create one concise commit describing the ERIC upgrade and report the version, commit hash, verification commands, and any residual risks. Do not tag, push, or publish unless explicitly requested.
```
