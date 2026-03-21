import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../bids/domain/entities/existing_match_bid.dart';
import '../../../bids/presentation/match_bid_labels.dart';
import '../../../match_schedule/domain/entities/match.dart';
import '../../../match_schedule/presentation/widgets/team_logo_asset.dart';

/// Upcoming match tile for the auction dashboard (status + countdown + teams + CTA).
class AuctionUpcomingMatchCard extends StatelessWidget {
  const AuctionUpcomingMatchCard({
    super.key,
    required this.match,
    required this.onEnterAuction,
    this.myBid,
  });

  final Match match;
  final VoidCallback onEnterAuction;

  /// When set, the user's team already bid — amber **LOCKED** and shows the picked side.
  final ExistingMatchBid? myBid;

  static const Color _cardBg = Color(0xFF0B1221);
  static const Color _cardBorder = Color(0xFF1E293B);
  static const Color _ctaText = Color(0xFF052E16);

  @override
  Widget build(BuildContext context) {
    final t1 = (match.team1 ?? 'TEAM 1').toUpperCase();
    final t2 = (match.team2 ?? 'TEAM 2').toUpperCase();
    final status = _statusPresentation(match);
    final scheduleLocked = isMatchScheduleLocked(match);
    final completed = isMatchCompleted(match);
    final winnerSide = matchCompletedWinnerSide(match);
    final bid = myBid;
    final userHasBid = bid != null;
    final pickedName = userHasBid ? pickedTeamDisplayName(match, bid) : '';
    final pickedSide = userHasBid ? pickedSideIndexForMatch(match, bid.matchBidTeamDocumentId) : -1;
    /// Dim card for schedule lock without bid (not when user bid, not when completed).
    final cardMuted = scheduleLocked && !userHasBid && !completed;

    final card = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardMuted ? const Color(0xFF12161F) : _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: completed
              ? Colors.yellow.withValues(alpha: 0.5)
              : (cardMuted ? const Color(0xFF2D3748) : _cardBorder),
          width: completed ? 1 : 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: status.chipFill,
                  borderRadius: BorderRadius.circular(20),
                  border: status.chipBorder,
                ),
                child: Text(
                  status.label,
                  style: TextStyle(
                    color: status.foreground,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              Flexible(
                child: Text(
                  completed
                      ? 'Final'
                      : userHasBid
                          ? 'Bid placed'
                          : (scheduleLocked ? 'Bidding closed' : _timeCaption(match)),
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    color: completed
                        ? Colors.amber.shade200
                        : userHasBid
                            ? Colors.amber.shade200
                            : (cardMuted ? Colors.grey[600] : Colors.grey[400]),
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    fontWeight: (userHasBid || completed) ? FontWeight.w600 : null,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: _buildTeamColumn(
                  t1,
                  match.team1Id,
                  match.team1,
                  0,
                  desaturate: scheduleLocked && !userHasBid && !completed,
                  highlightPick: pickedSide == 0,
                  highlightAmber: userHasBid,
                  highlightWinnerGreen: winnerSide == 0,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'VS',
                  style: TextStyle(
                    color: cardMuted ? Colors.grey[700] : Colors.grey[600],
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              Expanded(
                child: _buildTeamColumn(
                  t2,
                  match.team2Id,
                  match.team2,
                  1,
                  desaturate: scheduleLocked && !userHasBid && !completed,
                  highlightPick: pickedSide == 1,
                  highlightAmber: userHasBid,
                  highlightWinnerGreen: winnerSide == 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          if (completed)
            _buildCompletedCta()
          else if (userHasBid)
            _buildUserBidLockedCta(pickedName)
          else if (scheduleLocked)
            _buildLockedCtaPlaceholder()
          else
            Container(
              width: double.infinity,
              height: 55,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF4ADE80),
                    Color(0xFF166534),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
              child: ElevatedButton(
                onPressed: onEnterAuction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'ENTER AUCTION ROOM',
                  style: TextStyle(
                    color: _ctaText,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    return cardMuted ? Opacity(opacity: 0.58, child: card) : card;
  }

  static Widget _buildCompletedCta() {
    return Container(
      width: double.infinity,
      height: 55,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'VIEW RESULTS',
        style: TextStyle(
          color: Colors.amber.shade300,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
          fontSize: 14,
        ),
      ),
    );
  }

  /// Amber CTA when this user already placed a bid on the match.
  static Widget _buildUserBidLockedCta(String pickedTeamUpper) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: double.infinity,
          height: 55,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.withValues(alpha: 0.55)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, color: Colors.amber.shade400, size: 20),
              const SizedBox(width: 10),
              Text(
                'LOCKED',
                style: TextStyle(
                  color: Colors.amber.shade200,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'PICKED: $pickedTeamUpper',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.amber.shade200,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
      ],
    );
  }

  static Widget _buildLockedCtaPlaceholder() {
    return SizedBox(
      height: 55,
      child: Center(
        child: Text(
          'LOCKED',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.24),
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildTeamColumn(
    String displayName,
    String? teamId,
    String? teamNameForLogo,
    int side, {
    required bool desaturate,
    bool highlightPick = false,
    bool highlightAmber = false,
    bool highlightWinnerGreen = false,
  }) {
    final style = _teamVisual(displayName, side);
    final fallbackIcon = Icon(
      style.icon,
      color: desaturate ? Color.lerp(style.iconColor, Colors.grey, 0.5) : style.iconColor,
      size: 40,
    );
    final hasLogoAsset = teamLogoAssetPathForMatch(
          teamId: teamId,
          teamDisplayName: teamNameForLogo,
        ) !=
        null;
    final borderColor = highlightWinnerGreen
        ? AppColors.neonGreen
        : (highlightPick
            ? (highlightAmber ? Colors.amber.shade400 : const Color(0xFF4ADE80))
            : null);
    final shadowColor = highlightWinnerGreen
        ? AppColors.neonGreen
        : (highlightPick ? (highlightAmber ? Colors.amber : const Color(0xFF4ADE80)) : null);

    return Column(
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: !hasLogoAsset
                ? (desaturate ? Color.lerp(style.bg, const Color(0xFF374151), 0.55)! : style.bg)
                : Colors.black.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
            border: borderColor != null ? Border.all(color: borderColor, width: 2.5) : null,
            boxShadow: shadowColor != null
                ? [
                    BoxShadow(
                      color: shadowColor.withValues(alpha: 0.35),
                      blurRadius: 10,
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: TeamLogoAsset(
            teamId: teamId,
            teamDisplayName: teamNameForLogo,
            size: 64,
            borderRadius: 6,
            desaturate: desaturate,
            fallback: fallbackIcon,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                displayName,
                style: TextStyle(
                  color: desaturate
                      ? Colors.grey[500]
                      : (highlightWinnerGreen
                          ? AppColors.neonGreen
                          : (highlightPick && highlightAmber ? Colors.amber.shade200 : Colors.white)),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (highlightWinnerGreen) ...[
              const SizedBox(width: 4),
              Icon(Icons.check_circle, color: AppColors.neonGreen, size: 16),
            ],
          ],
        ),
      ],
    );
  }
}

class _StatusPresentation {
  const _StatusPresentation({
    required this.label,
    required this.chipFill,
    required this.foreground,
    this.chipBorder,
  });

  final String label;
  final Color chipFill;
  final Color foreground;
  final BoxBorder? chipBorder;
}

_StatusPresentation _statusPresentation(Match m) {
  final raw = (m.status ?? '').trim();
  final upper = raw.toUpperCase();

  if (upper.contains('LOCKED')) {
    return _StatusPresentation(
      label: 'LOCKED',
      chipFill: const Color(0xFF374151).withValues(alpha: 0.85),
      foreground: const Color(0xFF9CA3AF),
      chipBorder: Border.all(color: const Color(0xFF4B5563)),
    );
  }
  if (upper.contains('LIVE')) {
    return _StatusPresentation(
      label: 'LIVE',
      chipFill: const Color(0xFF7F1D1D).withValues(alpha: 0.45),
      foreground: const Color(0xFFFCA5A5),
      chipBorder: Border.all(color: const Color(0xFF991B1B).withValues(alpha: 0.6)),
    );
  }
  if (upper.contains('CLOSE') || upper.contains('COMPLETE') || upper.contains('FINISH')) {
    return _StatusPresentation(
      label: upper.isNotEmpty ? upper : 'CLOSED',
      chipFill: const Color(0xFF334155).withValues(alpha: 0.6),
      foreground: const Color(0xFF94A3B8),
    );
  }
  if (upper.contains('OPEN') || raw.isEmpty) {
    return _StatusPresentation(
      label: raw.isEmpty ? 'OPEN' : upper,
      chipFill: const Color(0xFF14532D).withValues(alpha: 0.3),
      foreground: const Color(0xFF4ADE80),
    );
  }
  return _StatusPresentation(
    label: upper,
    chipFill: const Color(0xFF1E3A5F).withValues(alpha: 0.5),
    foreground: const Color(0xFF93C5FD),
  );
}

class _TeamVisual {
  const _TeamVisual({
    required this.bg,
    required this.icon,
    required this.iconColor,
  });

  final Color bg;
  final IconData icon;
  final Color iconColor;
}

_TeamVisual _teamVisual(String name, int side) {
  const palettes = <_TeamVisual>[
    _TeamVisual(bg: Color(0xFF064E3B), icon: Icons.sports_cricket, iconColor: Colors.white),
    _TeamVisual(bg: Color(0xFFFEF3C7), icon: Icons.pets, iconColor: Color(0xFFEA580C)),
    _TeamVisual(bg: Color(0xFF1E3A5F), icon: Icons.bolt, iconColor: Color(0xFF7DD3FC)),
    _TeamVisual(bg: Color(0xFF4C1D95), icon: Icons.military_tech, iconColor: Color(0xFFE9D5FF)),
  ];
  final i = (name.hashCode.abs() + side * 17) % palettes.length;
  return palettes[i];
}

String _timeCaption(Match m) {
  final dt = m.matchDate;
  if (dt == null) return 'Schedule TBA';

  final now = DateTime.now();
  if (!dt.isAfter(now)) {
    final s = (m.status ?? '').toUpperCase();
    if (s.contains('LIVE')) return 'In progress';
    if (s.contains('OPEN')) return 'Match day';
    return 'Started';
  }

  final diff = dt.difference(now);
  if (diff.inMinutes < 1) return 'Starting soon';

  final totalMin = diff.inMinutes;
  final h = totalMin ~/ 60;
  final min = totalMin % 60;

  if (diff.inHours >= 48) {
    final days = diff.inDays;
    final hr = diff.inHours % 24;
    return 'Starts in ${days}d ${hr}h';
  }

  final hh = h.toString().padLeft(2, '0');
  final mm = min.toString().padLeft(2, '0');
  return 'Starts in ${hh}h ${mm}m';
}
