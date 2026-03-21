import '../../domain/entities/match.dart';
import '../../domain/repositories/match_schedule_repository.dart';
import '../datasources/match_schedule_firestore_data_source.dart';

class MatchScheduleRepositoryImpl implements MatchScheduleRepository {
  MatchScheduleRepositoryImpl(this._firestoreDataSource);

  final MatchScheduleFirestoreDataSource _firestoreDataSource;

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
  }) {
    return _firestoreDataSource.createMatch(
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
  }) {
    return _firestoreDataSource.updateMatch(
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
  }
}
