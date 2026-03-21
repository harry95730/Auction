import '../entities/team.dart';

abstract class TeamRepository {
  /// When [tournament] is set (e.g. `CGI`), only those teams are returned.
  Future<List<Team>> getAllTeams({String? tournament});

  /// Same filter as [getAllTeams]; emits again when any matching team document changes.
  Stream<List<Team>> watchTeams({String? tournament});

  Future<Team?> getByTeamId(String teamId);

  Stream<Team?> watchByDocumentId(String documentId);

  Stream<Team?> watchByTeamId(String teamId);

  /// Creates a Firebase Auth user and a `teams` document (auto id). [data] must be from [Team.signup].
  Future<void> registerTeam(Team data);
}
