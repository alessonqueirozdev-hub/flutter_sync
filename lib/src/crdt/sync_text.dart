// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 The FlutterSync Authors. All rights reserved.

import 'dart:math' as math;

import 'package:meta/meta.dart';

/// Single atom inside a [LogootPosition].
///
/// The pair `(digit, siteId)` is compared first by [digit] (numeric) and
/// then by [siteId] (lexicographic) so that the resulting total order on
/// positions is dense — between any two distinct positions there is always
/// at least one new position the algorithm can synthesize.
@immutable
class LogootAtom implements Comparable<LogootAtom> {
  /// Creates an immutable atom.
  const LogootAtom(this.digit, this.siteId);

  /// Numeric component of the atom, in `[0, base)`.
  final int digit;

  /// Stable site identifier — typically the HLC `nodeId` of the site that
  /// generated the surrounding position.
  final String siteId;

  @override
  int compareTo(LogootAtom other) {
    if (digit != other.digit) {
      return digit.compareTo(other.digit);
    }
    return siteId.compareTo(other.siteId);
  }

  @override
  bool operator ==(Object other) =>
      other is LogootAtom && other.digit == digit && other.siteId == siteId;

  @override
  int get hashCode => Object.hash(digit, siteId);

  @override
  String toString() => '($digit, $siteId)';
}

/// Dense, lexicographically-ordered position identifier used by [SyncText].
@immutable
class LogootPosition implements Comparable<LogootPosition> {
  /// Creates a position from the supplied list of [atoms].
  LogootPosition(List<LogootAtom> atoms)
      : atoms = List<LogootAtom>.unmodifiable(atoms);

  /// The empty position, used as the lower bound when inserting at index 0.
  static const LogootPosition empty = LogootPosition._const(<LogootAtom>[]);

  const LogootPosition._const(this.atoms);

  /// Sequence of atoms that make up this position.
  final List<LogootAtom> atoms;

  /// `true` when this position contains no atoms (the sentinel lower bound).
  bool get isEmpty => atoms.isEmpty;

  @override
  int compareTo(LogootPosition other) {
    final int minLen = math.min(atoms.length, other.atoms.length);
    for (int i = 0; i < minLen; i++) {
      final int cmp = atoms[i].compareTo(other.atoms[i]);
      if (cmp != 0) {
        return cmp;
      }
    }
    return atoms.length.compareTo(other.atoms.length);
  }

  /// Returns the canonical wire representation: atoms joined by `.`, each
  /// atom serialized as `digit:siteId`.
  String toWire() =>
      atoms.map((LogootAtom a) => '${a.digit}:${a.siteId}').join('.');

  /// Reconstructs a position from its [LogootPosition.toWire] form.
  factory LogootPosition.parse(String wire) {
    if (wire.isEmpty) {
      return LogootPosition.empty;
    }
    final List<LogootAtom> atoms = <LogootAtom>[];
    for (final String segment in wire.split('.')) {
      final int colon = segment.indexOf(':');
      if (colon <= 0) {
        throw FormatException('Invalid Logoot atom: $segment');
      }
      final int? digit = int.tryParse(segment.substring(0, colon));
      final String siteId = segment.substring(colon + 1);
      if (digit == null || siteId.isEmpty) {
        throw FormatException('Invalid Logoot atom: $segment');
      }
      atoms.add(LogootAtom(digit, siteId));
    }
    return LogootPosition(atoms);
  }

  @override
  bool operator ==(Object other) {
    if (other is! LogootPosition) {
      return false;
    }
    if (other.atoms.length != atoms.length) {
      return false;
    }
    for (int i = 0; i < atoms.length; i++) {
      if (atoms[i] != other.atoms[i]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(atoms);

  @override
  String toString() => toWire();
}

/// Single character inside a [SyncText].
@immutable
class LogootCharacter {
  /// Creates an immutable character.
  const LogootCharacter({required this.value, required this.position});

  /// The character's payload — typically a single Unicode grapheme.
  final String value;

  /// Position identifier giving this character its place in the document.
  final LogootPosition position;

  @override
  bool operator ==(Object other) =>
      other is LogootCharacter &&
      other.value == value &&
      other.position == position;

  @override
  int get hashCode => Object.hash(value, position);

  @override
  String toString() => 'LogootCharacter($value @ $position)';
}

/// Logoot-based collaborative-text Conflict-free Replicated Data Type.
///
/// [SyncText] maintains a list of [LogootCharacter]s ordered by their
/// position identifiers. Inserts and deletes are reified as
/// position-stamped operations so that two replicas applying the same set
/// of operations in any order converge to the same value.
///
/// The implementation is a minimal but correct variant of the Logoot
/// algorithm from Weiss et al. (2009). The base used for digit generation
/// is `1 << 16`, which keeps position lengths reasonable while still
/// providing dense ordering even after long edit histories.
class SyncText {
  /// Creates a text from an optional initial set of [characters] (which
  /// must already be sorted by position).
  SyncText({
    List<LogootCharacter>? characters,
    String? siteId,
    math.Random? rng,
  })  : _characters = List<LogootCharacter>.of(characters ?? <LogootCharacter>[]),
        _siteId = siteId ?? 'anon',
        _rng = rng ?? math.Random();

  final List<LogootCharacter> _characters;
  final String _siteId;
  final math.Random _rng;

  /// Base used to generate digits between two positions.
  static const int base = 1 << 16;

  /// Returns the rendered text value.
  String get value =>
      _characters.map((LogootCharacter c) => c.value).join();

  /// Number of characters in the document.
  int get length => _characters.length;

  /// `true` when the document contains no characters.
  bool get isEmpty => _characters.isEmpty;

  /// Returns the immutable list of characters.
  List<LogootCharacter> get characters =>
      List<LogootCharacter>.unmodifiable(_characters);

  /// Inserts [text] at logical [index], generating fresh positions for
  /// each character.
  void insert(int index, String text) {
    if (text.isEmpty) {
      return;
    }
    if (index < 0 || index > _characters.length) {
      throw RangeError.range(index, 0, _characters.length, 'index');
    }
    final LogootPosition before = index == 0
        ? LogootPosition.empty
        : _characters[index - 1].position;
    final LogootPosition after = index == _characters.length
        ? LogootPosition.empty
        : _characters[index].position;
    LogootPosition cursor = before;
    int offset = 0;
    for (int i = 0; i < text.length; i++) {
      final LogootPosition newPos = _generateBetween(
        cursor,
        after.isEmpty || i < text.length - 1 ? LogootPosition.empty : after,
      );
      _characters.insert(
        index + offset,
        LogootCharacter(value: text[i], position: newPos),
      );
      cursor = newPos;
      offset += 1;
    }
  }

  /// Deletes the characters in the half-open range `[start, end)`.
  void delete(int start, int end) {
    if (start < 0 || end > _characters.length || start > end) {
      throw RangeError.range(start, 0, _characters.length, 'start');
    }
    _characters.removeRange(start, end);
  }

  /// Returns the merge of this document with [other].
  ///
  /// Characters are deduplicated by position so that the merge is
  /// idempotent. The returned document is independent of both inputs.
  SyncText merge(SyncText other) {
    final Map<String, LogootCharacter> byPos = <String, LogootCharacter>{};
    for (final LogootCharacter c in _characters) {
      byPos[c.position.toWire()] = c;
    }
    for (final LogootCharacter c in other._characters) {
      byPos[c.position.toWire()] = c;
    }
    final List<LogootCharacter> merged = byPos.values.toList();
    merged.sort(
      (LogootCharacter a, LogootCharacter b) =>
          a.position.compareTo(b.position),
    );
    return SyncText(
      characters: merged,
      siteId: _siteId,
      rng: _rng,
    );
  }

  /// Generates a fresh position strictly between [p1] and [p2].
  ///
  /// When [p2] is empty, the generated position is strictly greater than
  /// [p1] and unbounded above. Throws [StateError] when the input pair is
  /// in an unsupported degenerate configuration.
  LogootPosition _generateBetween(LogootPosition p1, LogootPosition p2) {
    final List<LogootAtom> result = <LogootAtom>[];
    bool useUpper = !p2.isEmpty;
    int i = 0;
    while (true) {
      final int d1 = i < p1.atoms.length ? p1.atoms[i].digit : 0;
      final int d2 =
          (useUpper && i < p2.atoms.length) ? p2.atoms[i].digit : base;
      if (d2 - d1 > 1) {
        final int digit = d1 + 1 + _rng.nextInt(d2 - d1 - 1);
        result.add(LogootAtom(digit, _siteId));
        return LogootPosition(result);
      }
      if (d1 == d2) {
        if (i < p1.atoms.length &&
            useUpper &&
            i < p2.atoms.length &&
            p1.atoms[i].siteId == p2.atoms[i].siteId) {
          result.add(p1.atoms[i]);
          i += 1;
          continue;
        }
        if (i < p1.atoms.length &&
            useUpper &&
            i < p2.atoms.length &&
            p1.atoms[i].siteId.compareTo(p2.atoms[i].siteId) < 0) {
          result.add(p1.atoms[i]);
          useUpper = false;
          i += 1;
          continue;
        }
        if (i < p1.atoms.length) {
          result.add(p1.atoms[i]);
          i += 1;
          continue;
        }
        result.add(LogootAtom(d1, _siteId));
        i += 1;
        continue;
      }
      if (i < p1.atoms.length) {
        result.add(p1.atoms[i]);
      } else {
        result.add(LogootAtom(d1, _siteId));
      }
      useUpper = false;
      i += 1;
    }
  }

  /// Serializes the text to a JSON-compatible map.
  Map<String, Object?> toJson() => <String, Object?>{
        'type': 'sync_text',
        'site_id': _siteId,
        'characters': <Map<String, Object?>>[
          for (final LogootCharacter c in _characters)
            <String, Object?>{
              'value': c.value,
              'position': c.position.toWire(),
            },
        ],
      };

  /// Reconstructs a text from a JSON-compatible map.
  factory SyncText.fromJson(
    Map<String, Object?> json, {
    math.Random? rng,
  }) {
    final List<Object?> raw = json['characters']! as List<Object?>;
    final List<LogootCharacter> chars = <LogootCharacter>[
      for (final Object? rawChar in raw)
        LogootCharacter(
          value: (rawChar! as Map<Object?, Object?>)['value']! as String,
          position: LogootPosition.parse(
            (rawChar as Map<Object?, Object?>)['position']! as String,
          ),
        ),
    ];
    chars.sort(
      (LogootCharacter a, LogootCharacter b) =>
          a.position.compareTo(b.position),
    );
    return SyncText(
      characters: chars,
      siteId: json['site_id'] as String? ?? 'anon',
      rng: rng,
    );
  }

  @override
  String toString() => 'SyncText(length: $length)';
}
