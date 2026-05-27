// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'package:meta/meta.dart';

/// Comparison operators supported by [SyncQuery] and [SyncQueryCondition].
enum SyncQueryOperator {
  /// Equality comparison.
  equals,

  /// Inequality comparison.
  notEquals,

  /// Less-than comparison (numeric or lexicographic).
  lessThan,

  /// Less-than-or-equal comparison.
  lessThanOrEqual,

  /// Greater-than comparison.
  greaterThan,

  /// Greater-than-or-equal comparison.
  greaterThanOrEqual,

  /// Membership in a list of values.
  inList,

  /// Non-membership in a list of values.
  notInList,

  /// `LIKE` substring match (case-insensitive).
  contains,

  /// Begins-with substring match (case-insensitive).
  startsWith,

  /// Ends-with substring match (case-insensitive).
  endsWith,

  /// Field is null.
  isNull,

  /// Field is not null.
  isNotNull,
}

/// Sort direction for [SyncQuerySort].
enum SyncQuerySortDirection {
  /// Ascending order.
  ascending,

  /// Descending order.
  descending,
}

/// A single condition in a [SyncQuery] WHERE clause.
@immutable
class SyncQueryCondition {
  /// Creates an immutable condition.
  const SyncQueryCondition({
    required this.field,
    required this.operator,
    this.value,
  });

  /// Field name being compared.
  final String field;

  /// Comparison operator.
  final SyncQueryOperator operator;

  /// Comparison value; ignored for [SyncQueryOperator.isNull] and
  /// [SyncQueryOperator.isNotNull].
  final Object? value;

  @override
  bool operator ==(Object other) =>
      other is SyncQueryCondition &&
      other.field == field &&
      other.operator == operator &&
      other.value == value;

  @override
  int get hashCode => Object.hash(field, operator, value);

  @override
  String toString() => 'SyncQueryCondition($field $operator $value)';
}

/// A single ORDER BY clause in a [SyncQuery].
@immutable
class SyncQuerySort {
  /// Creates an immutable sort clause.
  const SyncQuerySort({required this.field, required this.direction});

  /// Field name being sorted.
  final String field;

  /// Ascending or descending direction.
  final SyncQuerySortDirection direction;

  @override
  bool operator ==(Object other) =>
      other is SyncQuerySort &&
      other.field == field &&
      other.direction == direction;

  @override
  int get hashCode => Object.hash(field, direction);

  @override
  String toString() => 'SyncQuerySort($field, $direction)';
}

/// Fluent, immutable query builder for `SyncStore.findAll` and
/// `SyncRepository.findAll` / `.watch`.
///
/// Every mutating method returns a NEW [SyncQuery]; the builder itself
/// is immutable so it is safe to share across threads and stream listeners.
///
/// ```dart
/// final query = SyncQuery()
///     .where('user_id', equals: currentUser.id)
///     .where('completed', equals: false)
///     .orderBy('created_at', descending: true)
///     .limit(50);
/// ```
@immutable
class SyncQuery {
  /// Creates a query with optional pre-populated clauses.
  const SyncQuery({
    this.conditions = const <SyncQueryCondition>[],
    this.sorts = const <SyncQuerySort>[],
    this.limitCount,
    this.offsetCount,
    this.includeDeleted = false,
  });

  /// Immutable list of WHERE conditions; combined with logical AND.
  final List<SyncQueryCondition> conditions;

  /// Immutable list of ORDER BY clauses applied in order.
  final List<SyncQuerySort> sorts;

  /// Maximum number of records returned; `null` for no limit.
  final int? limitCount;

  /// Number of records skipped at the beginning of the result; `null`
  /// for no offset.
  final int? offsetCount;

  /// When `true`, tombstones (records with `isDeleted: true`) are returned
  /// alongside live records. Defaults to `false`.
  final bool includeDeleted;

  /// Returns a new query with an equality WHERE condition appended.
  SyncQuery where(
    String field, {
    Object? equals,
    Object? notEquals,
    Object? lessThan,
    Object? lessThanOrEqual,
    Object? greaterThan,
    Object? greaterThanOrEqual,
    List<Object?>? inList,
    List<Object?>? notInList,
    String? contains,
    String? startsWith,
    String? endsWith,
    bool? isNull,
  }) {
    final SyncQueryCondition condition = _resolveCondition(
      field: field,
      equals: equals,
      notEquals: notEquals,
      lessThan: lessThan,
      lessThanOrEqual: lessThanOrEqual,
      greaterThan: greaterThan,
      greaterThanOrEqual: greaterThanOrEqual,
      inList: inList,
      notInList: notInList,
      contains: contains,
      startsWith: startsWith,
      endsWith: endsWith,
      isNull: isNull,
    );
    return SyncQuery(
      conditions: <SyncQueryCondition>[...conditions, condition],
      sorts: sorts,
      limitCount: limitCount,
      offsetCount: offsetCount,
      includeDeleted: includeDeleted,
    );
  }

  /// Returns a new query with an ORDER BY clause appended.
  SyncQuery orderBy(String field, {bool descending = false}) {
    return SyncQuery(
      conditions: conditions,
      sorts: <SyncQuerySort>[
        ...sorts,
        SyncQuerySort(
          field: field,
          direction: descending
              ? SyncQuerySortDirection.descending
              : SyncQuerySortDirection.ascending,
        ),
      ],
      limitCount: limitCount,
      offsetCount: offsetCount,
      includeDeleted: includeDeleted,
    );
  }

  /// Returns a new query with the supplied [count] applied as the limit.
  SyncQuery limit(int count) {
    return SyncQuery(
      conditions: conditions,
      sorts: sorts,
      limitCount: count,
      offsetCount: offsetCount,
      includeDeleted: includeDeleted,
    );
  }

  /// Returns a new query with the supplied [count] applied as the offset.
  SyncQuery offset(int count) {
    return SyncQuery(
      conditions: conditions,
      sorts: sorts,
      limitCount: limitCount,
      offsetCount: count,
      includeDeleted: includeDeleted,
    );
  }

  /// Returns a new query that includes tombstoned records.
  SyncQuery withDeleted() {
    return SyncQuery(
      conditions: conditions,
      sorts: sorts,
      limitCount: limitCount,
      offsetCount: offsetCount,
      includeDeleted: true,
    );
  }

  SyncQueryCondition _resolveCondition({
    required String field,
    Object? equals,
    Object? notEquals,
    Object? lessThan,
    Object? lessThanOrEqual,
    Object? greaterThan,
    Object? greaterThanOrEqual,
    List<Object?>? inList,
    List<Object?>? notInList,
    String? contains,
    String? startsWith,
    String? endsWith,
    bool? isNull,
  }) {
    if (equals != null) {
      return SyncQueryCondition(
        field: field,
        operator: SyncQueryOperator.equals,
        value: equals,
      );
    }
    if (notEquals != null) {
      return SyncQueryCondition(
        field: field,
        operator: SyncQueryOperator.notEquals,
        value: notEquals,
      );
    }
    if (lessThan != null) {
      return SyncQueryCondition(
        field: field,
        operator: SyncQueryOperator.lessThan,
        value: lessThan,
      );
    }
    if (lessThanOrEqual != null) {
      return SyncQueryCondition(
        field: field,
        operator: SyncQueryOperator.lessThanOrEqual,
        value: lessThanOrEqual,
      );
    }
    if (greaterThan != null) {
      return SyncQueryCondition(
        field: field,
        operator: SyncQueryOperator.greaterThan,
        value: greaterThan,
      );
    }
    if (greaterThanOrEqual != null) {
      return SyncQueryCondition(
        field: field,
        operator: SyncQueryOperator.greaterThanOrEqual,
        value: greaterThanOrEqual,
      );
    }
    if (inList != null) {
      return SyncQueryCondition(
        field: field,
        operator: SyncQueryOperator.inList,
        value: inList,
      );
    }
    if (notInList != null) {
      return SyncQueryCondition(
        field: field,
        operator: SyncQueryOperator.notInList,
        value: notInList,
      );
    }
    if (contains != null) {
      return SyncQueryCondition(
        field: field,
        operator: SyncQueryOperator.contains,
        value: contains,
      );
    }
    if (startsWith != null) {
      return SyncQueryCondition(
        field: field,
        operator: SyncQueryOperator.startsWith,
        value: startsWith,
      );
    }
    if (endsWith != null) {
      return SyncQueryCondition(
        field: field,
        operator: SyncQueryOperator.endsWith,
        value: endsWith,
      );
    }
    if (isNull != null) {
      return SyncQueryCondition(
        field: field,
        operator: isNull
            ? SyncQueryOperator.isNull
            : SyncQueryOperator.isNotNull,
      );
    }
    throw ArgumentError(
      'SyncQuery.where requires exactly one comparison argument.',
    );
  }

  @override
  String toString() =>
      'SyncQuery(conditions: ${conditions.length}, sorts: ${sorts.length}, '
      'limit: $limitCount, offset: $offsetCount)';
}
