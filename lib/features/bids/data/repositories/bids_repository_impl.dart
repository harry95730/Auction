import '../../data/datasources/bids_firestore_data_source.dart';
import '../../domain/entities/existing_match_bid.dart';
import '../../domain/entities/match_bid_tally.dart';
import '../../domain/entities/recent_bid.dart';
import '../../domain/repositories/bids_repository.dart';

class BidsRepositoryImpl implements BidsRepository {
  BidsRepositoryImpl(this._dataSource);

  final BidsFirestoreDataSource _dataSource;

  @override
  Future<void> placeBid({
    required String bidderTeamDocumentId,
    required String matchDocumentId,
    required String matchBidTeamDocumentId,
    required double bidAmount,
    required double payoutOdds,
  }) {
    return _dataSource.placeBid(
      bidderTeamDocumentId: bidderTeamDocumentId,
      matchDocumentId: matchDocumentId,
      matchBidTeamDocumentId: matchBidTeamDocumentId,
      bidAmount: bidAmount,
      payoutOdds: payoutOdds,
    );
  }

  @override
  Stream<MatchBidTally> watchBidTally({
    required String matchDocumentId,
    required String team1DocumentId,
    required String team2DocumentId,
  }) {
    return _dataSource.watchBidTally(
      matchDocumentId: matchDocumentId,
      team1DocumentId: team1DocumentId,
      team2DocumentId: team2DocumentId,
    );
  }

  @override
  Stream<ExistingMatchBid?> watchMyBidForMatch({
    required String matchDocumentId,
    required String bidderTeamDocumentId,
  }) {
    return _dataSource.watchMyBidForMatch(
      matchDocumentId: matchDocumentId,
      bidderTeamDocumentId: bidderTeamDocumentId,
    );
  }

  @override
  Stream<List<RecentBid>> watchBidsForTeam({
    required String teamDocumentId,
    int limit = 3,
  }) {
    return _dataSource.watchBidsForTeam(teamDocumentId: teamDocumentId, limit: limit);
  }
}
