import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/match_model.dart';

class MatchScheduleFirestoreDataSource {
  MatchScheduleFirestoreDataSource({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const String collectionName = 'matches';

  Future<List<MatchModel>> fetchMatches() async {
    final snapshot = await _db.collection(collectionName).get();
    final models = <MatchModel>[
      for (final doc in snapshot.docs) MatchModel.fromFirestore(doc.data(), doc.id),
    ];

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
}
