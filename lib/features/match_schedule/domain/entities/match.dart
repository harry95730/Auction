/// Firestore-backed match; most fields are optional because documents may omit
/// keys or use string dates that fail to parse.
class Match {
  const Match({
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

  /// Firestore document id (always present when loaded from Firestore).
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

  /// Firestore `odds` (e.g. `2` or `5`) — decimal **payout multiplier** on the winning pick.
  final double? odds;
}
