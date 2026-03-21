import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_snack_bars.dart';
import '../../../../app/widgets/auction_command_app_bar.dart';
import '../../../../app/widgets/custom_nav_bar.dart';
import '../../../bids/data/datasources/bids_firestore_data_source.dart';
import '../../../bids/data/repositories/bids_repository_impl.dart';
import '../../../bids/domain/entities/existing_match_bid.dart';
import '../../../bids/presentation/match_bid_labels.dart';
import '../../../bids/domain/entities/recent_bid.dart';
import '../../../bids/domain/repositories/bids_repository.dart';
import '../../../bids/presentation/screens/recent_bids_history_screen.dart';
import '../../../match_schedule/domain/entities/match.dart';
import '../../../match_schedule/domain/repositories/match_schedule_repository.dart';
import '../../../leaderboard/presentation/screens/auction_leaderboard_screen.dart';
import '../../../match_schedule/presentation/screens/match_schedule_screen.dart';
import '../../../match_schedule/presentation/screens/place_bid_screen.dart';
import '../../../teams/data/datasources/teams_firestore_data_source.dart';
import '../../../teams/data/repositories/team_repository_impl.dart';
import '../../../teams/domain/entities/team.dart';
import '../../../teams/domain/repositories/team_repository.dart';
import '../../../users/data/datasources/users_firestore_data_source.dart';
import '../theme/auction_dashboard_colors.dart';
import '../widgets/auction_upcoming_match_card.dart';
import '../widgets/dashboard_recent_bids_section.dart';

class AuctionDashboardScreen extends StatefulWidget {
  const AuctionDashboardScreen({
    super.key,
    required this.matchScheduleRepository,
    this.teamRepository,
    this.onNavigateToTab,
  });

  final MatchScheduleRepository matchScheduleRepository;
  final TeamRepository? teamRepository;

  /// When set (main shell), switches bottom tab instead of pushing routes.
  final ValueChanged<int>? onNavigateToTab;

  @override
  State<AuctionDashboardScreen> createState() => _AuctionDashboardScreenState();
}

class _AuctionDashboardScreenState extends State<AuctionDashboardScreen> {
  late final TeamRepository _teamRepo;
  late final UsersFirestoreDataSource _usersDs;
  late final BidsRepository _bidsRepo;

  @override
  void initState() {
    super.initState();
    _teamRepo = widget.teamRepository ?? TeamRepositoryImpl(TeamsFirestoreDataSource());
    _usersDs = UsersFirestoreDataSource();
    _bidsRepo = BidsRepositoryImpl(BidsFirestoreDataSource());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuctionDashboardColors.background,
      appBar: AuctionCommandAppBar(
        accentColor: AuctionDashboardColors.accentGreen,
        backgroundColor: Colors.transparent,
      ),
      body: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, authSnap) {
          final user = authSnap.data;

          if (user == null) {
            return const Center(
              child: Text('Sign in to view your dashboard', style: TextStyle(color: Colors.white70)),
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
                  final team = teamSnap.data;
                  final teamLoading = hasTeam && teamSnap.connectionState == ConnectionState.waiting;

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildWelcomeCard(team?.name, teamLoading),
                        const SizedBox(height: 16),
                        _buildStatCard(team, teamLoading),
                        const SizedBox(height: 16),
                        _buildRankCard(context, team, teamLoading),
                        const SizedBox(height: 16),
                        _buildWalletCard(team, teamLoading),
                        const SizedBox(height: 24),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D0D1B),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: _buildRecentBidsSection(context, team, hasTeam),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Upcoming Matches',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextButton(
                              onPressed: () => _openSchedule(context),
                              child: const Text(
                                'Full schedule',
                                style: TextStyle(color: AuctionDashboardColors.accentGreen, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildUpcomingMatchesSection(team?.documentId),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  void _openSchedule(BuildContext context) {
    if (widget.onNavigateToTab != null) {
      widget.onNavigateToTab!(MainTab.schedule);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MatchScheduleScreen(
              repository: widget.matchScheduleRepository,
              teamRepository: _teamRepo,
              bidsRepository: _bidsRepo,
            ),
      ),
    );
  }

  void _openLeaderboard(BuildContext context) {
    if (widget.onNavigateToTab != null) {
      widget.onNavigateToTab!(MainTab.leaderboard);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AuctionLeaderboardScreen(
              teamRepository: _teamRepo,
              matchScheduleRepository: widget.matchScheduleRepository,
              bidsRepository: _bidsRepo,
            ),
      ),
    );
  }

  Widget _buildRecentBidsSection(BuildContext context, Team? team, bool hasTeam) {
    final teamDoc = team?.documentId.trim() ?? '';
    if (!hasTeam || teamDoc.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Bids',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: null,
                child: Text(
                  'FULL HISTORY',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Link a team to your profile to see bids.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
          ),
        ],
      );
    }

    return StreamBuilder<List<Match>>(
      stream: widget.matchScheduleRepository.watchMatches(),
      builder: (context, matchSnap) {
        if (matchSnap.hasError) {
          return Text(
            'Could not load matches',
            style: TextStyle(color: Colors.red.shade300, fontSize: 13),
          );
        }
        final matches = matchSnap.data ?? [];
        final byId = {for (final m in matches) m.documentId: m};

        return StreamBuilder<List<RecentBid>>(
          stream: _bidsRepo.watchBidsForTeam(teamDocumentId: teamDoc, limit: 3),
          builder: (context, bidSnap) {
            final loading = bidSnap.connectionState == ConnectionState.waiting && !bidSnap.hasData;
            final bids = bidSnap.data ?? [];

            return DashboardRecentBidsSection(
              bids: bids,
              matchById: byId,
              loading: loading,
              onViewAll: () {
                if (widget.onNavigateToTab != null) {
                  widget.onNavigateToTab!(MainTab.history);
                  return;
                }
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => RecentBidsHistoryScreen(
                      teamDocumentId: teamDoc,
                      bidsRepository: _bidsRepo,
                      matchScheduleRepository: widget.matchScheduleRepository,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildWelcomeCard(String? teamName, bool loading) {
    final name = loading ? '…' : (teamName?.trim().isNotEmpty == true ? teamName! : 'Your team');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AuctionDashboardColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome,\n$name',
            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, height: 1.15),
          ),
          const SizedBox(height: 8),
          const Text(
            'SEASON 2026 • PRO LEAGUE\nDIVISION',
            style: TextStyle(
              color: AuctionDashboardColors.accentGreen,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(Team? team, bool loading) {
    final balance = team?.balance;
    final prev = team?.previousBalance;
    String valueStr;
    String sub;
    if (loading) {
      valueStr = '…';
      sub = 'Loading…';
    } else if (balance == null) {
      valueStr = '—';
      sub = 'Link a team to track points';
    } else {
      final pts = balance.round();
      valueStr = _formatThousands(pts);
      if (prev != null) {
        final delta = balance - prev;
        final pct = prev != 0 ? (delta / prev * 100) : 0.0;
        sub = delta >= 0
            ? '+${pct.abs().toStringAsFixed(0)}% from last snapshot'
            : '${pct.toStringAsFixed(0)}% from last snapshot';
      } else {
        sub = 'Team balance (season)';
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AuctionDashboardColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('CURRENT POINTS', style: TextStyle(color: Colors.grey, fontSize: 12)),
              Icon(Icons.trending_up, color: AuctionDashboardColors.accentGreen, size: 18),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            valueStr,
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
          ),
          Text(sub, style: TextStyle(color: AuctionDashboardColors.accentGreen, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildRankCard(BuildContext context, Team? team, bool loading) {
    String rankStr;
    String blurb;
    if (loading) {
      rankStr = '…';
      blurb = 'Loading…';
    } else {
      final r = team?.rank;
      rankStr = r != null ? '#${r.toString().padLeft(2, '0')}' : '—';
      blurb = r != null && r <= 10 ? 'Top tier leaderboard' : 'Keep climbing the board';
    }

    return Material(
      color: AuctionDashboardColors.card,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openLeaderboard(context),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            border: Border(
              left: BorderSide(color: AuctionDashboardColors.accentGold, width: 4),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('LEADERBOARD RANK', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(
                      rankStr,
                      style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      blurb,
                      style: const TextStyle(color: AuctionDashboardColors.accentGold, fontSize: 10),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.emoji_events, color: AuctionDashboardColors.accentGold, size: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWalletCard(Team? team, bool loading) {
    final balance = team?.balance?.toDouble();
    double progress;
    String utilLabel;
    String balStr;

    if (loading) {
      balStr = '…';
      progress = 0;
      utilLabel = 'Loading wallet…';
    } else if (balance == null) {
      balStr = '—';
      progress = 0;
      utilLabel = 'No balance data';
    } else {
      balStr = '₹ ${balance.toStringAsFixed(1)}';
      const cap = 100000.0;
      progress = (balance / cap).clamp(0.0, 1.0);
      utilLabel = 'UTILIZATION: ${(progress * 100).round()}% OF REF. BUDGET (₹${_formatThousands(cap.round())})';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AuctionDashboardColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('WALLET BALANCE', style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 8),
          Text(
            balStr,
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: const Color(0xFF2A2A2A),
              valueColor: const AlwaysStoppedAnimation<Color>(AuctionDashboardColors.accentGreen),
            ),
          ),
          const SizedBox(height: 8),
          Text(utilLabel, style: const TextStyle(color: Colors.grey, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildUpcomingMatchesSection(String? teamDocumentId) {
    final teamDoc = teamDocumentId?.trim() ?? '';

    return StreamBuilder<List<Match>>(
      stream: widget.matchScheduleRepository.watchMatches(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text(
            'Could not load matches',
            style: TextStyle(color: Colors.red.shade300),
          );
        }
        if (!snapshot.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(color: AuctionDashboardColors.accentGreen),
            ),
          );
        }
        final all = snapshot.data!;
        final upcoming = _upcomingMatches(all);
        if (upcoming.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AuctionDashboardColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: const Text(
              'No upcoming matches right now.',
              style: TextStyle(color: Colors.white54),
            ),
          );
        }
        return Column(
          children: [
            for (var i = 0; i < upcoming.length && i < 3; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              _buildUpcomingMatchCardWithBid(context, upcoming[i], teamDoc),
            ],
          ],
        );
      },
    );
  }

  Widget _buildUpcomingMatchCardWithBid(BuildContext context, Match match, String teamDoc) {
    if (teamDoc.isEmpty) {
      return AuctionUpcomingMatchCard(
        match: match,
        myBid: null,
        onEnterAuction: () {
          if (isMatchScheduleLocked(match)) return;
          if (isMatchBiddingCutoffReached(match)) {
            ScaffoldMessenger.of(context).showSnackBar(
              AppSnackBars.warning('Bidding closes 30 minutes before match start.'),
            );
            return;
          }
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => PlaceBidScreen(match: match),
            ),
          );
        },
      );
    }

    return StreamBuilder<ExistingMatchBid?>(
      stream: _bidsRepo.watchMyBidForMatch(
        matchDocumentId: match.documentId,
        bidderTeamDocumentId: teamDoc,
      ),
      builder: (context, bidSnap) {
        final myBid = bidSnap.data;
        return AuctionUpcomingMatchCard(
          match: match,
          myBid: myBid,
          onEnterAuction: () {
            if (myBid != null) return;
            if (isMatchScheduleLocked(match)) return;
            if (isMatchBiddingCutoffReached(match)) {
              ScaffoldMessenger.of(context).showSnackBar(
                AppSnackBars.warning('Bidding closes 30 minutes before match start.'),
              );
              return;
            }
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => PlaceBidScreen(match: match),
              ),
            );
          },
        );
      },
    );
  }

  static List<Match> _upcomingMatches(List<Match> matches) {
    final now = DateTime.now();
    final sorted = List<Match>.from(matches);
    sorted.sort((a, b) {
      final da = a.matchDate;
      final db = b.matchDate;
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return da.compareTo(db);
    });
    return sorted.where((m) {
      final d = m.matchDate;
      if (d == null) return true;
      return !d.isBefore(DateTime(now.year, now.month, now.day));
    }).toList();
  }

  static String _formatThousands(int n) {
    final s = n.abs().toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final fromEnd = s.length - i;
      if (i > 0 && fromEnd % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return n < 0 ? '-$buf' : buf.toString();
  }
}
