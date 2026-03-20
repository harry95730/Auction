import '../entities/match.dart';

abstract class MatchScheduleRepository {
  Future<List<Match>> getMatches();
}
