import 'package:flutter/material.dart';

import '../../../../app/widgets/auction_command_app_bar.dart';
import '../../../dashboard/presentation/widgets/dashboard_recent_bids_section.dart';
import '../../../match_schedule/domain/entities/match.dart';
import '../../../match_schedule/domain/repositories/match_schedule_repository.dart';
import '../../domain/entities/recent_bid.dart';
import '../../domain/repositories/bids_repository.dart';

/// Full bid history for a team ([teamDocumentId] is the `teams` document id).
class RecentBidsHistoryScreen extends StatelessWidget {
  const RecentBidsHistoryScreen({
    super.key,
    required this.teamDocumentId,
    required this.bidsRepository,
    required this.matchScheduleRepository,
    this.appBarTitle,
  });

  final String teamDocumentId;
  final BidsRepository bidsRepository;
  final MatchScheduleRepository matchScheduleRepository;

  /// Defaults to **HISTORY** (e.g. use team name when viewing from leaderboard).
  final String? appBarTitle;

  static const Color _card = Color(0xFF1A1A2E);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1B),
      appBar: AuctionCommandAppBar(
        title: appBarTitle ?? 'HISTORY',
        backgroundColor: Colors.transparent,
      ),
      body: FutureBuilder<List<Match>>(
        future: matchScheduleRepository.getMatches(),
        builder: (context, matchSnap) {
          if (matchSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF2ECC71)));
          }
          final byId = {for (final m in matchSnap.data ?? []) m.documentId: m};

          return StreamBuilder<List<RecentBid>>(
            stream: bidsRepository.watchBidsForTeam(teamDocumentId: teamDocumentId, limit: 100),
            builder: (context, bidSnap) {
              final loading =
                  bidSnap.connectionState == ConnectionState.waiting && !bidSnap.hasData;
              final bids = bidSnap.data ?? [];

              if (loading) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFF2ECC71)));
              }

              if (bids.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No bids yet.',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                    ),
                  ),
                );
              }

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                    ),
                    child: Column(
                      children: [
                        for (var i = 0; i < bids.length; i++)
                          RecentBidRow(
                            bid: bids[i],
                            match: byId[bids[i].matchId],
                            isLast: i == bids.length - 1,
                          ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
