import '../entities/existing_match_bid.dart';
import '../entities/match_bid_tally.dart';
import '../entities/recent_bid.dart';

abstract class BidsRepository {
  /// [bidderTeamDocumentId] and [matchBidTeamDocumentId] are `teams/{id}` document ids.
  Future<void> placeBid({
    required String bidderTeamDocumentId,
    required String matchDocumentId,
    required String matchBidTeamDocumentId,
    required double bidAmount,
    required double payoutOdds,
  });

  /// [team1DocumentId] / [team2DocumentId] — `teams` document ids for the two sides.
  Stream<MatchBidTally> watchBidTally({
    required String matchDocumentId,
    required String team1DocumentId,
    required String team2DocumentId,
  });

  Stream<ExistingMatchBid?> watchMyBidForMatch({
    required String matchDocumentId,
    required String bidderTeamDocumentId,
  });

  Stream<List<RecentBid>> watchBidsForTeam({
    required String teamDocumentId,
    int limit = 3,
  });
}
