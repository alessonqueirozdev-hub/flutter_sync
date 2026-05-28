# Contributing to FlutterSync

Thank you for your interest in helping build FlutterSync! This document explains how to set up a development environment, what kinds of contributions are most useful right now, and the workflow we follow.

FlutterSync is **early-stage** — the architecture is complete and the test suite is green, but no adapter has been validated against a live backend yet. Your contribution can have a real, visible impact.

---

## Code of Conduct

This project follows the [Contributor Covenant 2.1](CODE_OF_CONDUCT.md). By participating you agree to abide by its terms.

---

## High-impact contributions we are actively asking for

| Area | Why it matters | Effort |
|---|---|---|
| **Validate `SupabaseSyncAdapter` against a real project** | Compiles today, never run against a live Supabase. Most-requested backend. | Medium |
| **Validate `FirebaseSyncAdapter` against Firestore** | Same as above. | Medium |
| **Validate `RestSyncAdapter` against a real REST server** | Generic; any tutorial backend works. | Small |
| **Real device background sync — Android (WorkManager)** | Code is API-correct, never run on a device. | Medium |
| **Real device background sync — iOS (BGTaskScheduler)** | Notoriously hard to test; needs Apple hardware. | Medium-Large |
| **Web ServiceWorker bridge (the JS side)** | Dart side exists; the actual `flutter_sync_sw.js` is missing. | Medium |
| **Wider CRDT property tests (10k seeds, more replicas)** | Current 20-seed suite already caught a `LWWMap` bug — there are likely more. | Small |
| **Drift `OutboxQueue` (persistent variant)** | Today only `InMemoryOutboxQueue` is wired up. | Medium |
| **Performance benchmarks** | No data yet on HLC ticks/sec, outbox throughput, large-batch behavior. | Small-Medium |
| **Tutorials** — "Building X with FlutterSync" | Documentation is reference-style; we need stories. | Small per tutorial |

See [ROADMAP.md](ROADMAP.md) for the longer-term plan.

---

## Development setup

Requires Flutter ≥ 3.19 and Dart ≥ 3.3.

```bash
# Clone
git clone https://github.com/alessonqueirozdev-hub/flutter_sync.git
cd flutter_sync

# Install dependencies
flutter pub get

# Verify everything is green before you start
dart format --output=none --set-exit-if-changed .
dart analyze --fatal-infos --fatal-warnings
flutter test
```

To run the example app:

```bash
cd example
flutter pub get
flutter run -d chrome        # or -d windows, -d macos, -d linux, -d <android-device-id>
```

---

## Branching model

```
main      ← protected; v0.1.x releases, squash-merges from develop only
develop   ← integration; PRs land here first
└── feat|fix|docs|chore/<short-name>   ← your work happens here
```

**Branch naming:** lowercase kebab-case prefixed `feat/`, `fix/`, `docs/`, `chore/`, `ci/`. Examples:

- `feat/supabase-batch-retry`
- `fix/lww-set-tombstone-leak`
- `docs/getting-started-supabase`

Always branch from `develop`, never from `main`.

---

## Commit conventions

We use **[Conventional Commits](https://www.conventionalcommits.org/)** for community contributions:

```
type(scope): imperative description (≤72 chars)

Optional longer body explaining *why*, not *what*. Wrap at 72 chars.
```

**Types:** `feat` · `fix` · `test` · `docs` · `chore` · `refactor` · `ci` · `perf` · `style`

**Scope:** lowercase layer/module — `hlc`, `outbox`, `crdt`, `models`, `core`, `store`, `scheduler`, `supabase-adapter`, `firebase-adapter`, `rest-adapter`, `graphql-adapter`, `grpc-adapter`, `mock-adapter`, `encryption`, `audit`, `migrations`, `logging`, `bandwidth`, `devtools`, `example`, `readme`.

**Good examples:**

```
feat(supabase-adapter): retry push on connection reset
fix(crdt): make LWWMap merge commutative on HLC ties
test(hlc): add property tests for receive() drift detection
docs(getting-started): add Firebase quickstart
```

**Notes:**
- Historical commits use a `[NNN]` sequential prefix (`[001]` through `[178]`). This was an internal cataloging convention; **contributors do not need to follow it**. Maintainers may add a number on merge.
- No emojis in commit subjects.
- No ticket references in subjects (they go in the body if needed).
- One logical change per commit. Two files in one commit is fine if they belong to the same change (e.g. source + its test).

---

## Pull request process

1. Fork the repo, branch from `develop`, make your change.
2. Run the local gate (see Development setup).
3. Open a PR against `develop` with a clear description (the template will guide you).
4. CI must be green before review. CI runs `dart analyze`, `dart format` check, and `flutter test`.
5. A maintainer reviews. Expect comments — this is a young codebase and we are still discovering good patterns together.
6. Squash-merge when approved.

For larger changes (new adapter, breaking change, schema migration), please open an issue or a [Discussion](https://github.com/alessonqueirozdev-hub/flutter_sync/discussions) first so we can talk through the design.

---

## Code style

- **Dart 3.3+** with the full lint set from `analysis_options.yaml`.
- `dart format` is the formatter. No exceptions.
- Use `sealed class` for unions; `pattern matching` in every `switch` over a sealed class (exhaustiveness required).
- All immutable fields are `final`. Value objects are `@immutable`.
- Every public class, method, and field has a `///` DartDoc with a complete first-sentence summary.
- **No `dynamic`** in public APIs. **No `late`** in public APIs without DartDoc rationale.
- Never use `throw UnimplementedError()` as a stub body.
- Never leave `// TODO`, `// FIXME`, `// XXX`, `// HACK` in committed code. Open an issue instead.

### Streams and resources

- Public streams are `broadcast` by default.
- Every `StreamController` is closed in `dispose()`. Every `StreamSubscription` is cancelled.
- `.distinct()` on all status streams to suppress duplicate emissions.

### Async

- Never use exceptions for control flow.
- Use `SyncResult<T, E>` (or typed exceptions) for fallible operations.
- Log every error through `SyncLogger` before propagating.
- Heavy work (Argon2id derivation, AES of large batches, delta computation > 1000 records) runs in `Isolate.run()`.

---

## Tests

Every PR that adds logic must add tests. Coverage targets:

| Component | Target |
|---|---|
| Overall package | 80% |
| Core engine (`lib/src/core/`) | 95% |
| HLC | **100%** |
| Conflict resolvers | **100%** |
| CRDTs | **100%** |
| Outbox | 90% |

Categories you should cover for any non-trivial class:

- **Unit** — happy path, boundary values, invalid inputs, empty state, serialization round-trip.
- **Behavioral** — offline behavior, retry attempts and delays, conflict outcomes, multi-client simulation.
- **Integration** — full `write → outbox → push → pull → resolve → apply` cycle.
- **Property-based** — for CRDTs, random op sequences on N replicas in random orders; final state must converge on every replica.

Run a single test file:

```bash
flutter test test/path/to/file_test.dart
```

Run with coverage:

```bash
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
```

---

## Licensing and copyright

By contributing you agree your work is released under the [Apache 2.0 License](LICENSE).

Every new `.dart` file must include the SPDX header on its first two lines:

```dart
// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.
```

---

## Reporting security issues

Do not open a public issue for security vulnerabilities. See [SECURITY.md](SECURITY.md).

---

## Reporting bugs / requesting features

Use the GitHub issue templates:

- [Bug report](https://github.com/alessonqueirozdev-hub/flutter_sync/issues/new?template=bug_report.md)
- [Feature request](https://github.com/alessonqueirozdev-hub/flutter_sync/issues/new?template=feature_request.md)

For open-ended questions or design discussions, use [GitHub Discussions](https://github.com/alessonqueirozdev-hub/flutter_sync/discussions).

---

## Questions?

If something isn't clear, open a Discussion. Helping us improve this guide is itself a contribution.

Thank you for being here.
