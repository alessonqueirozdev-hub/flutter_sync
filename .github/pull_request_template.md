<!-- Title format: "Phase NN — Short title" or "<type>(<scope>): <imperative description>" -->

## Summary

<!-- 2-4 sentences describing what changed and why. Focus on the why, not the what. -->

## Files added or modified

<!-- One bullet per file, with a one-line purpose. -->

- `path/to/file.dart` — one-line purpose
- `path/to/file_test.dart` — one-line purpose

## Verification

- [ ] `dart analyze` reports zero issues
- [ ] `dart format --output=none --set-exit-if-changed .` passes
- [ ] All tests pass (`flutter test`)
- [ ] No TODOs, FIXMEs, XXX, or HACK markers introduced
- [ ] No `throw UnimplementedError()` stub bodies
- [ ] All `.dart` files include the Apache 2.0 SPDX header
- [ ] Every public symbol has DartDoc with a complete first-sentence summary
- [ ] Every `StreamController` and `StreamSubscription` is disposed
- [ ] Every `Isolate.run` block has a justification comment
- [ ] Commit messages follow `[NNN] type(scope): imperative description` (≤72 chars)
- [ ] Coverage targets respected (overall ≥80%, HLC and CRDTs 100%, core ≥95%, conflict ≥100%)

## Phase information

<!-- For phase PRs only. Delete this section for non-phase work. -->

- Phase number:
- Commit range: `[NNN-start]` through `[NNN-end]`
- Branch: `feat/phase-NN-<name>`

## Notes

<!-- Optional. Design decisions worth recording, follow-up tasks, links to external context. -->
