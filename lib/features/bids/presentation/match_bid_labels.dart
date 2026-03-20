import '../../match_schedule/domain/entities/match.dart';
import '../domain/entities/existing_match_bid.dart';

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
