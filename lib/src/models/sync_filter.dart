// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'package:meta/meta.dart';

/// Comparison operators supported by [SyncFilter].
enum SyncFilterOperator {
  /// Equality comparison.
  equals,

  /// Inequality comparison.
  notEquals,

  /// Less-than comparison.
  lessThan,

  /// Less-than-or-equal comparison.
  lessThanOrEqual,

  /// Greater-than comparison.
  greaterThan,

  /// Greater-than-or-equal comparison.
  greaterThanOrEqual,

  /// Membership in a list of values.
  inList,
}

/// Server-side predicate used to drive partial (selective) sync.
///
/// Unlike [SyncQuery], which is evaluated by the local store, [SyncFilter]
/// is forwarded to the backend adapter and applied at the source, so that
/// only the records matching the filter are ever transferred. This is the
/// primary mechanism for multi-tenant isolation, per-user data scoping,
/// and bandwidth control.
///
/// Filters are composed with logical AND. Use [SyncFilter.and] or
/// [SyncFilter.or] to compose nested logical structures.
@immutable
sealed class SyncFilter {
  /// Internal const constructor for subclasses.
  const SyncFilter();

  /// Creates an equality filter (`field == value`).
  factory SyncFilter.where(
    String field, {
    required Object? isEqualTo,
  }) =>
      SyncFilterCondition(
        field: field,
        operator: SyncFilterOperator.equals,
        value: isEqualTo,
      );

  /// Creates a "not equals" filter (`field != value`).
  factory SyncFilter.whereNot(
    String field, {
    required Object? isEqualTo,
  }) =>
      SyncFilterCondition(
        field: field,
        operator: SyncFilterOperator.notEquals,
        value: isEqualTo,
      );

  /// Creates a "less than" filter (`field < value`).
  factory SyncFilter.whereLessThan(String field, Object value) =>
      SyncFilterCondition(
        field: field,
        operator: SyncFilterOperator.lessThan,
        value: value,
      );

  /// Creates a "greater than" filter (`field > value`).
  factory SyncFilter.whereGreaterThan(String field, Object value) =>
      SyncFilterCondition(
        field: field,
        operator: SyncFilterOperator.greaterThan,
        value: value,
      );

  /// Creates a "membership" filter (`field IN values`).
  factory SyncFilter.whereIn(String field, List<Object?> values) =>
      SyncFilterCondition(
        field: field,
        operator: SyncFilterOperator.inList,
        value: values,
      );

  /// Composes an AND filter from the supplied children.
  factory SyncFilter.and(List<SyncFilter> children) =>
      SyncFilterAnd(children);

  /// Composes an OR filter from the supplied children.
  factory SyncFilter.or(List<SyncFilter> children) => SyncFilterOr(children);
}

/// Leaf filter representing a single field comparison.
final class SyncFilterCondition extends SyncFilter {
  /// Creates a leaf condition.
  const SyncFilterCondition({
    required this.field,
    required this.operator,
    this.value,
  });

  /// Field name being compared.
  final String field;

  /// Comparison operator.
  final SyncFilterOperator operator;

  /// Comparison value.
  final Object? value;

  @override
  bool operator ==(Object other) =>
      other is SyncFilterCondition &&
      other.field == field &&
      other.operator == operator &&
      other.value == value;

  @override
  int get hashCode => Object.hash(field, operator, value);

  @override
  String toString() => 'SyncFilter($field $operator $value)';
}

/// Compound filter combining children with logical AND.
final class SyncFilterAnd extends SyncFilter {
  /// Creates an AND filter over [children].
  const SyncFilterAnd(this.children);

  /// Child filters combined with logical AND.
  final List<SyncFilter> children;

  @override
  bool operator ==(Object other) =>
      other is SyncFilterAnd &&
      other.children.length == children.length &&
      _listEquals(other.children, children);

  @override
  int get hashCode => Object.hashAll(children);

  @override
  String toString() => 'SyncFilter.and($children)';
}

/// Compound filter combining children with logical OR.
final class SyncFilterOr extends SyncFilter {
  /// Creates an OR filter over [children].
  const SyncFilterOr(this.children);

  /// Child filters combined with logical OR.
  final List<SyncFilter> children;

  @override
  bool operator ==(Object other) =>
      other is SyncFilterOr &&
      other.children.length == children.length &&
      _listEquals(other.children, children);

  @override
  int get hashCode => Object.hashAll(children);

  @override
  String toString() => 'SyncFilter.or($children)';
}

bool _listEquals(List<Object?> a, List<Object?> b) {
  if (identical(a, b)) {
    return true;
  }
  if (a.length != b.length) {
    return false;
  }
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}
