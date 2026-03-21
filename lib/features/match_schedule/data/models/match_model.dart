import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/match.dart';

class MatchModel {
  const MatchModel({
    required this.documentId,
    this.tournament,
    this.season,
    this.matchId,
    this.matchNo,
    this.matchDate,
    this.venue,
    this.team1,
    this.team1Id,
    this.team2,
    this.team2Id,
    this.status,
    this.bidEndTime,
    this.bidRange,
    this.result,
    this.toss,
    this.odds,
  });

  final String documentId;
  final String? tournament;
  final int? season;
  final String? matchId;
  final String? matchNo;
  final DateTime? matchDate;
  final String? venue;
  final String? team1;
  final String? team1Id;
  final String? team2;
  final String? team2Id;
  final String? status;
  final DateTime? bidEndTime;
  final List<double>? bidRange;
  final String? result;
  final String? toss;
  final List<double>? odds;

  factory MatchModel.fromFirestore(Map<String, dynamic> raw, String documentId) {
    final m = raw;

    final matchDate = _parseDateTimeNullable(_firstOf(m, _matchDateKeys));
    final bidEndRaw = _firstOf(m, _bidEndKeys);
    final bidEndParsed = _parseDateTimeNullable(bidEndRaw);
    final bidEndTime = bidEndParsed ?? matchDate;

    return MatchModel(
      documentId: documentId,
      tournament: _strNullable(m, ['tournament']),
      season: _parseIntNullable(_firstOf(m, ['season'])),
      matchId: _strNullable(m, ['match_id', 'matchId']),
      matchNo: _strNullable(m, ['match_no', 'matchNo']),
      matchDate: matchDate,
      venue: _strNullable(m, ['venue']),
      team1: _strNullable(m, ['team_1', 'team1']),
      team1Id: _strNullable(m, ['team_1_id', 'team1Id']),
      team2: _strNullable(m, ['team_2', 'team2']),
      team2Id: _strNullable(m, ['team_2_id', 'team2Id']),
      status: _strNullable(m, ['status']),
      bidEndTime: bidEndTime,
      bidRange: _parseBidRangeNullable(_firstOf(m, ['bid_range', 'bidRange'])),
      result: _strNullable(m, ['result']),
      toss: _strNullable(m, ['toss']),
      odds: _parseOddsList(_firstOf(m, ['odds'])),
    );
  }

  Match toEntity() => Match(
        documentId: documentId,
        tournament: tournament,
        season: season,
        matchId: matchId,
        matchNo: matchNo,
        matchDate: matchDate,
        venue: venue,
        team1: team1,
        team1Id: team1Id,
        team2: team2,
        team2Id: team2Id,
        status: status,
        bidEndTime: bidEndTime,
        bidRange: bidRange,
        result: result,
        toss: toss,
        odds: odds,
      );
}

/// Keys tried in order for the match start (same Firestore doc may use different names).
const _matchDateKeys = [
  'match_date_time', // common in Firestore (snake_case)
  'match_date',
  'matchDate',
  'matchDateTime',
  'date',
  'start_time',
  'startTime',
  'datetime',
];

const _bidEndKeys = [
  'bid_end_time',
  'bidEndTime',
  'bid_end',
  'bidEnd',
];

dynamic _firstOf(Map<String, dynamic> m, List<String> keys) {
  for (final k in keys) {
    if (m.containsKey(k) && m[k] != null) return m[k];
  }
  return null;
}

/// Null if missing or blank.
String? _strNullable(Map<String, dynamic> m, List<String> keys) {
  final v = _firstOf(m, keys);
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

/// Accepts [Timestamp], [DateTime], epoch [int]/[double] (seconds if &lt; 1e10 else ms),
/// Firestore-style maps `seconds`/`nanoseconds`, and ISO-like strings (incl. `+05:30`, `+0530`).
DateTime? _parseDateTimeNullable(dynamic v) {
  if (v == null) return null;
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;

  if (v is Map) {
    final fromMap = _parseFirestoreTimestampMap(v);
    if (fromMap != null) return fromMap;
  }

  if (v is int) return _epochIntToDateTime(v);
  if (v is double) {
    if (v.isNaN || v.isInfinite) return null;
    return _epochIntToDateTime(v.round());
  }

  if (v is String) {
    return _parseDateTimeString(v);
  }

  final asString = v.toString().trim();
  if (asString.isEmpty) return null;
  if (RegExp(r'^-?\d+(\.\d+)?$').hasMatch(asString)) {
    final n = double.tryParse(asString);
    if (n != null && !n.isNaN) {
      return _epochIntToDateTime(n.round());
    }
  }
  return _parseDateTimeString(asString);
}

DateTime? _parseFirestoreTimestampMap(Map<dynamic, dynamic> m) {
  final sec = m['seconds'] ?? m['_seconds'];
  if (sec == null) return null;
  final s = sec is num ? sec.toInt() : int.tryParse(sec.toString());
  if (s == null) return null;
  final nsRaw = m['nanoseconds'] ?? m['_nanoseconds'];
  final ns = nsRaw is num ? nsRaw.toInt() : (int.tryParse(nsRaw?.toString() ?? '') ?? 0);
  return DateTime.fromMillisecondsSinceEpoch(s * 1000 + ns ~/ 1000000, isUtc: true).toLocal();
}

/// Unix **seconds** are typically ≤10 digits; **milliseconds** since 2001 are ≥13 digits.
DateTime? _epochIntToDateTime(int v) {
  const maxUnixSeconds = 10000000000; // 10^10 — above this, treat as ms
  if (v.abs() < maxUnixSeconds) {
    return DateTime.fromMillisecondsSinceEpoch(v * 1000, isUtc: true).toLocal();
  }
  return DateTime.fromMillisecondsSinceEpoch(v, isUtc: true).toLocal();
}

String _normalizeDateString(String input) {
  var s = input.trim();
  if (s.isEmpty) return s;
  // Strip BOM / quotes from copy-paste or JSON
  if (s.startsWith('\uFEFF')) s = s.substring(1);
  if ((s.startsWith('"') && s.endsWith('"')) || (s.startsWith("'") && s.endsWith("'"))) {
    s = s.substring(1, s.length - 1).trim();
  }
  return s;
}

/// `+0530` / `-0330` (no colon) → `+05:30` for Dart's ISO parser.
String _insertColonInNumericOffset(String s) {
  return s.replaceFirstMapped(
    RegExp(r'([+-])(\d{2})(\d{2})$'),
    (m) => '${m[1]}${m[2]}:${m[3]}',
  );
}

DateTime? _parseDateTimeString(String raw) {
  var t = _normalizeDateString(raw);
  if (t.isEmpty) return null;

  DateTime? tryParseChain(String s) {
    var p = DateTime.tryParse(s);
    if (p != null) return p;
    // Space between date and time: "2026-03-29 19:00:00+05:30"
    if (RegExp(r'^\d{4}-\d{2}-\d{2} \d').hasMatch(s)) {
      p = DateTime.tryParse(s.replaceFirst(RegExp(r'^(\d{4}-\d{2}-\d{2}) '), r'$1T'));
      if (p != null) return p;
    }
    // Offset without colon: ...+0530
    if (RegExp(r'[+-]\d{4}$').hasMatch(s) && !RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(s)) {
      final withColon = _insertColonInNumericOffset(s);
      if (withColon != s) {
        p = DateTime.tryParse(withColon);
        if (p != null) return p;
      }
    }
    try {
      return DateTime.parse(s);
    } on FormatException {
      return null;
    }
  }

  final first = tryParseChain(t);
  if (first != null) return first;

  // Do not use naive local parsers if an explicit zone suffix is present.
  final hasExplicitZone = RegExp(r'(?:Z|[+-]\d{2}:\d{2}|[+-]\d{4})$').hasMatch(t);
  if (hasExplicitZone) return null;

  final space = RegExp(r'^(\d{4})-(\d{2})-(\d{2})(?:[ T](\d{2}):(\d{2})(?::(\d{2}))?)?$');
  final match = space.firstMatch(t);
  if (match != null) {
    final y = int.parse(match.group(1)!);
    final mo = int.parse(match.group(2)!);
    final d = int.parse(match.group(3)!);
    final hh = int.tryParse(match.group(4) ?? '') ?? 0;
    final mm = int.tryParse(match.group(5) ?? '') ?? 0;
    final ss = int.tryParse(match.group(6) ?? '') ?? 0;
    return DateTime(y, mo, d, hh, mm, ss);
  }

  final slash = RegExp(
    r'^(\d{1,2})/(\d{1,2})/(\d{4})(?:\s+(\d{1,2}):(\d{2})(?::(\d{2}))?)?$',
  );
  final sm = slash.firstMatch(t);
  if (sm != null) {
    final day = int.parse(sm.group(1)!);
    final month = int.parse(sm.group(2)!);
    final year = int.parse(sm.group(3)!);
    final hh = int.tryParse(sm.group(4) ?? '') ?? 0;
    final mm = int.tryParse(sm.group(5) ?? '') ?? 0;
    final ss = int.tryParse(sm.group(6) ?? '') ?? 0;
    if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
      return DateTime(year, month, day, hh, mm, ss);
    }
  }
  return null;
}

double? _parseDoubleNullable(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.trim());
  return null;
}

/// Odds multiplier from Firestore (must be finite and positive).
double? _parsePositiveDoubleNullable(dynamic v) {
  final d = _parseDoubleNullable(v);
  if (d == null || d.isNaN || d.isInfinite || d <= 0) return null;
  return d;
}

/// Firestore `odds`: **two** multipliers [team1/home, team2/away]. Legacy single number → `[x, x]`.
List<double>? _parseOddsList(dynamic v) {
  if (v == null) return null;
  if (v is List) {
    final out = <double>[];
    for (final e in v) {
      final d = _parsePositiveDoubleNullable(e);
      if (d != null) out.add(d);
    }
    if (out.isEmpty) return null;
    if (out.length == 1) return [out[0], out[0]];
    return [out[0], out[1]];
  }
  final single = _parsePositiveDoubleNullable(v);
  if (single != null) return [single, single];
  return null;
}

int? _parseIntNullable(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is double) return v.toInt();
  if (v is String) return int.tryParse(v.trim());
  return null;
}

List<double>? _parseBidRangeNullable(dynamic v) {
  if (v == null) return null;
  if (v is! List) return null;
  final out = <double>[];
  for (final e in v) {
    if (e == null) continue;
    if (e is num) {
      out.add(e.toDouble());
    } else if (e is String) {
      final d = double.tryParse(e.trim());
      if (d != null) out.add(d);
    }
  }
  return out.isEmpty ? null : out;
}
