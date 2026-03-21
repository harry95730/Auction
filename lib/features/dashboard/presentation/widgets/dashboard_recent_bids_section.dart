import 'package:flutter/material.dart';

import '../../../bids/domain/entities/recent_bid.dart';
import '../../../bids/presentation/match_bid_labels.dart';
import '../../../match_schedule/domain/entities/match.dart';

/// “Recent Bids” card — dark navy styling; [bids] already capped (e.g. 3).
///
/// Callers should pass bids where Firestore `bids.team_id` equals the user’s team **document id**.
class DashboardRecentBidsSection extends StatelessWidget {
  const DashboardRecentBidsSection({
    super.key,
    required this.bids,
    required this.matchById,
    this.onViewAll,
    this.loading = false,
  });

  final List<RecentBid> bids;
  final Map<String, Match> matchById;
  final VoidCallback? onViewAll;
  final bool loading;

  static const Color _card = Color(0xFF1A1A2E);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Bids',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: onViewAll,
              child: Text(
                'FULL HISTORY',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: loading
              ? const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFF2ECC71)),
                  ),
                )
              : bids.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No bids yet. Enter an auction room when a match is open.',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
                      ),
                    )
                  : Column(
                      children: [
                        for (var i = 0; i < bids.length; i++)
                          RecentBidRow(
                            bid: bids[i],
                            match: matchById[bids[i].matchId],
                            isLast: i == bids.length - 1,
                          ),
                      ],
                    ),
        ),
      ],
    );
  }
}

/// Single bid row (dashboard + full history).
class RecentBidRow extends StatelessWidget {
  const RecentBidRow({
    super.key,
    required this.bid,
    required this.match,
    required this.isLast,
  });

  final RecentBid bid;
  final Match? match;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final title = _matchTitle(match, bid);
    final role = _roleLine(bid);
    final status = _statusPresentation(bid.result);
    final price = '₹ ${_formatMoney(bid.bidAmount)}';
    final odds = effectivePayoutOddsForBid(bid, match);
    final potentialWin = odds != null ? bid.bidAmount * odds : null;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 50,
                width: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFF252545),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.gavel, color: status.iconColor, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      role,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (odds != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        '@ ${odds.toStringAsFixed(2)}× on your pick',
                        style: TextStyle(
                          color: Colors.green.shade300,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (potentialWin != null)
                        Text(
                          'If win: ₹ ${_formatMoney(potentialWin)}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.45),
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    price,
                    style: TextStyle(
                      color: status.amountColor,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    status.label,
                    style: TextStyle(
                      color: status.textColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(height: 1, thickness: 1, color: Colors.white.withValues(alpha: 0.06)),
      ],
    );
  }

  static String _matchTitle(Match? m, RecentBid bid) {
    if (m == null) {
      final id = bid.matchId;
      if (id.isEmpty) return 'Match';
      final short = id.length > 8 ? '${id.substring(0, 8)}…' : id;
      return 'Match $short';
    }
    final a = (m.team1 ?? 'T1').trim();
    final b = (m.team2 ?? 'T2').trim();
    return '$a vs $b';
  }

  String _roleLine(RecentBid bid) {
    final id = bid.pickedTeamDocumentId;
    final pickShort = id.length > 10 ? '${id.substring(0, 10)}…' : id;
    final pick = id.isNotEmpty ? 'STAKE ON PICK • $pickShort' : 'MATCH BID';
    if (bid.createdAt == null) return pick;
    final d = bid.createdAt!;
    final mo = _months[d.month - 1];
    return '$pick • $mo ${d.day}, ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  static const _months = <String>[
    'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
  ];

  static String _formatMoney(double v) {
    final s = v.round().toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final fromEnd = s.length - i;
      if (i > 0 && fromEnd % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

class _StatusPresentation {
  const _StatusPresentation({
    required this.label,
    required this.textColor,
    required this.iconColor,
    required this.amountColor,
  });

  final String label;
  final Color textColor;
  final Color iconColor;
  /// Same semantics as [textColor] — applied to the staked ₹ amount.
  final Color amountColor;
}

_StatusPresentation _statusPresentation(String raw) {
  final result = raw.trim().toLowerCase();

  switch (result) {
    case 'won':
    case 'win':
      return const _StatusPresentation(
        label: 'WON',
        textColor: Color(0xFF4ADE80),
        iconColor: Color(0xFF4ADE80),
        amountColor: Color(0xFF4ADE80),
      );
    case 'lost':
    case 'lose':
      return const _StatusPresentation(
        label: 'LOST',
        textColor: Color(0xFFF87171),
        iconColor: Color(0xFFF87171),
        amountColor: Color(0xFFF87171),
      );
    case 'draw':
      return const _StatusPresentation(
        label: 'DRAW',
        textColor: Color(0xFF93C5FD),
        iconColor: Color(0xFF93C5FD),
        amountColor: Color(0xFF93C5FD),
      );
    case 'outbid':
      return const _StatusPresentation(
        label: 'OUTBID',
        textColor: Color(0xFFF87171),
        iconColor: Color(0xFFF87171),
        amountColor: Color(0xFFF87171),
      );
    case 'pending':
    default:
      return const _StatusPresentation(
        label: 'PENDING',
        textColor: Color(0xFFFBBF24),
        iconColor: Color(0xFFFBBF24),
        amountColor: Color(0xFFFBBF24),
      );
  }
}
