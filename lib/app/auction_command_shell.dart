import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../features/bids/data/datasources/bids_firestore_data_source.dart';
import '../features/bids/data/repositories/bids_repository_impl.dart';
import '../features/bids/domain/repositories/bids_repository.dart';
import '../features/bids/presentation/screens/recent_bids_history_screen.dart';
import '../features/dashboard/presentation/screens/auction_dashboard_screen.dart';
import '../features/leaderboard/presentation/screens/auction_leaderboard_screen.dart';
import '../features/admin/presentation/screens/match_management_screen.dart';
import '../features/match_schedule/domain/repositories/match_schedule_repository.dart';
import '../features/match_schedule/presentation/screens/match_schedule_screen.dart';
import '../features/teams/domain/entities/team.dart';
import '../features/teams/domain/repositories/team_repository.dart';
import '../features/users/data/datasources/users_firestore_data_source.dart';
import 'theme/app_colors.dart';
import 'widgets/auction_command_app_bar.dart';
import 'widgets/custom_nav_bar.dart';

/// Signed-in root: main tabs + [CustomNavBar]. Tab selection drives highlight (dashboard / schedule / leaderboard / history).
class AuctionCommandShell extends StatefulWidget {
  const AuctionCommandShell({
    super.key,
    required this.matchScheduleRepository,
    required this.teamRepository,
  });

  final MatchScheduleRepository matchScheduleRepository;
  final TeamRepository teamRepository;

  @override
  State<AuctionCommandShell> createState() => _AuctionCommandShellState();
}

class _AuctionCommandShellState extends State<AuctionCommandShell> {
  int _tabIndex = MainTab.dashboard;
  late final BidsRepository _bidsRepo;
  late final UsersFirestoreDataSource _usersDs;

  @override
  void initState() {
    super.initState();
    _bidsRepo = BidsRepositoryImpl(BidsFirestoreDataSource());
    _usersDs = UsersFirestoreDataSource();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return StreamBuilder<bool>(
      stream: uid != null ? _usersDs.watchIsAdmin(uid) : Stream<bool>.value(false),
      builder: (context, adminSnap) {
        final isAdmin = adminSnap.data ?? false;
        return Scaffold(
          backgroundColor: AppColors.scaffoldBackground,
          body: IndexedStack(
            index: _tabIndex,
            children: [
              AuctionDashboardScreen(
                matchScheduleRepository: widget.matchScheduleRepository,
                teamRepository: widget.teamRepository,
                onNavigateToTab: (i) => setState(() => _tabIndex = i),
              ),
              MatchScheduleScreen(
                repository: widget.matchScheduleRepository,
                teamRepository: widget.teamRepository,
                bidsRepository: _bidsRepo,
              ),
              AuctionLeaderboardScreen(
                teamRepository: widget.teamRepository,
                matchScheduleRepository: widget.matchScheduleRepository,
                bidsRepository: _bidsRepo,
              ),
              _HistoryTab(
                teamRepository: widget.teamRepository,
                matchScheduleRepository: widget.matchScheduleRepository,
                bidsRepository: _bidsRepo,
                usersDs: _usersDs,
              ),
            ],
          ),
          floatingActionButton: isAdmin
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 72),
                  child: FloatingActionButton.extended(
                    onPressed: () {
                      Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => MatchManagementScreen(
                            matchScheduleRepository: widget.matchScheduleRepository,
                            teamRepository: widget.teamRepository,
                            usersDataSource: _usersDs,
                          ),
                        ),
                      );
                    },
                    backgroundColor: AppColors.neonGreen,
                    foregroundColor: Colors.black,
                    icon: const Icon(Icons.edit_calendar_outlined),
                    label: const Text('MATCH MGMT'),
                  ),
                )
              : null,
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
          bottomNavigationBar: SafeArea(
            minimum: const EdgeInsets.only(bottom: 4),
            child: CustomNavBar(
              selectedIndex: _tabIndex,
              onItemSelected: (i) => setState(() => _tabIndex = i),
            ),
          ),
        );
      },
    );
  }
}

class _HistoryTab extends StatelessWidget {
  const _HistoryTab({
    required this.teamRepository,
    required this.matchScheduleRepository,
    required this.bidsRepository,
    required this.usersDs,
  });

  final TeamRepository teamRepository;
  final MatchScheduleRepository matchScheduleRepository;
  final BidsRepository bidsRepository;
  final UsersFirestoreDataSource usersDs;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnap) {
        final user = authSnap.data;
        if (user == null) {
          return const Scaffold(
            backgroundColor: Color(0xFF0D0D1B),
            body: Center(
              child: Text('Sign in to view history', style: TextStyle(color: Colors.white70)),
            ),
          );
        }

        return StreamBuilder<UserTeamPointers>(
          stream: usersDs.watchTeamPointersForUid(user.uid),
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
                teamStream = teamRepository.watchByDocumentId(p.teamDocumentId!);
              } else if (p.teamId != null && p.teamId!.isNotEmpty) {
                teamStream = teamRepository.watchByTeamId(p.teamId!);
              } else {
                teamStream = Stream<Team?>.value(null);
              }
            }

            return StreamBuilder<Team?>(
              stream: teamStream,
              builder: (context, teamSnap) {
                final team = teamSnap.data;
                final teamDoc = team?.documentId.trim() ?? '';
                final loading = hasTeam && teamSnap.connectionState == ConnectionState.waiting && teamDoc.isEmpty;

                if (loading) {
                  return const Scaffold(
                    backgroundColor: Color(0xFF0D0D1B),
                    body: Center(child: CircularProgressIndicator(color: AppColors.neonGreen)),
                  );
                }

                if (!hasTeam || teamDoc.isEmpty) {
                  return Scaffold(
                    backgroundColor: const Color(0xFF0D0D1B),
                    appBar: const AuctionCommandAppBar(
                      title: 'HISTORY',
                      backgroundColor: Colors.transparent,
                    ),
                    body: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Link a team to your profile to see bid history.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 15),
                        ),
                      ),
                    ),
                  );
                }

                return RecentBidsHistoryScreen(
                  teamDocumentId: teamDoc,
                  bidsRepository: bidsRepository,
                  matchScheduleRepository: matchScheduleRepository,
                );
              },
            );
          },
        );
      },
    );
  }
}
