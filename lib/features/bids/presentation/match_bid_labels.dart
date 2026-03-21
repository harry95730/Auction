import '../../match_schedule/domain/entities/match.dart';
import '../domain/entities/existing_match_bid.dart';
import '../domain/entities/recent_bid.dart';

/// Uppercase label for the team the user picked (`match_bid_id` vs match `team_1_id` / `team_2_id`).
String pickedTeamDisplayName(Match match, ExistingMatchBid bid) {
  final id = bid.matchBidTeamDocumentId.trim();
  if (id.isEmpty) return '—';
  final t1 = match.team1Id?.trim();
  final t2 = match.team2Id?.trim();
  if (t1 != null && t1 == id) {
    return (match.team1 ?? t1).toUpperCase();
  }
  if (t2 != null && t2 == id) {
    return (match.team2 ?? t2).toUpperCase();
  }
  return 'YOUR PICK';
}

/// `0` = team1 side, `1` = team2, `-1` if unknown.
int pickedSideIndexForMatch(Match match, String pickedDocumentId) {
  final id = pickedDocumentId.trim();
  if (id.isEmpty) return -1;
  if (match.team1Id?.trim() == id) return 0;
  if (match.team2Id?.trim() == id) return 1;
  return -1;
}

bool isMatchScheduleLocked(Match m) => (m.status ?? '').toUpperCase().contains('LOCKED');

/// Match finished / result known — UI uses yellow border and results CTA.
bool isMatchCompleted(Match m) {
  final s = (m.status ?? '').toUpperCase();
  if (s.contains('COMPLETE') || s.contains('FINISH') || s.contains('RESULT')) return true;
  return (m.result?.trim().isNotEmpty ?? false);
}

/// When **`status` is `COMPLETED`** and Firestore **`result`** is `team_1` / `team_2`, returns **`0`** / **`1`**.
/// `draw`, missing result, or other statuses → **`null`** (no winner highlight).
int? matchCompletedWinnerSide(Match m) {
  final status = (m.status ?? '').trim().toUpperCase();
  if (status != 'COMPLETED') return null;
  final r = (m.result ?? '').trim().toLowerCase().replaceAll('-', '_');
  if (r == 'team_1' || r == 'team1') return 0;
  if (r == 'team_2' || r == 'team2') return 1;
  return null;
}

/// Odds multiplier for this bid: prefers Firestore **`payout_odds`** on the bid, else derives from [match].
double? effectivePayoutOddsForBid(RecentBid bid, Match? match) {
  final locked = bid.payoutOdds;
  if (locked != null && locked > 0 && locked.isFinite) return locked;
  if (match == null) return null;
  final list = match.odds;
  if (list == null || list.isEmpty) return null;
  final side = pickedSideIndexForMatch(match, bid.pickedTeamDocumentId);
  if (side != 0 && side != 1) return null;
  if (list.length >= 2) {
    final o = list[side];
    return o > 0 && o.isFinite ? o : null;
  }
  final o = list[0];
  return o > 0 && o.isFinite ? o : null;
}
