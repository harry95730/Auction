import 'package:cloud_firestore/cloud_firestore.dart';

/// One row from `bids` for the signed-in user's team.
class RecentBid {
  const RecentBid({
    required this.documentId,
    required this.bidderTeamDocumentId,
    required this.matchId,
    required this.pickedTeamDocumentId,
    required this.bidAmount,
    required this.result,
    this.createdAt,
  });

  final String documentId;
  /// Firestore `team_id` — bidder's **teams** document id.
  final String bidderTeamDocumentId;
  final String matchId;
  /// Firestore `match_bid_id` — picked side's **teams** document id.
  final String pickedTeamDocumentId;
  final double bidAmount;
  final String result;
  final DateTime? createdAt;

  factory RecentBid.fromFirestore(String documentId, Map<String, dynamic> d) {
    final ts = d['created_at'];
    DateTime? at;
    if (ts is Timestamp) at = ts.toDate();

    return RecentBid(
      documentId: documentId,
      bidderTeamDocumentId: (d['team_id'] as String?)?.trim() ?? '',
      matchId: (d['match_id'] as String?)?.trim() ?? '',
      pickedTeamDocumentId: (d['match_bid_id'] as String?)?.trim() ?? '',
      bidAmount: (d['bid_amount'] as num?)?.toDouble() ?? 0,
      result: (d['result'] as String?)?.trim().toLowerCase() ?? 'pending',
      createdAt: at,
    );
  }
}
