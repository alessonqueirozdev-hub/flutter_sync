# Background sync setup

Background sync is opt-in per platform: the engine works in the foreground out of the box, but to keep syncing while the app is closed you must add a few platform manifest entries.

## Android

Add the following permissions to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
```

Register the callback in `main.dart`:

```dart
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    final flutterSync = await FlutterSync.configure(...);
    await flutterSync.syncNow();
    return true;
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Workmanager().initialize(callbackDispatcher);
  final flutterSync = await FlutterSync.configure(adapter: ..., store: ...);
  await AndroidBackgroundSync().register(
    config: const BackgroundSyncConfig(
      taskName: 'flutter_sync_background',
      interval: Duration(minutes: 15),
    ),
    onSync: () async => true,
  );
  runApp(MyApp(flutterSync: flutterSync));
}
```

## iOS

Add to `ios/Runner/Info.plist`:

```xml
<key>UIBackgroundModes</key>
<array>
  <string>fetch</string>
  <string>processing</string>
</array>
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
  <string>com.transistorsoft.fetch</string>
</array>
```

Register on the Dart side:

```dart
await IOSBackgroundSync().register(
  config: const BackgroundSyncConfig(
    taskName: 'flutter_sync_background',
    interval: Duration(minutes: 15),
  ),
  onSync: () async {
    await flutterSync.syncNow();
    return true;
  },
);
```

Note that iOS clamps the minimum interval to 15 minutes and may delay execution further.

## macOS / Windows / Linux

Desktop platforms do not expose a system-level periodic scheduler that survives termination. `DesktopBackgroundSync` instead drives a `Timer.periodic` in-process while the app is alive:

```dart
await DesktopBackgroundSync().register(
  config: const BackgroundSyncConfig(
    taskName: 'flutter_sync_background',
    interval: Duration(minutes: 5),
  ),
  onSync: () async {
    await flutterSync.syncNow();
    return true;
  },
);
```

To sync while the app is closed, register a Windows Task Scheduler job (or `launchd` plist on macOS, or `systemd` timer on Linux) that calls a small companion binary.

## Web

Web background sync needs a `ServiceWorker` registration in `web/index.html`:

```html
<script>
  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.register('/flutter_sync_sw.js');
  }
</script>
```

The Dart side:

```dart
final webSync = WebBackgroundSync();
await webSync.register(
  config: const BackgroundSyncConfig(
    taskName: 'flutter_sync_background',
    interval: Duration(minutes: 5),
  ),
  onSync: () async {
    await flutterSync.syncNow();
    return true;
  },
);
```

The service worker invokes `webSync.handleSyncEvent()` when the browser fires a `sync` event.
