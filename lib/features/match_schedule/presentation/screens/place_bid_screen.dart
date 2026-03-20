import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/widgets/auction_command_app_bar.dart';
import '../../../bids/data/datasources/bids_firestore_data_source.dart';
import '../../../bids/data/repositories/bids_repository_impl.dart';
import '../../../bids/domain/entities/existing_match_bid.dart';
import '../../../bids/presentation/match_bid_labels.dart';
import '../../../bids/domain/entities/match_bid_tally.dart';
import '../../../bids/domain/repositories/bids_repository.dart';
import '../../../teams/data/datasources/teams_firestore_data_source.dart';
import '../../../teams/data/repositories/team_repository_impl.dart';
import '../../../teams/domain/entities/team.dart';
import '../../../teams/domain/repositories/team_repository.dart';
import '../../../users/data/datasources/users_firestore_data_source.dart';
import '../../domain/entities/match.dart';
import '../widgets/auction_bidding_panel.dart';
import '../widgets/team_logo_asset.dart';

/// Accent palette for this screen (matches the provided mockup).
abstract final class _BidUi {
  static const Color bg = Color(0xFF0A0E0F);
  static const Color accent = Color(0xFF4CAF50);
}

class PlaceBidScreen extends StatefulWidget {
  const PlaceBidScreen({super.key, required this.match, this.teamRepository});

  final Match match;
  final TeamRepository? teamRepository;

  @override
  State<PlaceBidScreen> createState() => _PlaceBidScreenState();
}

class _PlaceBidScreenState extends State<PlaceBidScreen> {
  late final TeamRepository _teamRepo;
  late final BidsRepository _bidsRepo;
  late final UsersFirestoreDataSource _usersDs;
  Team? _team1;
  Team? _team2;
  bool _loadingTeams = true;

  /// Match `status` indicates locked — close screen; bidding is disabled in panel too.
  bool _matchLockedByStatus = false;

  Match get _m => widget.match;

  static const _months = <String>[
    'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
  ];

  @override
  void initState() {
    super.initState();
    _teamRepo = widget.teamRepository ?? TeamRepositoryImpl(TeamsFirestoreDataSource());
    _bidsRepo = BidsRepositoryImpl(BidsFirestoreDataSource());
    _usersDs = UsersFirestoreDataSource();
    if (isMatchScheduleLocked(widget.match)) {
      _matchLockedByStatus = true;
      _loadingTeams = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This match is locked. Bidding is not available.')),
        );
        Navigator.of(context).pop();
      });
      return;
    }
    _loadTeams();
  }

  Future<void> _placeBid({
    required Team myTeam,
    required double amount,
    required String matchBidTeamDocumentId,
  }) {
    return _bidsRepo.placeBid(
      bidderTeamDocumentId: myTeam.documentId,
      matchDocumentId: _m.documentId,
      matchBidTeamDocumentId: matchBidTeamDocumentId,
      bidAmount: amount,
    );
  }

  Widget _buildAuctionBiddingPanel({
    required String team1Name,
    required String team2Name,
  }) {
    final m = _m;
    final doc1 = _team1?.documentId.trim() ?? '';
    final doc2 = _team2?.documentId.trim() ?? '';

    return StreamBuilder<MatchBidTally>(
      stream: _bidsRepo.watchBidTally(
        matchDocumentId: m.documentId,
        team1DocumentId: doc1,
        team2DocumentId: doc2,
      ),
      initialData: const MatchBidTally(countTeam1: 0, countTeam2: 0),
      builder: (context, tallySnap) {
        final tally = tallySnap.data ?? const MatchBidTally(countTeam1: 0, countTeam2: 0);

        return StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, authSnap) {
            final user = authSnap.data;

            Widget panel({
              required bool isAuthenticated,
              required bool hasTeam,
              required bool walletLoading,
              required double? walletBalance,
              required Future<void> Function(double amount, String matchBidTeamDocumentId)? onPlaceBid,
              ExistingMatchBid? existingBid,
              bool existingBidLoading = false,
            }) {
              final locked = existingBid != null || isMatchScheduleLocked(m);
              return AuctionBiddingPanel(
                match: m,
                team1Name: team1Name,
                team2Name: team2Name,
                team1Code: _abbr(_m.team1Id, _m.team1),
                team2Code: _abbr(_m.team2Id, _m.team2),
                team1Color: _fallbackTint1(),
                team2Color: _fallbackTint2(),
                matchTeam1DocumentId: doc1.isEmpty ? null : doc1,
                matchTeam2DocumentId: doc2.isEmpty ? null : doc2,
                walletBalance: walletBalance,
                walletLoading: walletLoading,
                bidsTeam1: tally.countTeam1,
                bidsTeam2: tally.countTeam2,
                isAuthenticated: isAuthenticated,
                hasTeam: hasTeam,
                onPlaceBid: locked ? null : onPlaceBid,
                existingBid: existingBid,
                existingBidLoading: existingBidLoading,
              );
            }

            if (user == null) {
              return panel(
                isAuthenticated: false,
                hasTeam: false,
                walletLoading: false,
                walletBalance: null,
                onPlaceBid: null,
                existingBid: null,
                existingBidLoading: false,
              );
            }

            return StreamBuilder<UserTeamPointers>(
              stream: _usersDs.watchTeamPointersForUid(user.uid),
              builder: (context, ptrSnap) {
                final ptr = ptrSnap.data;
                final hasTeam = ptr != null &&
                    ((ptr.teamDocumentId != null && ptr.teamDocumentId!.isNotEmpty) ||
                        (ptr.teamId != null && ptr.teamId!.isNotEmpty));

                final Stream<Team?> teamStream = !hasTeam
                    ? Stream<Team?>.value(null)
                    : () {
                        final p = ptr;
                        if (p.teamDocumentId != null && p.teamDocumentId!.isNotEmpty) {
                          return _teamRepo.watchByDocumentId(p.teamDocumentId!);
                        }
                        if (p.teamId != null && p.teamId!.isNotEmpty) {
                          return _teamRepo.watchByTeamId(p.teamId!);
                        }
                        return Stream<Team?>.value(null);
                      }();

                return StreamBuilder<Team?>(
                  stream: teamStream,
                  builder: (context, teamSnap) {
                    final myTeam = teamSnap.data;
                    final walletLoading =
                        hasTeam && teamSnap.connectionState == ConnectionState.waiting;
                    final bal = myTeam?.balance?.toDouble();
                    final bidderDoc = myTeam?.documentId.trim() ?? '';

                    final Stream<ExistingMatchBid?> myBidStream =
                        (hasTeam && bidderDoc.isNotEmpty)
                            ? _bidsRepo.watchMyBidForMatch(
                                matchDocumentId: m.documentId,
                                bidderTeamDocumentId: bidderDoc,
                              )
                            : Stream<ExistingMatchBid?>.value(null);

                    return StreamBuilder<ExistingMatchBid?>(
                      stream: myBidStream,
                      builder: (context, existingSnap) {
                        final pending = hasTeam &&
                            bidderDoc.isNotEmpty &&
                            existingSnap.connectionState == ConnectionState.waiting;
                        final existingBid = existingSnap.data;

                        Future<void> Function(double, String)? onPlaceBid;
                        if (!pending &&
                            existingBid == null &&
                            hasTeam &&
                            myTeam != null &&
                            myTeam.documentId.isNotEmpty) {
                          onPlaceBid = (amount, matchBidTeamDocumentId) => _placeBid(
                                myTeam: myTeam,
                                amount: amount,
                                matchBidTeamDocumentId: matchBidTeamDocumentId,
                              );
                        }

                        return panel(
                          isAuthenticated: true,
                          hasTeam: hasTeam,
                          walletLoading: walletLoading,
                          walletBalance: bal,
                          onPlaceBid: onPlaceBid,
                          existingBid: existingBid,
                          existingBidLoading: pending,
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _loadTeams() async {
    final id1 = _m.team1Id;
    final id2 = _m.team2Id;
    final f1 = (id1 != null && id1.isNotEmpty) ? _teamRepo.getByTeamId(id1) : Future<Team?>.value(null);
    final f2 = (id2 != null && id2.isNotEmpty) ? _teamRepo.getByTeamId(id2) : Future<Team?>.value(null);
    final results = await Future.wait([f1, f2]);
    if (!mounted) return;
    setState(() {
      _team1 = results[0];
      _team2 = results[1];
      _loadingTeams = false;
    });
  }

  String _abbr(String? id, String? name) {
    if (id != null && id.trim().isNotEmpty) {
      final t = id.trim().toUpperCase();
      return t.length <= 4 ? t : t.substring(0, 4);
    }
    final n = (name ?? 'TM').trim().toUpperCase().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).take(2).map((e) => e[0]).join();
    return n.isEmpty ? 'TM' : n;
  }

  String _scheduleLine() {
    final dt = _m.matchDate;
    if (dt == null) return '—';
    return '${dt.day} ${_months[dt.month - 1]} ${dt.year} • '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} IST';
  }

  String _oddsLine() {
    final o = _m.odds;
    if (o == null) return '— ODDS';
    return '${o.toStringAsFixed(2)}x ODDS';
  }

  Color _fallbackTint1() => const Color(0xFF1565C0);
  Color _fallbackTint2() => const Color(0xFFF9A825);

  @override
  Widget build(BuildContext context) {
    if (_matchLockedByStatus) {
      return Scaffold(
        backgroundColor: _BidUi.bg,
        appBar: const AuctionCommandAppBar(
          backgroundColor: Colors.transparent,
          accentColor: AppColors.neonGreen,
        ),
        body: const Center(child: CircularProgressIndicator(color: _BidUi.accent)),
      );
    }

    final t1 = _team1?.name ?? _m.team1 ?? 'TEAM 1';
    final t2 = _team2?.name ?? _m.team2 ?? 'TEAM 2';
    final venue = _m.venue ?? 'Venue TBA';

    return Scaffold(
      backgroundColor: _BidUi.bg,
      appBar: const AuctionCommandAppBar(
        backgroundColor: Colors.transparent,
        accentColor: AppColors.neonGreen,
      ),
      body: _loadingTeams
          ? const Center(child: CircularProgressIndicator(color: _BidUi.accent))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 24),
                        _buildTeamBlock(
                          team: _team1,
                          matchTeamId: _m.team1Id,
                          matchName: _m.team1 ?? 'TEAM 1',
                          logoText: _abbr(_m.team1Id, _m.team1),
                          fallbackColor: _fallbackTint1(),
                          label: 'HOME TEAM',
                          labelColor: Colors.green.shade900,
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Text(
                            'VS',
                            style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                        Text(
                          _oddsLine(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        Text(
                          (_m.status ?? '').toUpperCase().contains('LIVE') ? 'LIVE MARKET' : 'HIGH VOLATILITY MATCH',
                          style: const TextStyle(color: Colors.grey, fontSize: 10, letterSpacing: 1.2),
                        ),
                        const SizedBox(height: 20),
                        Text(venue, style: const TextStyle(color: Colors.white70, fontSize: 14), textAlign: TextAlign.center),
                        Text(_scheduleLine(), style: const TextStyle(color: Colors.white54, fontSize: 12)),
                        const SizedBox(height: 24),
                        _buildTeamBlock(
                          team: _team2,
                          matchTeamId: _m.team2Id,
                          matchName: _m.team2 ?? 'TEAM 2',
                          logoText: _abbr(_m.team2Id, _m.team2),
                          fallbackColor: _fallbackTint2(),
                          label: 'CHALLENGER',
                          labelColor: Colors.white10,
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildAuctionBiddingPanel(team1Name: t1, team2Name: t2),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildTeamBlock({
    required Team? team,
    required String? matchTeamId,
    required String matchName,
    required String logoText,
    required Color fallbackColor,
    required String label,
    required Color labelColor,
  }) {
    final name = (team?.name ?? matchName).toUpperCase();
    final assetPath = teamLogoAssetPathForMatch(
      teamId: matchTeamId,
      teamDisplayName: matchName,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: fallbackColor.withValues(alpha: assetPath == null ? 0.35 : 0.12),
              ),
              child: assetPath != null
                  ? Opacity(
                      opacity: 0.22,
                      child: Image.asset(
                        assetPath,
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                        errorBuilder: (_, _, _) => const SizedBox.expand(),
                      ),
                    )
                  : const SizedBox.expand(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
            child: Column(
              children: [
                TeamLogoAsset(
                  teamId: matchTeamId,
                  teamDisplayName: matchName,
                  size: 88,
                  borderRadius: 12,
                  fallback: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: fallbackColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      logoText.isEmpty ? '?' : logoText,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 28,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  name,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: labelColor, borderRadius: BorderRadius.circular(20)),
                  child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

}
