import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/team_model.dart';

class TeamsFirestoreDataSource {
  TeamsFirestoreDataSource({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const String collectionName = 'teams';

  /// Auto-generated document id (Firebase).
  Future<String> addTeam(Map<String, dynamic> data) async {
    final ref = await _db.collection(collectionName).add(data);
    return ref.id;
  }

  Future<bool> teamIdExists(String teamId) async {
    final trimmed = teamId.trim();
    if (trimmed.isEmpty) return false;
    final snapshot = await _db
        .collection(collectionName)
        .where('team_id', isEqualTo: trimmed)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  /// First team whose `players` array contains this email (normalized lowercase).
  Future<TeamModel?> findTeamByPlayerEmail(String email) async {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    final snapshot = await _db
        .collection(collectionName)
        .where('players', arrayContains: normalized)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    final doc = snapshot.docs.first;
    return TeamModel.fromFirestore(doc.data(), doc.id);
  }

  /// All team documents (for leaderboards). Client should sort/filter.
  Future<List<TeamModel>> fetchAllTeams() async {
    final snap = await _db.collection(collectionName).get();
    return snap.docs.map((d) => TeamModel.fromFirestore(d.data(), d.id)).toList();
  }

  /// Teams in a tournament (e.g. `CGI`). Field: `tournament`.
  Future<List<TeamModel>> fetchTeamsByTournament(String tournament) async {
    final t = tournament.trim();
    if (t.isEmpty) return fetchAllTeams();
    final snap = await _db.collection(collectionName).where('tournament', isEqualTo: t).get();
    return snap.docs.map((d) => TeamModel.fromFirestore(d.data(), d.id)).toList();
  }

  /// Live updates when any team in [tournament] changes (balance, rank, etc.).
  /// If [tournament] is null or empty, watches the full `teams` collection.
  Stream<List<TeamModel>> watchTeams({String? tournament}) {
    final t = tournament?.trim() ?? '';
    Query<Map<String, dynamic>> q = _db.collection(collectionName);
    if (t.isNotEmpty) {
      q = q.where('tournament', isEqualTo: t);
    }
    return q.snapshots().map(
          (snap) => snap.docs.map((d) => TeamModel.fromFirestore(d.data(), d.id)).toList(),
        );
  }

  /// [storedId] may be a **Firestore document id** or the **`team_id`** field value (e.g. `"MI"`).
  /// Returns the canonical **document id** for updates that must match `bids.match_bid_id`.
  Future<String?> resolveTeamDocumentId(String storedId) async {
    final s = storedId.trim();
    if (s.isEmpty) return null;
    final byDoc = await _db.collection(collectionName).doc(s).get();
    if (byDoc.exists) return s;
    final byField = await fetchByTeamId(s);
    return byField?.documentId;
  }

  /// [teamId] matches document field `team_id` (e.g. "MI").
  Future<TeamModel?> fetchByTeamId(String teamId) async {
    final trimmed = teamId.trim();
    if (trimmed.isEmpty) return null;

    final snapshot = await _db
        .collection(collectionName)
        .where('team_id', isEqualTo: trimmed)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    final doc = snapshot.docs.first;
    return TeamModel.fromFirestore(doc.data(), doc.id);
  }

  Stream<TeamModel?> watchTeamByDocumentId(String documentId) {
    final id = documentId.trim();
    if (id.isEmpty) return Stream.value(null);
    return _db.collection(collectionName).doc(id).snapshots().map((snap) {
      if (!snap.exists) return null;
      return TeamModel.fromFirestore(snap.data()!, snap.id);
    });
  }

  /// [teamId] matches document field `team_id`.
  Stream<TeamModel?> watchTeamByTeamId(String teamId) {
    final trimmed = teamId.trim();
    if (trimmed.isEmpty) return Stream.value(null);
    return _db
        .collection(collectionName)
        .where('team_id', isEqualTo: trimmed)
        .limit(1)
        .snapshots()
        .map((snap) {
      if (snap.docs.isEmpty) return null;
      final doc = snap.docs.first;
      return TeamModel.fromFirestore(doc.data(), doc.id);
    });
  }
}
