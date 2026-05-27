---
name: Bug report
about: Report a defect or unexpected behavior in FlutterSync.
title: "[bug] <short summary>"
labels: ["bug", "needs-triage"]
assignees: []
---

## Summary

A clear and concise description of what the bug is.

## Reproduction

Minimal, runnable steps that consistently reproduce the issue.

1. Configure FlutterSync with `...`
2. Call `...`
3. Observe `...`

If possible, attach a minimal Dart snippet or a link to a small repository that reproduces the bug.

## Expected behavior

What you expected to happen.

## Actual behavior

What actually happened, including any error messages, stack traces, or unexpected sync state.

## Environment

Fill in every line that applies.

- FlutterSync version (from `pubspec.yaml` or `flutter pub deps`):
- Flutter version (`flutter --version`):
- Dart version:
- Platform (Android / iOS / macOS / Windows / Linux / Web):
- Platform version (for example, Android 14, iOS 17.4, macOS 14.5):
- Backend adapter (Supabase / Firebase / REST / GraphQL / gRPC / Mock / custom):
- Conflict resolver in use (LWW / ServerWins / ClientWins / CRDT / FieldLevel / custom):
- Encryption enabled (yes / no):
- Background sync enabled (yes / no):

## DevTools and logs

If feasible, paste:

- Relevant entries from the `FlutterSyncDevTools` Status, Outbox, Conflicts, HLC, and Network tabs.
- The most recent `SyncLogger` output, with timestamps.
- Any `SyncEvent.permanentFailure` records.

Please redact secrets, tokens, and personal data before submitting.

## Additional context

Any other context, links, related issues, or workarounds you have tried.
