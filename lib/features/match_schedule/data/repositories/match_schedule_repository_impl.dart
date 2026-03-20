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
}
