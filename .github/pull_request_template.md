<!-- Title: `<type>(<scope>): <imperative description ≤72 chars>` -->

## Summary

<!-- 2-4 sentences describing what changed and why. Focus on the why, not the what. -->

## Files added or modified

<!-- One bullet per file, with a one-line purpose. -->

- `path/to/file.dart` — one-line purpose
- `path/to/file_test.dart` — one-line purpose

## Verification

- [ ] `dart analyze --fatal-infos --fatal-warnings` reports zero issues
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
- [ ] Public-API changes also update `lib/flutter_sync.dart`, the relevant README section, and `CHANGELOG.md`

## Notes

<!-- Optional. Design decisions worth recording, follow-up tasks, links to external context. -->

---

By submitting this pull request I confirm my contribution is offered under the terms of the [Apache 2.0 License](../LICENSE).
