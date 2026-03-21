import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/widgets/auction_command_app_bar.dart';
import '../../../bids/data/datasources/bids_firestore_data_source.dart';
import '../../../bids/data/repositories/bids_repository_impl.dart';
import '../../../bids/domain/repositories/bids_repository.dart';
import '../../../bids/presentation/screens/recent_bids_history_screen.dart';
import '../../../match_schedule/data/datasources/match_schedule_firestore_data_source.dart';
import '../../../match_schedule/data/repositories/match_schedule_repository_impl.dart';
import '../../../match_schedule/domain/repositories/match_schedule_repository.dart';
import '../../../teams/data/datasources/teams_firestore_data_source.dart';
import '../../../teams/data/repositories/team_repository_impl.dart';
import '../../../teams/domain/entities/team.dart';
import '../../../teams/domain/repositories/team_repository.dart';
import '../../../users/data/datasources/users_firestore_data_source.dart';

/// Leaderboard for one tournament (default **CGI**). Top three featured, full list below. Sorted by balance.
class AuctionLeaderboardScreen extends StatefulWidget {
  const AuctionLeaderboardScreen({
    super.key,
    this.teamRepository,
    this.matchScheduleRepository,
    this.bidsRepository,
    this.tournament = _kLeaderboardTournament,
  });

  static const String _kLeaderboardTournament = 'CGI';

  final TeamRepository? teamRepository;
  final MatchScheduleRepository? matchScheduleRepository;
  final BidsRepository? bidsRepository;

  /// Firestore `tournament` field (registration uses `CGI`).
  final String tournament;

  @override
  State<AuctionLeaderboardScreen> createState() => _AuctionLeaderboardScreenState();
}

class _AuctionLeaderboardScreenState extends State<AuctionLeaderboardScreen> {
  late final TeamRepository _teamRepo;
  late final MatchScheduleRepository _matchRepo;
  late final BidsRepository _bidsRepo;
  late final Stream<List<Team>> _teamsStream;
  late final UsersFirestoreDataSource _usersDs;

  @override
  void initState() {
    super.initState();
    _teamRepo = widget.teamRepository ?? TeamRepositoryImpl(TeamsFirestoreDataSource());
    _matchRepo = widget.matchScheduleRepository ??
        MatchScheduleRepositoryImpl(MatchScheduleFirestoreDataSource());
    _bidsRepo = widget.bidsRepository ?? BidsRepositoryImpl(BidsFirestoreDataSource());
    _usersDs = UsersFirestoreDataSource();
    _teamsStream = _teamRepo.watchTeams(tournament: widget.tournament);
  }

  void _openTeamBids(BuildContext context, Team team) {
    final id = team.documentId.trim();
    if (id.isEmpty) return;
    final name = team.name?.trim();
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => RecentBidsHistoryScreen(
          teamDocumentId: id,
          bidsRepository: _bidsRepo,
          matchScheduleRepository: _matchRepo,
          appBarTitle: (name != null && name.isNotEmpty) ? name.toUpperCase() : 'BIDS',
        ),
      ),
    );
  }

  static List<Team> _sortedByPoints(List<Team> teams) {
    final copy = List<Team>.from(teams);
    copy.sort((a, b) {
      final ba = (a.balance ?? 0).toDouble();
      final bb = (b.balance ?? 0).toDouble();
      final c = bb.compareTo(ba);
      if (c != 0) return c;
      return (a.name ?? '').toLowerCase().compareTo((b.name ?? '').toLowerCase());
    });
    return copy;
  }

  static String _formatPoints(num? n) {
    final v = (n ?? 0).round();
    final s = v.abs().toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    if (v < 0) return '-$buf';
    return buf.toString();
  }

  static String _rankLabel(int oneBased) => oneBased.toString().padLeft(2, '0');

  static String _seasonBanner(List<Team> teams, String tournament) {
    final t = tournament.trim();
    final prefix = t.isEmpty ? '' : '$t • ';
    final seasons = teams.map((e) => e.season).whereType<int>().toList();
    if (seasons.isEmpty) return '${prefix}LIVE STANDINGS';
    final m = seasons.reduce((a, b) => a > b ? a : b);
    return '${prefix}SEASON $m • LIVE STANDINGS';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E12),
      appBar: const AuctionCommandAppBar(
        title: 'LEADERBOARD',
        backgroundColor: Colors.transparent,
        accentColor: AppColors.neonGreen,
      ),
      body: StreamBuilder<List<Team>>(
        stream: _teamsStream,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load standings.\n${snap.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator(color: AppColors.neonGreen));
          }

          final teams = _sortedByPoints(snap.data!);

          return StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, authSnap) {
              final uid = authSnap.data?.uid;
              if (uid == null) {
                return _scrollBody(context, teams, myTeamDocumentId: null);
              }
              return StreamBuilder<UserTeamPointers>(
                stream: _usersDs.watchTeamPointersForUid(uid),
                builder: (context, ptrSnap) {
                  final myDoc = ptrSnap.data?.teamDocumentId?.trim();
                  final myId = (myDoc != null && myDoc.isNotEmpty) ? myDoc : null;
                  return _scrollBody(context, teams, myTeamDocumentId: myId);
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _scrollBody(
    BuildContext context,
    List<Team> teams, {
    required String? myTeamDocumentId,
  }) {
    final myIndex = myTeamDocumentId == null
        ? -1
        : teams.indexWhere((t) => t.documentId == myTeamDocumentId);
    final myTeam = myIndex >= 0 ? teams[myIndex] : null;
    final myRank = myIndex >= 0 ? myIndex + 1 : null;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            _buildGlobalRankingHeader(
              seasonBanner: _seasonBanner(teams, widget.tournament),
              totalTeams: teams.length,
              myRank: myRank,
              myPoints: myTeam?.balance,
            ),
            const SizedBox(height: 20),
            if (teams.isNotEmpty) ...[
              _buildTopTeamCard(context, teams.first),
              const SizedBox(height: 10),
              if (teams.length > 1)
                _buildRunnerUp(
                  context,
                  teams[1],
                  points: '${_formatPoints(teams[1].balance)} PTS',
                ),
              if (teams.length > 2)
                _buildRunnerUp(
                  context,
                  teams[2],
                  points: '${_formatPoints(teams[2].balance)} PTS',
                ),
              const SizedBox(height: 20),
            ],
            _buildListHeader(),
            if (teams.length <= 3)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  teams.isEmpty ? 'No teams yet.' : 'Full standings show ranks 4+ when more teams join.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 13),
                ),
              )
            else
              ...teams.skip(3).map((t) {
                final idx = teams.indexOf(t);
                final rank = _rankLabel(idx + 1);
                final isUser = myTeamDocumentId != null && t.documentId == myTeamDocumentId;
                return _buildLeaderboardItem(
                  context,
                  team: t,
                  rank: rank,
                  points: _formatPoints(t.balance),
                  isUser: isUser,
                  matchesPlayed: t.matchesPlayed ?? 0,
                  matchesWon: t.matchesWon ?? 0,
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildGlobalRankingHeader({
    required String seasonBanner,
    required int totalTeams,
    required int? myRank,
    required num? myPoints,
  }) {
    final positionLine = myRank == null
        ? '— / —'
        : '#${_rankLabel(myRank)} / ${_formatPoints(myPoints)}';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            seasonBanner,
            style: const TextStyle(color: AppColors.neonGreen, fontSize: 10, letterSpacing: 0.5),
          ),
          const Text(
            'GLOBAL\nRANKINGS',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              fontStyle: FontStyle.italic,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              const Icon(Icons.emoji_events, color: AppColors.neonGreen, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'YOUR CURRENT POSITION',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 10),
                    ),
                    Text(
                      '$positionLine${myRank != null ? ' PTS' : ''}',
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    if (totalTeams > 0)
                      Text(
                        '$totalTeams teams',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 11),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopTeamCard(BuildContext context, Team team) {
    return Material(
      color: const Color(0xFF1C1F26),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openTeamBids(context, team),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.yellow, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.shield, color: Colors.blue, size: 40),
              ),
              const SizedBox(height: 10),
              const Icon(Icons.emoji_events, color: Colors.amber, size: 30),
              Text(
                (team.name ?? 'TOP TEAM').toUpperCase(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  fontStyle: FontStyle.italic,
                ),
              ),
              Text(
                '${_formatPoints(team.balance)} PTS',
                style: const TextStyle(color: Colors.amber, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.yellow.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'LEADER',
                  style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRunnerUp(BuildContext context, Team team, {required String points}) {
    final name = team.name ?? '—';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openTeamBids(context, team),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            child: Column(
              children: [
                const Icon(Icons.emoji_events_outlined, color: Colors.white38, size: 20),
                Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                Text(points, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeaderboardItem(
    BuildContext context, {
    required Team team,
    required String rank,
    required String points,
    bool isUser = false,
    int matchesPlayed = 0,
    int matchesWon = 0,
  }) {
    final teamLabel = team.name ?? '—';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: isUser ? const Color(0xFF232931) : const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _openTeamBids(context, team),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: isUser ? Border.all(color: AppColors.neonGreen.withValues(alpha: 0.5)) : null,
            ),
            child: Row(
              children: [
                Text(
                  rank,
                  style: TextStyle(
                    color: isUser ? AppColors.neonGreen : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 15),
                const CircleAvatar(radius: 15, backgroundColor: Colors.white10),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              teamLabel,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isUser) ...[
                            const SizedBox(width: 5),
                            _buildSmallTag('YOU', AppColors.neonGreen),
                          ],
                        ],
                      ),
                      Text(
                        '$matchesPlayed MATCHES • $matchesWon WINS',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(points, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    const Text('POINTS', style: TextStyle(color: Colors.white38, fontSize: 10)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSmallTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildListHeader() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Full Leaderboard',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Row(
            children: [
              Text(
                'BY POINTS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  decoration: TextDecoration.underline,
                ),
              ),
              SizedBox(width: 10),
              Text('BY BIDS', style: TextStyle(color: Colors.white38, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}
