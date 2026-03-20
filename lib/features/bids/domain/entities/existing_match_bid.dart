/// Snapshot of this team's bid on a match (`bids` where `team_id` + `match_id` match).
class ExistingMatchBid {
  const ExistingMatchBid({
    required this.matchBidTeamDocumentId,
    required this.bidAmount,
  });

  /// Picked side — Firestore `match_bid_id` (**teams** document id of that side).
  final String matchBidTeamDocumentId;
  final double bidAmount;
}
