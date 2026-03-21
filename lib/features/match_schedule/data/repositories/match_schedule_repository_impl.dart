import '../../../bids/data/datasources/bids_firestore_data_source.dart';
import '../../domain/entities/match.dart';
import '../../domain/repositories/match_schedule_repository.dart';
import '../datasources/match_schedule_firestore_data_source.dart';

class MatchScheduleRepositoryImpl implements MatchScheduleRepository {
  MatchScheduleRepositoryImpl(
    this._firestoreDataSource,
    this._bidsDataSource,
  );

  final MatchScheduleFirestoreDataSource _firestoreDataSource;
  final BidsFirestoreDataSource _bidsDataSource;

  Future<void> _settleIfNeeded({
    required String matchDocumentId,
    required String? result,
    required String team1Id,
    required String team2Id,
  }) async {
    final r = (result ?? '').trim();
    if (r.isEmpty) return;
    final lr = r.toLowerCase().replaceAll('-', '_');
    if (lr != 'team_1' &&
        lr != 'team1' &&
        lr != 'team_2' &&
        lr != 'team2' &&
        lr != 'draw') {
      return;
    }
    await _bidsDataSource.settleBidsForMatchResult(
      matchDocumentId: matchDocumentId,
      matchResult: lr,
      team1Id: team1Id,
      team2Id: team2Id,
    );
  }

  @override
  Future<List<Match>> getMatches() async {
    final models = await _firestoreDataSource.fetchMatches();
    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Stream<List<Match>> watchMatches() {
    return _firestoreDataSource.watchMatches().map((list) => list.map((m) => m.toEntity()).toList());
  }

  @override
  Future<String> createMatch({
    required String matchNo,
    required DateTime matchDate,
    required String venue,
    required String team1Name,
    required String team1Id,
    required String team2Name,
    required String team2Id,
    required List<double> odds,
    required List<double> bidRange,
    String status = 'OPEN',
    String tournament = 'IPL',
    int season = 2026,
    String? result,
  }) async {
    final id = await _firestoreDataSource.createMatch(
      matchNo: matchNo,
      matchDate: matchDate,
      venue: venue,
      team1Name: team1Name,
      team1Id: team1Id,
      team2Name: team2Name,
      team2Id: team2Id,
      odds: odds,
      bidRange: bidRange,
      status: status,
      tournament: tournament,
      season: season,
      result: result,
    );
    await _settleIfNeeded(
      matchDocumentId: id,
      result: result,
      team1Id: team1Id,
      team2Id: team2Id,
    );
    return id;
  }

  @override
  Future<void> updateMatch({
    required String documentId,
    required String matchNo,
    required DateTime matchDate,
    required String venue,
    required String team1Name,
    required String team1Id,
    required String team2Name,
    required String team2Id,
    required List<double> odds,
    required List<double> bidRange,
    required String status,
    required String tournament,
    required int season,
    String? result,
  }) async {
    await _firestoreDataSource.updateMatch(
      documentId: documentId,
      matchNo: matchNo,
      matchDate: matchDate,
      venue: venue,
      team1Name: team1Name,
      team1Id: team1Id,
      team2Name: team2Name,
      team2Id: team2Id,
      odds: odds,
      bidRange: bidRange,
      status: status,
      tournament: tournament,
      season: season,
      result: result,
    );
    await _settleIfNeeded(
      matchDocumentId: documentId,
      result: result,
      team1Id: team1Id,
      team2Id: team2Id,
    );
  }
}
