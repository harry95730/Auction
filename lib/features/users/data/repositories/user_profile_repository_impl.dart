import 'package:firebase_auth/firebase_auth.dart';

import '../../../teams/data/datasources/teams_firestore_data_source.dart';
import '../../domain/repositories/user_profile_repository.dart';
import '../datasources/users_firestore_data_source.dart';

class UserProfileRepositoryImpl implements UserProfileRepository {
  UserProfileRepositoryImpl(
    this._usersDataSource,
    this._teamsDataSource,
  );

  final UsersFirestoreDataSource _usersDataSource;
  final TeamsFirestoreDataSource _teamsDataSource;

  @override
  Future<void> syncUserDocumentAfterSignIn(User user) async {
    final email = user.email;
    if (email == null || email.trim().isEmpty) return;

    final team = await _teamsDataSource.findTeamByPlayerEmail(email);
    await _usersDataSource.upsertAfterSignIn(user, team);
  }
}
