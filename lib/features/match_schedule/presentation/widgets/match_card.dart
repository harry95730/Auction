import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../bids/domain/entities/existing_match_bid.dart';
import '../../../bids/presentation/match_bid_labels.dart';
import '../../domain/entities/match.dart';
import '../screens/place_bid_screen.dart';
import 'team_logo_asset.dart';

class MatchCard extends StatelessWidget {
  const MatchCard({super.key, required this.match, this.myBid});

  final Match match;

  /// When set, this user’s team already bid — amber **LOCKED** + picked side.
  final ExistingMatchBid? myBid;

  static const _months = <String>[
    'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
  ];

  String _monthDay(DateTime d) {
    return '${_months[d.month - 1]} ${d.day.toString().padLeft(2, '0')}';
  }

  String _timeIst(DateTime? d) {
    if (d == null) return '—';
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m IST';
  }

  String _formatBidRange(List<double>? range) {
    if (range == null || range.isEmpty) return '—';
    if (range.length == 1) return range.first.toStringAsFixed(0);
    final lo = range.reduce((a, b) => a < b ? a : b);
    final hi = range.reduce((a, b) => a > b ? a : b);
    return '${lo.toStringAsFixed(0)} – ${hi.toStringAsFixed(0)}';
  }

  Widget _oddsInlineRow(List<double>? odds, TextStyle style) {
    if (odds == null || odds.isEmpty) {
      return Text('Odds —', style: style);
    }
    if (odds.length >= 2) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Odds ', style: style),
          Text(odds[0].toStringAsFixed(2), style: style.copyWith(fontWeight: FontWeight.w600)),
          Text('  ·  ', style: style),
          Text(odds[1].toStringAsFixed(2), style: style.copyWith(fontWeight: FontWeight.w600)),
        ],
      );
    }
    return Text('Odds ${odds[0].toStringAsFixed(2)}', style: style);
  }

  Color _statusColor() {
    final s = (match.status ?? '').toUpperCase();
    if (s == 'OPEN' || s == 'LIVE') return AppColors.neonGreen;
    if (s.contains('LOCK')) return Colors.orange.shade300;
    if (s == 'CLOSED' || s == 'COMPLETED') return Colors.white38;
    return Colors.amber.shade200;
  }

  String _headerNo() => match.matchNo ?? match.matchId ?? match.documentId;

  @override
  Widget build(BuildContext context) {
    final md = match.matchDate;
    final dateStr = md != null ? _monthDay(md) : '— —';
    final dateParts = md != null ? dateStr.split(' ') : ['—', '—'];
    final bid = myBid;
    final userHasBid = bid != null;
    final pickedSide =
        userHasBid ? pickedSideIndexForMatch(match, bid.matchBidTeamDocumentId) : -1;
    final scheduleLocked = isMatchScheduleLocked(match);
    final completed = isMatchCompleted(match);
    final winnerSide = matchCompletedWinnerSide(match);
    final greyNoBidLocked = scheduleLocked && !userHasBid && !completed;

    final cardBg = const Color(0xFF1A1D26);
    final border = completed
        ? Border.all(color: Colors.yellow.withValues(alpha: 0.5), width: 1)
        : null;

    Widget content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _headerNo(),
                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                  Text(
                    dateParts[0],
                    style: TextStyle(
                      fontSize: 18,
                      color: greyNoBidLocked ? Colors.white54 : Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    dateParts[1],
                    style: TextStyle(
                      fontSize: 18,
                      color: greyNoBidLocked ? Colors.white54 : Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 30),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: _teamName(
                        match.team1,
                        match.team1Id,
                        0,
                        alignEnd: false,
                        highlightPick: pickedSide == 0,
                        highlightWinner: winnerSide == 0,
                        muted: greyNoBidLocked,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        'VS',
                        style: TextStyle(
                          color: greyNoBidLocked
                              ? Colors.green.withValues(alpha: 0.35)
                              : AppColors.neonGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      child: _teamName(
                        match.team2,
                        match.team2Id,
                        1,
                        alignEnd: true,
                        highlightPick: pickedSide == 1,
                        highlightWinner: winnerSide == 1,
                        muted: greyNoBidLocked,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              const SizedBox(width: 70),
              Icon(
                Icons.access_time,
                size: 14,
                color: greyNoBidLocked ? Colors.white24 : Colors.white38,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  completed && (match.result?.trim().isNotEmpty ?? false)
                      ? 'Final: ${match.result}'
                      : _timeIst(match.matchDate),
                  style: TextStyle(
                    color: completed
                        ? Colors.amber.shade200
                        : (greyNoBidLocked ? Colors.white38 : Colors.white70),
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if ((match.venue ?? '').trim().isNotEmpty) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.location_on,
                  size: 14,
                  color: greyNoBidLocked ? Colors.white24 : Colors.white38,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    match.venue!,
                    style: TextStyle(
                      color: greyNoBidLocked ? Colors.white38 : Colors.white70,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ],
          ),
          if (!completed) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 70),
              child: Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  Text(
                    'Bid ends ${_timeIst(match.bidEndTime ?? match.matchDate)}',
                    style: TextStyle(
                      color: greyNoBidLocked ? Colors.white30 : Colors.white38,
                      fontSize: 11,
                    ),
                  ),
                  _oddsInlineRow(
                    match.odds,
                    TextStyle(
                      color: greyNoBidLocked ? Colors.white30 : Colors.white38,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    'Range ${_formatBidRange(match.bidRange)}',
                    style: TextStyle(
                      color: greyNoBidLocked ? Colors.white30 : Colors.white38,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if ((match.toss != null && match.toss!.isNotEmpty) ||
              (match.result != null && match.result!.isNotEmpty)) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 70),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (match.toss != null && match.toss!.isNotEmpty)
                    Text('Toss: ${match.toss}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                  if (match.result != null && match.result!.isNotEmpty)
                    Text('Result: ${match.result}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatusBadge(completed: completed, scheduleLocked: scheduleLocked, greyed: greyNoBidLocked),
              Flexible(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _buildBidAction(
                    context,
                    bid,
                    userHasBid,
                    completed: completed,
                    scheduleLocked: scheduleLocked,
                  ),
                ),
              ),
            ],
          ),
        ],
    );

    content = Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: border,
      ),
      child: content,
    );

    if (greyNoBidLocked) {
      return Opacity(opacity: 0.58, child: content);
    }

    return content;
  }

  Widget _buildStatusBadge({
    required bool completed,
    required bool scheduleLocked,
    required bool greyed,
  }) {
    Color labelColor;
    String label;
    if (completed) {
      labelColor = Colors.orange.shade300;
      label = 'COMPLETED';
    } else if (scheduleLocked) {
      labelColor = greyed ? Colors.white24 : Colors.grey;
      label = 'LOCKED';
    } else {
      final raw = (match.status ?? '').trim();
      final upper = raw.toUpperCase();
      if (upper.contains('OPEN') || upper.contains('LIVE') || raw.isEmpty) {
        labelColor = AppColors.neonGreen;
        label = upper.contains('LIVE') ? '● LIVE' : '● OPEN';
      } else {
        labelColor = _statusColor();
        label = raw.isEmpty ? '—' : upper;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: labelColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildBidAction(
    BuildContext context,
    ExistingMatchBid? bid,
    bool userHasBid, {
    required bool completed,
    required bool scheduleLocked,
  }) {
    if (completed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'VIEW RESULTS',
          style: TextStyle(
            color: Colors.amber.shade300,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      );
    }

    if (userHasBid && bid != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.55)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, color: Colors.amber.shade400, size: 18),
                const SizedBox(width: 8),
                Text(
                  'LOCKED',
                  style: TextStyle(
                    color: Colors.amber.shade200,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'PICKED: ${pickedTeamDisplayName(match, bid)}',
            style: TextStyle(
              color: Colors.amber.shade200,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
            textAlign: TextAlign.end,
          ),
        ],
      );
    }

    if (scheduleLocked) {
      return Text(
        'LOCKED',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.24),
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      );
    }

    return ElevatedButton(
      onPressed: () {
        if (isMatchScheduleLocked(match)) return;
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (context) => PlaceBidScreen(match: match),
          ),
        );
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.neonGreen,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: const Text('BID NOW'),
    );
  }

  Widget _teamName(
    String? name,
    String? teamId,
    int side, {
    required bool alignEnd,
    bool highlightPick = false,
    bool highlightWinner = false,
    bool muted = false,
  }) {
    final label = (name == null || name.trim().isEmpty) ? 'TBD' : name.trim();
    final parts = label.split(' ');
    final visual = _teamVisualForCard(name, side);

    Color nameColor;
    FontWeight weight;
    if (muted) {
      nameColor = Colors.white54;
      weight = FontWeight.w600;
    } else if (highlightWinner) {
      nameColor = AppColors.neonGreen;
      weight = FontWeight.w900;
    } else if (highlightPick) {
      nameColor = Colors.amber.shade200;
      weight = FontWeight.w900;
    } else {
      nameColor = Colors.white;
      weight = FontWeight.w600;
    }

    final baseStyle = TextStyle(
      fontSize: 14,
      color: nameColor,
      fontWeight: weight,
      letterSpacing: 0.8,
    );

    final fallbackLogo = Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: muted ? Color.lerp(visual.bg, const Color(0xFF374151), 0.55) : visual.bg,
        borderRadius: BorderRadius.circular(6),
      ),
      alignment: Alignment.center,
      child: Icon(
        visual.icon,
        size: 22,
        color: muted ? Color.lerp(visual.iconColor, Colors.grey, 0.5) : visual.iconColor,
      ),
    );

    return Column(
      crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: highlightWinner ? const EdgeInsets.all(2) : EdgeInsets.zero,
          decoration: highlightWinner
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.neonGreen, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.neonGreen.withValues(alpha: 0.35),
                      blurRadius: 8,
                    ),
                  ],
                )
              : null,
          child: TeamLogoAsset(
            teamId: teamId,
            teamDisplayName: name,
            size: 36,
            borderRadius: 6,
            desaturate: muted,
            fallback: fallbackLogo,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            Flexible(
              child: Text(
                parts[0],
                style: baseStyle,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                textAlign: alignEnd ? TextAlign.end : TextAlign.start,
              ),
            ),
            if (highlightWinner) ...[
              const SizedBox(width: 4),
              Icon(Icons.check_circle, color: AppColors.neonGreen, size: 16),
            ],
          ],
        ),
        Text(
          parts.length > 1 ? parts[1] : '',
          style: baseStyle,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
          textAlign: alignEnd ? TextAlign.end : TextAlign.start,
        ),
      ],
    );
  }
}

class _TeamVisualForCard {
  const _TeamVisualForCard({
    required this.bg,
    required this.icon,
    required this.iconColor,
  });

  final Color bg;
  final IconData icon;
  final Color iconColor;
}

_TeamVisualForCard _teamVisualForCard(String? name, int side) {
  const palettes = <_TeamVisualForCard>[
    _TeamVisualForCard(bg: Color(0xFF064E3B), icon: Icons.sports_cricket, iconColor: Colors.white),
    _TeamVisualForCard(bg: Color(0xFFFEF3C7), icon: Icons.pets, iconColor: Color(0xFFEA580C)),
    _TeamVisualForCard(bg: Color(0xFF1E3A5F), icon: Icons.bolt, iconColor: Color(0xFF7DD3FC)),
    _TeamVisualForCard(bg: Color(0xFF4C1D95), icon: Icons.military_tech, iconColor: Color(0xFFE9D5FF)),
  ];
  final i = ((name ?? '').hashCode.abs() + side * 17) % palettes.length;
  return palettes[i];
}
