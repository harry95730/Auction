/// Firestore `teams` document + signup payload used by [TeamRepository.registerTeam].
///
/// [password] is only for Firebase Auth during registration and is never stored on the team document.
class Team {
  const Team({
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
    this.password,
  });

  final String documentId;
  final String? teamId;
  final String? name;
  /// Captain display name (Firestore field `captain`).
  final String? captain;
  /// Squad emails — **captain’s email first**, then other members.
  /// After registration, includes the synthetic team login email ([firebaseAuthEmailFromTeamName])
  /// so email/password sign-in with that address resolves the squad.
  final List<String>? players;
  final String? logoUrl;
  final String? homeGround;
  /// Firestore `venue` (display name); [homeGround] maps `home_ground`.
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

  final String? password;

  factory Team.signup({
    required String teamName,
    required String teamId,
    required String captainName,
    required String password,
    required String captainEmail,
    required String member2Email,
    required String member3Email,
    String? member4Email,
  }) {
    final emails = <String>[
      captainEmail.trim(),
      member2Email.trim(),
      member3Email.trim(),
      if (member4Email != null && member4Email.trim().isNotEmpty) member4Email.trim(),
    ];
    return Team(
      documentId: '',
      teamId: teamId.trim(),
      name: teamName.trim(),
      captain: captainName.trim(),
      players: emails,
      password: password,
    );
  }

  static String firebaseAuthEmailFromTeamName(String teamName) {
    var local = teamName.toLowerCase().trim().replaceAll(RegExp(r'\s+'), '');
    local = local.replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (local.isEmpty) local = 'team';
    if (local.length > 64) local = local.substring(0, 64);
    return '$local@gmail.com';
  }
}
