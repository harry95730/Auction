import '../entities/match.dart';

abstract class MatchScheduleRepository {
  Future<List<Match>> getMatches();

  Stream<List<Match>> watchMatches();

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
  });

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
  });
}
