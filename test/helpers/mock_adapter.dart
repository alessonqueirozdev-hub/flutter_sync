// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

// Re-export of the package-shipped MockSyncAdapter under the test/helpers
// namespace so the test suite can import a single, conventional helper
// regardless of where the underlying mock lives.
export 'package:flutter_sync/flutter_sync.dart' show MockSyncAdapter;
