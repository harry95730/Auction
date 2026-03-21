import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/match_model.dart';

class MatchScheduleFirestoreDataSource {
  MatchScheduleFirestoreDataSource({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const String collectionName = 'matches';

  Future<List<MatchModel>> fetchMatches() async {
    final snapshot = await _db.collection(collectionName).get();
    return _sortMatchModels([
      for (final doc in snapshot.docs) MatchModel.fromFirestore(doc.data(), doc.id),
    ]);
  }

  Stream<List<MatchModel>> watchMatches() {
    return _db.collection(collectionName).snapshots().map((snapshot) {
      return _sortMatchModels([
        for (final doc in snapshot.docs) MatchModel.fromFirestore(doc.data(), doc.id),
      ]);
    });
  }

  List<MatchModel> _sortMatchModels(List<MatchModel> models) {
    models.sort((a, b) {
      final ad = a.matchDate;
      final bd = b.matchDate;
      if (ad == null && bd == null) return a.documentId.compareTo(b.documentId);
      if (ad == null) return 1;
      if (bd == null) return -1;
      return ad.compareTo(bd);
    });
    return models;
  }

  void _assertBidRange(List<double> bidRange) {
    if (bidRange.length != 2) {
      throw ArgumentError.value(bidRange, 'bidRange', 'expected [min, max]');
    }
    if (bidRange[0] >= bidRange[1]) {
      throw ArgumentError.value(bidRange, 'bidRange', 'min must be < max');
    }
  }

  /// Final results require **`COMPLETED`** status in Firestore.
  String _statusForFirestore({required String status, String? result}) {
    final r = (result ?? '').trim().toLowerCase().replaceAll('-', '_');
    if (r == 'team_1' ||
        r == 'team1' ||
        r == 'team_2' ||
        r == 'team2' ||
        r == 'draw') {
      return 'COMPLETED';
    }
    return status.trim();
  }

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
    if (odds.length != 2) {
      throw ArgumentError.value(odds, 'odds', 'expected exactly two values [home, away]');
    }
    _assertBidRange(bidRange);
    final data = <String, dynamic>{
      'match_no': matchNo.trim(),
      'match_date_time': Timestamp.fromDate(matchDate),
      'venue': venue.trim(),
      'team_1': team1Name.trim(),
      'team_1_id': team1Id.trim(),
      'team_2': team2Name.trim(),
      'team_2_id': team2Id.trim(),
      'odds': odds,
      'status': _statusForFirestore(status: status, result: result),
      'tournament': tournament.trim(),
      'season': season,
      'bid_range': bidRange,
    };
    if (result != null && result.trim().isNotEmpty) {
      data['result'] = result.trim();
    }
    final ref = await _db.collection(collectionName).add(data);
    return ref.id;
  }

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
    if (odds.length != 2) {
      throw ArgumentError.value(odds, 'odds', 'expected exactly two values [home, away]');
    }
    _assertBidRange(bidRange);
    final data = <String, dynamic>{
      'match_no': matchNo.trim(),
      'match_date_time': Timestamp.fromDate(matchDate),
      'venue': venue.trim(),
      'team_1': team1Name.trim(),
      'team_1_id': team1Id.trim(),
      'team_2': team2Name.trim(),
      'team_2_id': team2Id.trim(),
      'odds': odds,
      'status': _statusForFirestore(status: status, result: result),
      'tournament': tournament.trim(),
      'season': season,
      'bid_range': bidRange,
    };
    if (result != null && result.trim().isNotEmpty) {
      data['result'] = result.trim();
    } else {
      data['result'] = FieldValue.delete();
    }
    await _db.collection(collectionName).doc(documentId).update(data);
  }
}
