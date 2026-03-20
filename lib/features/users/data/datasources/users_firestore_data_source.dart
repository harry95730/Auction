import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../teams/data/models/team_model.dart';

class UsersFirestoreDataSource {
  UsersFirestoreDataSource({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const String collectionName = 'users';

  /// Creates or updates `users/{uid}` after sign-in. [team] from [players] lookup.
  Future<void> upsertAfterSignIn(User user, TeamModel? team) async {
    final email = user.email?.trim();
    if (email == null || email.isEmpty) return;

    final ref = _db.collection(collectionName).doc(user.uid);
    final snap = await ref.get();

    if (!snap.exists) {
      await ref.set({
        'display_name': user.displayName,
        'email': email,
        'display_url': user.photoURL,
        'created_at': FieldValue.serverTimestamp(),
        'admin': false,
        if (team != null) 'team_id': team.teamId,
        if (team != null) 'team_document_id': team.documentId,
      });
      return;
    }

    final update = <String, dynamic>{
      'display_name': user.displayName,
      'email': email,
      'display_url': user.photoURL,
    };

    final data = snap.data();
    final existingTeamId = data?['team_id'];
    final hasTeam =
        existingTeamId != null && existingTeamId.toString().trim().isNotEmpty;
    if (team != null && !hasTeam) {
      update['team_id'] = team.teamId;
      update['team_document_id'] = team.documentId;
    }

    await ref.update(update);
  }

  /// Live `users/{uid}` fields used to resolve the signed-in user's team.
  Stream<UserTeamPointers> watchTeamPointersForUid(String uid) {
    return _db.collection(collectionName).doc(uid).snapshots().map((snap) {
      if (!snap.exists) return const UserTeamPointers();
      final d = snap.data()!;
      final docId = d['team_document_id']?.toString().trim();
      final tid = d['team_id']?.toString().trim();
      return UserTeamPointers(
        teamDocumentId: (docId != null && docId.isNotEmpty) ? docId : null,
        teamId: (tid != null && tid.isNotEmpty) ? tid : null,
      );
    });
  }
}

class UserTeamPointers {
  const UserTeamPointers({this.teamDocumentId, this.teamId});

  final String? teamDocumentId;
  final String? teamId;
}
