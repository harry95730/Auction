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

  /// When a match ends (`team_1` / `team_2` / `draw`), credit or record each **pending** bid and update bidder **teams**.
  ///
  /// - **Win** (picked side = winning side): `balance += bid_amount * payout_odds`, `previous_balance = payout`,
  ///   `matches_played++`, `matches_won++`, bid `result`: `won`.
  /// - **Loss**: `previous_balance = -bid_amount`, `matches_played++`, `matches_lost++`, bid `result`: `lost`.
  /// - **Draw**: refund stake `balance += bid_amount`, `previous_balance = 0`, `matches_played++`, bid `result`: `draw`.
  ///
  /// Skips bids whose `result` is already not `pending`.
  ///
  /// Match `team_1_id` / `team_2_id` may store either a **document id** or **`team_id`** (see admin save);
  /// `bids.match_bid_id` is always the picked side's **teams document id** — we resolve match ids before comparing.
  Future<void> settleBidsForMatchResult({
    required String matchDocumentId,
    required String matchResult,
    required String team1Id,
    required String team2Id,
  }) async {
    final mid = matchDocumentId.trim();
    if (mid.isEmpty) return;

    final r = matchResult.trim().toLowerCase().replaceAll('-', '_');
    if (r != 'team_1' &&
        r != 'team1' &&
        r != 'team_2' &&
        r != 'team2' &&
        r != 'draw') {
      return;
    }

    final teamsDs = TeamsFirestoreDataSource(firestore: _db);
    final t1 = team1Id.trim();
    final t2 = team2Id.trim();

    final String? winningPickedDocId;
    if (r == 'draw') {
      winningPickedDocId = null;
    } else {
      final sideRaw = (r == 'team_1' || r == 'team1') ? t1 : t2;
      winningPickedDocId = await teamsDs.resolveTeamDocumentId(sideRaw);
      if (winningPickedDocId == null) return;
    }

    final snap = await _db.collection(collectionName).where('match_id', isEqualTo: mid).get();

    for (final doc in snap.docs) {
      await _db.runTransaction((txn) async {
        final bidRef = doc.reference;
        final bidSnap = await txn.get(bidRef);
        if (!bidSnap.exists) return;

        final d = bidSnap.data()!;
        final bidStatus = (d['result'] as String?)?.trim().toLowerCase() ?? 'pending';
        if (bidStatus != 'pending') return;

        final bidderTeamId = (d['team_id'] as String?)?.trim() ?? '';
        final picked = (d['match_bid_id'] as String?)?.trim() ?? '';
        final stake = (d['bid_amount'] as num?)?.toDouble() ?? 0.0;
        final odds = (d['payout_odds'] as num?)?.toDouble() ?? 1.0;
        if (bidderTeamId.isEmpty || stake <= 0) return;

        final teamRef = _db.collection(TeamsFirestoreDataSource.collectionName).doc(bidderTeamId);
        final teamSnap = await txn.get(teamRef);
        if (!teamSnap.exists) return;

        if (r == 'draw') {
          txn.update(teamRef, {
            'balance': FieldValue.increment(stake),
            'previous_balance': 0,
            'matches_played': FieldValue.increment(1),
          });
          txn.update(bidRef, {'result': 'draw'});
          return;
        }

        final won = winningPickedDocId != null && picked == winningPickedDocId;
        if (won) {
          final payout = stake * odds;
          txn.update(teamRef, {
            'balance': FieldValue.increment(payout),
            'previous_balance': payout,
            'matches_played': FieldValue.increment(1),
            'matches_won': FieldValue.increment(1),
          });
          txn.update(bidRef, {'result': 'won'});
        } else {
          txn.update(teamRef, {
            'previous_balance': -stake,
            'matches_played': FieldValue.increment(1),
            'matches_lost': FieldValue.increment(1),
          });
          txn.update(bidRef, {'result': 'lost'});
        }
      });
    }
  }
}
