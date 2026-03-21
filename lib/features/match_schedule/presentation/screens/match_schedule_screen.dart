import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/widgets/auction_command_app_bar.dart';
import '../../../bids/data/datasources/bids_firestore_data_source.dart';
import '../../../bids/data/repositories/bids_repository_impl.dart';
import '../../../bids/domain/entities/existing_match_bid.dart';
import '../../../bids/domain/repositories/bids_repository.dart';
import '../../../teams/data/datasources/teams_firestore_data_source.dart';
import '../../../teams/data/repositories/team_repository_impl.dart';
import '../../../teams/domain/entities/team.dart';
import '../../../teams/domain/repositories/team_repository.dart';
import '../../../users/data/datasources/users_firestore_data_source.dart';
import '../../domain/entities/match.dart';
import '../../domain/repositories/match_schedule_repository.dart';
import '../widgets/match_card.dart';

/// Schedule tabs: all matches, today only, upcoming matches the user has not bid on.
class MatchScheduleScreen extends StatefulWidget {
  const MatchScheduleScreen({
    super.key,
    required this.repository,
    this.teamRepository,
    this.bidsRepository,
  });

  final MatchScheduleRepository repository;
  final TeamRepository? teamRepository;
  final BidsRepository? bidsRepository;

  @override
  State<MatchScheduleScreen> createState() => _MatchScheduleScreenState();
}

class _MatchScheduleScreenState extends State<MatchScheduleScreen> {
  late final TeamRepository _teamRepo;
  late final BidsRepository _bidsRepo;
  late final UsersFirestoreDataSource _usersDs;

  /// 0 = all, 1 = today, 2 = upcoming & not yet bid.
  int _scheduleTab = 0;

  @override
  void initState() {
    super.initState();
    _teamRepo = widget.teamRepository ?? TeamRepositoryImpl(TeamsFirestoreDataSource());
    _bidsRepo = widget.bidsRepository ?? BidsRepositoryImpl(BidsFirestoreDataSource());
    _usersDs = UsersFirestoreDataSource();
  }

  static List<Match> _sortedByDate(List<Match> matches) {
    final copy = List<Match>.from(matches);
    copy.sort((a, b) {
      final da = a.matchDate;
      final db = b.matchDate;
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return da.compareTo(db);
    });
    return copy;
  }

  /// Same calendar day as [now] in local time.
  static bool _isSameLocalDay(DateTime? matchDate, DateTime nowLocal) {
    if (matchDate == null) return false;
    final d = matchDate.toLocal();
    return d.year == nowLocal.year && d.month == nowLocal.month && d.day == nowLocal.day;
  }

  static List<Match> _matchesToday(List<Match> sorted, DateTime now) {
    return sorted.where((m) => _isSameLocalDay(m.matchDate, now)).toList();
  }

  /// Today or later (calendar day), or no date (TBA treated as still listed).
  static List<Match> _upcomingIncludingTba(List<Match> sorted, DateTime now) {
    final start = DateTime(now.year, now.month, now.day);
    return sorted.where((m) {
      final d = m.matchDate;
      if (d == null) return true;
      return !d.toLocal().isBefore(start);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: const AuctionCommandAppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              _buildBannerCard(),
              const SizedBox(height: 25),
              _buildFilterTabs(),
              const SizedBox(height: 20),
              Expanded(
                child: StreamBuilder<List<Match>>(
                  stream: widget.repository.watchMatches(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Could not load matches',
                          style: TextStyle(color: Colors.red.shade300),
                        ),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator(color: AppColors.neonGreen));
                    }
                    final raw = snapshot.data!;
                    final sorted = _sortedByDate(raw);
                    final now = DateTime.now();

                    List<Match> tabMatches;
                    switch (_scheduleTab) {
                      case 1:
                        tabMatches = _matchesToday(sorted, now);
                        break;
                      case 2:
                        tabMatches = _upcomingIncludingTba(sorted, now);
                        break;
                      default:
                        tabMatches = sorted;
                    }

                    return StreamBuilder<User?>(
                      stream: FirebaseAuth.instance.authStateChanges(),
                      builder: (context, authSnap) {
                        final user = authSnap.data;
                        if (user == null) {
                          return _buildMatchListForGuest(tabMatches);
                        }

                        return StreamBuilder<UserTeamPointers>(
                          stream: _usersDs.watchTeamPointersForUid(user.uid),
                          builder: (context, ptrSnap) {
                            final ptr = ptrSnap.data;
                            final hasTeam = ptr != null &&
                                ((ptr.teamDocumentId != null && ptr.teamDocumentId!.isNotEmpty) ||
                                    (ptr.teamId != null && ptr.teamId!.isNotEmpty));

                            late final Stream<Team?> teamStream;
                            if (!hasTeam) {
                              teamStream = Stream<Team?>.value(null);
                            } else {
                              final p = ptr;
                              if (p.teamDocumentId != null && p.teamDocumentId!.isNotEmpty) {
                                teamStream = _teamRepo.watchByDocumentId(p.teamDocumentId!);
                              } else if (p.teamId != null && p.teamId!.isNotEmpty) {
                                teamStream = _teamRepo.watchByTeamId(p.teamId!);
                              } else {
                                teamStream = Stream<Team?>.value(null);
                              }
                            }

                            return StreamBuilder<Team?>(
                              stream: teamStream,
                              builder: (context, teamSnap) {
                                final teamDoc = teamSnap.data?.documentId.trim() ?? '';
                                return _buildMatchList(
                                  tabMatches: tabMatches,
                                  teamDoc: teamDoc,
                                );
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMatchListForGuest(List<Match> tabMatches) {
    if (_scheduleTab == 2) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Sign in and link a team to see matches you still need to bid on.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 15),
          ),
        ),
      );
    }
    if (tabMatches.isEmpty) {
      return _emptyStateForTab(teamLinked: false);
    }
    return ListView(
      children: [
        for (final m in tabMatches)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: MatchCard(match: m, myBid: null),
          ),
      ],
    );
  }

  Widget _buildMatchList({
    required List<Match> tabMatches,
    required String teamDoc,
  }) {
    if (tabMatches.isEmpty) {
      return _emptyStateForTab(teamLinked: teamDoc.isNotEmpty);
    }

    if (_scheduleTab == 2) {
      if (teamDoc.isEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Link a team to your profile to see matches you still need to bid on.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 15),
            ),
          ),
        );
      }

      return ListView(
        children: [
          for (final m in tabMatches)
            StreamBuilder<ExistingMatchBid?>(
              stream: _bidsRepo.watchMyBidForMatch(
                matchDocumentId: m.documentId,
                bidderTeamDocumentId: teamDoc,
              ),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
                  return const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Center(
                      child: SizedBox(
                        height: 28,
                        width: 28,
                        child: CircularProgressIndicator(
                          color: AppColors.neonGreen,
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                  );
                }
                if (snap.data != null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: MatchCard(match: m, myBid: null),
                );
              },
            ),
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 24),
            child: Text(
              'Upcoming matches you have not placed a bid on yet.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 11),
            ),
          ),
        ],
      );
    }

    return ListView(
      children: [
        for (final m in tabMatches)
          teamDoc.isEmpty
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: MatchCard(match: m, myBid: null),
                )
              : StreamBuilder<ExistingMatchBid?>(
                  stream: _bidsRepo.watchMyBidForMatch(
                    matchDocumentId: m.documentId,
                    bidderTeamDocumentId: teamDoc,
                  ),
                  builder: (context, bidSnap) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: MatchCard(
                        match: m,
                        myBid: bidSnap.data,
                      ),
                    );
                  },
                ),
      ],
    );
  }

  Widget _emptyStateForTab({required bool teamLinked}) {
    String message;
    switch (_scheduleTab) {
      case 1:
        message = 'No matches today';
        break;
      case 2:
        message = teamLinked
            ? 'No upcoming matches left to bid on.\nYou may have already bid on all of them.'
            : 'Link a team to see matches you still need to bid on.';
        break;
      default:
        message = 'No matches scheduled.';
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildBannerCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: const Border(
          left: BorderSide(color: AppColors.neonGreen, width: 4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'MATCH\nSCHEDULE',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
          SizedBox(height: 8),
          Text(
            'SEASON 2026 • PHASE 1: GROUP STAGES',
            style: TextStyle(color: AppColors.neonGreen, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs() {
    return Row(
      children: [
        _tabButton(label: 'ALL', tabIndex: 0),
        const SizedBox(width: 8),
        _tabButton(label: 'TODAY', tabIndex: 1),
        const SizedBox(width: 8),
        _tabButton(label: 'TO BID', tabIndex: 2),
      ],
    );
  }

  Widget _tabButton({required String label, required int tabIndex}) {
    final isActive = _scheduleTab == tabIndex;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _scheduleTab = tabIndex),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? AppColors.neonGreen : AppColors.chipInactive,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isActive ? Colors.black : Colors.white60,
              fontSize: 11,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
