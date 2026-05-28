// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

/// Static helpers that produce Postgres Row-Level Security policy SQL
/// snippets matching the FlutterSync wire schema.
///
/// Supabase consumers paste these snippets directly into the SQL editor.
/// They are intentionally generated rather than executed by the adapter
/// itself so that policy changes remain part of the user's audit trail.
class SupabaseRlsHelper {
  /// Private constructor — the class is a static-only namespace.
  const SupabaseRlsHelper._();

  /// Enables RLS on [table] and authorizes the authenticated user to read,
  /// insert, update, and delete only rows where [userColumn] equals their
  /// `auth.uid()`.
  static String userScoped({
    required String table,
    String userColumn = 'user_id',
  }) =>
      '''
ALTER TABLE $table ENABLE ROW LEVEL SECURITY;

CREATE POLICY "${table}_select_own" ON $table
  FOR SELECT USING ($userColumn = auth.uid());

CREATE POLICY "${table}_insert_own" ON $table
  FOR INSERT WITH CHECK ($userColumn = auth.uid());

CREATE POLICY "${table}_update_own" ON $table
  FOR UPDATE USING ($userColumn = auth.uid())
  WITH CHECK ($userColumn = auth.uid());

CREATE POLICY "${table}_delete_own" ON $table
  FOR DELETE USING ($userColumn = auth.uid());
''';

  /// Enables RLS on [table] and authorizes members of [orgColumn] to access
  /// every row that belongs to one of their organizations (looked up via
  /// [membershipTable], whose `(user_id, org_id)` pairs encode membership).
  static String organizationScoped({
    required String table,
    String orgColumn = 'org_id',
    String membershipTable = 'org_memberships',
  }) =>
      '''
ALTER TABLE $table ENABLE ROW LEVEL SECURITY;

CREATE POLICY "${table}_select_member" ON $table
  FOR SELECT USING (
    $orgColumn IN (
      SELECT org_id FROM $membershipTable WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "${table}_modify_member" ON $table
  FOR ALL USING (
    $orgColumn IN (
      SELECT org_id FROM $membershipTable WHERE user_id = auth.uid()
    )
  )
  WITH CHECK (
    $orgColumn IN (
      SELECT org_id FROM $membershipTable WHERE user_id = auth.uid()
    )
  );
''';

  /// Returns the SQL snippet that creates the canonical Supabase trigger
  /// keeping `updated_at` in sync on every UPDATE — required so that the
  /// adapter's `since` filter works correctly.
  static String updatedAtTrigger(String table) => '''
CREATE OR REPLACE FUNCTION set_updated_at() RETURNS trigger AS \$\$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
\$\$ LANGUAGE plpgsql;

CREATE TRIGGER ${table}_set_updated_at
  BEFORE UPDATE ON $table
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
''';
}
