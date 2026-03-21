import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/existing_match_bid.dart';
import '../../domain/entities/match_bid_tally.dart';
import '../../domain/entities/recent_bid.dart';
import '../../domain/exceptions/insufficient_balance.dart';
import '../../../teams/data/datasources/teams_firestore_data_source.dart';

class BidsFirestoreDataSource {
  BidsFirestoreDataSource({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const String collectionName = 'bids';

  /// Creates a bid and debits [TeamsFirestoreDataSource.collectionName] balance in one transaction.
  ///
  /// Persists `team_id` = bidder's **teams document id**, `match_bid_id` = picked side's **teams document id**.
  Future<void> placeBid({
    required String bidderTeamDocumentId,
    required String matchDocumentId,
    required String matchBidTeamDocumentId,
    required double bidAmount,
    required double payoutOdds,
  }) async {
    if (bidAmount <= 0) {
      throw ArgumentError('bidAmount must be positive');
    }
    final bidderId = bidderTeamDocumentId.trim();
    final sideId = matchBidTeamDocumentId.trim();
    if (bidderId.isEmpty || sideId.isEmpty) {
      throw ArgumentError('Team document ids are required');
    }
    if (payoutOdds <= 0 || !payoutOdds.isFinite) {
      throw ArgumentError.value(payoutOdds, 'payoutOdds', 'must be a positive finite multiplier');
    }
    await _db.runTransaction((txn) async {
      final teamRef = _db.collection(TeamsFirestoreDataSource.collectionName).doc(bidderId);
      final teamSnap = await txn.get(teamRef);
      if (!teamSnap.exists) {
        throw StateError('Team document not found');
      }
      final raw = teamSnap.data()!;
      final balance = (raw['balance'] as num?)?.toDouble() ?? 0.0;
      if (balance < bidAmount) {
        throw const InsufficientBalanceException();
      }

      final bidRef = _db.collection(collectionName).doc();
      txn.set(bidRef, {
        'team_id': bidderId,
        'match_id': matchDocumentId,
        'created_at': FieldValue.serverTimestamp(),
        'match_bid_id': sideId,
        'bid_amount': bidAmount,
        'payout_odds': payoutOdds,
        'result': 'pending',
      });
      txn.update(teamRef, {'balance': balance - bidAmount});
    });
  }

  /// Live counts of bids whose `match_bid_id` is team1 vs team2 **document id**.
  Stream<MatchBidTally> watchBidTally({
    required String matchDocumentId,
    required String team1DocumentId,
    required String team2DocumentId,
  }) {
    final t1 = team1DocumentId.trim();
    final t2 = team2DocumentId.trim();
    if (matchDocumentId.isEmpty) {
      return Stream.value(const MatchBidTally(countTeam1: 0, countTeam2: 0));
    }

    return _db
        .collection(collectionName)
        .where('match_id', isEqualTo: matchDocumentId)
        .snapshots()
        .map((snap) {
      var c1 = 0;
      var c2 = 0;
      for (final doc in snap.docs) {
        final m = doc.data();
        final bidOn = (m['match_bid_id'] as String?)?.trim() ?? '';
        if (bidOn == t1) {
          c1++;
        } else if (bidOn == t2) {
          c2++;
        }
      }
      return MatchBidTally(countTeam1: c1, countTeam2: c2);
    });
  }

  /// Whether [bidderTeamDocumentId] already has a `bids` doc for this [matchDocumentId].
  Stream<ExistingMatchBid?> watchMyBidForMatch({
    required String matchDocumentId,
    required String bidderTeamDocumentId,
  }) {
    final mid = matchDocumentId.trim();
    final tid = bidderTeamDocumentId.trim();
    if (mid.isEmpty || tid.isEmpty) {
      return Stream.value(null);
    }

    return _db
        .collection(collectionName)
        .where('match_id', isEqualTo: mid)
        .where('team_id', isEqualTo: tid)
        .limit(1)
        .snapshots()
        .map((snap) {
      if (snap.docs.isEmpty) return null;
      final d = snap.docs.first.data();
      final bidOn = (d['match_bid_id'] as String?)?.trim() ?? '';
      final amt = (d['bid_amount'] as num?)?.toDouble() ?? 0.0;
      return ExistingMatchBid(matchBidTeamDocumentId: bidOn, bidAmount: amt);
        });
  }

  /// Latest bids placed by this team (`bids.team_id` = bidder's **teams** document id).
  Stream<List<RecentBid>> watchBidsForTeam({
    required String teamDocumentId,
    int limit = 3,
  }) {
    final tid = teamDocumentId.trim();
    if (tid.isEmpty) return Stream.value(const []);

    return _db
        .collection(collectionName)
        .where('team_id', isEqualTo: tid)
        .orderBy('created_at', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => RecentBid.fromFirestore(d.id, d.data()))
              .toList(),
        );
  }
}
