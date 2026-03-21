import '../../domain/entities/team.dart';

class TeamModel {
  const TeamModel({
    required this.documentId,
    this.teamId,
    this.name,
    this.captain,
    this.players,
    this.logoUrl,
    this.homeGround,
    this.venue,
    this.tournament,
    this.season,
    this.owner,
    this.rank,
    this.matchesPlayed,
    this.matchesWon,
    this.matchesLost,
    this.previousBalance,
    this.balance,
    this.authUid,
  });

  final String documentId;
  final String? teamId;
  final String? name;
  final String? captain;
  final List<String>? players;
  final String? logoUrl;
  final String? homeGround;
  /// Optional home venue name (Firestore `venue`); [homeGround] is `home_ground`.
  final String? venue;
  final String? tournament;
  final int? season;
  final String? owner;
  final int? rank;
  final int? matchesPlayed;
  final int? matchesWon;
  final int? matchesLost;
  final num? previousBalance;
  final num? balance;
  final String? authUid;

  factory TeamModel.fromFirestore(Map<String, dynamic> raw, String documentId) {
    return TeamModel(
      documentId: documentId,
      teamId: _str(raw['team_id']),
      name: _str(raw['team']),
      captain: _str(raw['captain']),
      players: _parseStringList(raw['players']),
      logoUrl: _str(raw['logo'] ?? raw['logoUrl']),
      homeGround: _str(raw['home_ground']),
      venue: _str(raw['venue']),
      tournament: _str(raw['tournament']),
      season: _parseInt(raw['season']),
      owner: _str(raw['owner']),
      rank: _parseInt(raw['rank']),
      matchesPlayed: _parseInt(raw['matches_played']),
      matchesWon: _parseInt(raw['matches_won']),
      matchesLost: _parseInt(raw['matches_lost']),
      previousBalance: _parseNum(raw['previous_balance']),
      balance: _parseNum(raw['balance']),
      authUid: _str(raw['auth_uid']),
    );
  }

  Team toEntity() => Team(
        documentId: documentId,
        teamId: teamId,
        name: name,
        captain: captain,
        players: players,
        logoUrl: logoUrl,
        homeGround: homeGround,
        venue: venue,
        tournament: tournament,
        season: season,
        owner: owner,
        rank: rank,
        matchesPlayed: matchesPlayed,
        matchesWon: matchesWon,
        matchesLost: matchesLost,
        previousBalance: previousBalance,
        balance: balance,
        authUid: authUid,
      );
}

String? _str(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

int? _parseInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is double) return v.toInt();
  if (v is String) return int.tryParse(v.trim());
  return null;
}

num? _parseNum(dynamic v) {
  if (v == null) return null;
  if (v is num) return v;
  if (v is String) return num.tryParse(v.trim());
  return null;
}

List<String>? _parseStringList(dynamic v) {
  if (v is! List) return null;
  final out = <String>[];
  for (final e in v) {
    final s = e?.toString().trim() ?? '';
    if (s.isNotEmpty) out.add(s);
  }
  return out.isEmpty ? null : out;
}
