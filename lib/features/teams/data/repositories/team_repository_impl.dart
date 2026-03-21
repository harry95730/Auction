import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/entities/team.dart';
import '../../domain/exceptions/auth_email_already_in_use.dart';
import '../../domain/exceptions/team_id_already_exists.dart';
import '../../domain/repositories/team_repository.dart';
import '../datasources/teams_firestore_data_source.dart';

class TeamRepositoryImpl implements TeamRepository {
  TeamRepositoryImpl(
    this._dataSource, {
    FirebaseAuth? auth,
  }) : _auth = auth ?? FirebaseAuth.instance;

  final TeamsFirestoreDataSource _dataSource;
  final FirebaseAuth _auth;

  @override
  Future<List<Team>> getAllTeams({String? tournament}) async {
    final models = tournament != null && tournament.trim().isNotEmpty
        ? await _dataSource.fetchTeamsByTournament(tournament.trim())
        : await _dataSource.fetchAllTeams();
    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Stream<List<Team>> watchTeams({String? tournament}) {
    return _dataSource.watchTeams(tournament: tournament).map(
          (models) => models.map((m) => m.toEntity()).toList(),
        );
  }

  @override
  Future<Team?> getByTeamId(String teamId) async {
    final model = await _dataSource.fetchByTeamId(teamId);
    return model?.toEntity();
  }

  @override
  Stream<Team?> watchByDocumentId(String documentId) {
    return _dataSource.watchTeamByDocumentId(documentId).map((m) => m?.toEntity());
  }

  @override
  Stream<Team?> watchByTeamId(String teamId) {
    return _dataSource.watchTeamByTeamId(teamId).map((m) => m?.toEntity());
  }

  @override
  Future<void> registerTeam(Team data) async {
    final pwd = data.password;
    final teamId = data.teamId;
    final teamName = data.name;
    final captain = data.captain;
    final players = data.players;
    if (pwd == null || pwd.isEmpty) {
      throw ArgumentError('password required for registration');
    }
    if (teamId == null ||
        teamName == null ||
        captain == null ||
        players == null ||
        players.isEmpty) {
      throw ArgumentError('incomplete signup data');
    }

    if (await _dataSource.teamIdExists(teamId)) {
      throw const TeamIdAlreadyExistsException();
    }

    final email = Team.firebaseAuthEmailFromTeamName(teamName);
    final playerEmails = players.map((e) => e.trim()).toList();
    final teamLoginEmail = email.trim().toLowerCase();
    if (!playerEmails.contains(teamLoginEmail)) {
      playerEmails.add(teamLoginEmail);
    }

    late UserCredential cred;
    try {
      cred = await _auth.createUserWithEmailAndPassword(email: email, password: pwd);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        throw const AuthEmailAlreadyInUseException();
      }
      rethrow;
    }

    try {
      await _dataSource.addTeam({
        'team_id': teamId,
        'team': teamName,
        'captain': captain,
        'players': playerEmails,
        'auth_uid': cred.user!.uid,
        'created_at': FieldValue.serverTimestamp(),
        'rank': 0,
        'matches_played': 0,
        'matches_won': 0,
        'matches_lost': 0,
        'previous_balance': 0,
        'balance': 0,
        'logoUrl': null,
        'tournament': 'CGI',
      });
    } catch (_) {
      await cred.user?.delete();
      rethrow;
    }
  }
}
