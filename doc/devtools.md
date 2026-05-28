# DevTools overlay

`FlutterSyncDevTools` is a debug-only widget that overlays a sync-status pill and a floating "developer board" button on top of your app. Tapping the button opens a tabbed inspector at the bottom of the screen.

## Wrap your top-level widget

```dart
runApp(
  kDebugMode
    ? FlutterSyncDevTools(
        flutterSync: flutterSync,
        auditTrail: auditTrail,
        child: const MyApp(),
      )
    : const MyApp(),
);
```

Always guard with `kDebugMode`: DevTools brings observability widgets that are not appropriate for release builds.

## Tabs

### Status

Renders the current `SyncStatus` (`idle`, `syncing`, `synced`, `offline`, `paused`, `error`) with a colored pill, last-sync timestamp, and progress indicator while a sync is in flight.

### Outbox

Lists every collection with pending/failed counts plus a "Flush now" button that calls `flutterSync.syncNow()` and reloads.

### Conflicts

Streams from the supplied `AuditTrail` filtered to `AuditOperation.conflictResolved`. Each entry shows the affected record key, the resolution strategy that was used, and a JSON export button that copies the full log to the clipboard.

## Building your own inspector

Every widget under `lib/src/devtools/` consumes only the public API (`flutterSync.status`, `flutterSync.debugInfo`, `auditTrail.find`). Copy them into your own app and customize as needed.
