import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/app_snack_bars.dart';
import '../../../bids/domain/entities/existing_match_bid.dart';
import '../../../bids/presentation/match_bid_labels.dart';
import '../../../bids/domain/exceptions/insufficient_balance.dart';
import '../../domain/entities/match.dart';
import 'team_logo_asset.dart';

const _card = Color(0xFF1A1F21);
const _accent = Color(0xFF4CAF50);
const _predictionPanel = Color(0xFF15191C);

class AuctionBiddingPanel extends StatefulWidget {
  const AuctionBiddingPanel({
    super.key,
    required this.match,
    required this.team1Name,
    required this.team2Name,
    required this.team1Code,
    required this.team2Code,
    required this.team1Color,
    required this.team2Color,
    this.matchTeam1DocumentId,
    this.matchTeam2DocumentId,
    this.walletBalance,
    this.walletLoading = false,
    this.bidsTeam1 = 0,
    this.bidsTeam2 = 0,
    this.isAuthenticated = true,
    this.hasTeam = true,
    this.onPlaceBid,
    this.existingBid,
    this.existingBidLoading = false,
  });

  final Match match;
  final String team1Name;
  final String team2Name;
  final String team1Code;
  final String team2Code;
  final Color team1Color;
  final Color team2Color;

  /// `teams` document ids for side 1 / 2 — stored as `match_bid_id` when placing a bid.
  final String? matchTeam1DocumentId;
  final String? matchTeam2DocumentId;

  /// Logged-in user's team wallet (`teams.balance`). Null if unknown or no team.
  final double? walletBalance;
  final bool walletLoading;

  /// Live counts from `bids` where `match_bid_id` matches each side's team document id.
  final int bidsTeam1;
  final int bidsTeam2;

  final bool isAuthenticated;
  final bool hasTeam;

  /// [payoutOdds] is the multiplier locked for this pick (stored on the bid as `payout_odds`).
  final Future<void> Function(double bidAmount, String matchBidTeamDocumentId, double payoutOdds)? onPlaceBid;

  /// If set, this team already has a `bids` row for this match — UI is read-only.
  final ExistingMatchBid? existingBid;

  /// True while checking Firestore for an existing bid (avoid duplicate submit race).
  final bool existingBidLoading;

  @override
  State<AuctionBiddingPanel> createState() => _AuctionBiddingPanelState();
}

class _AuctionBiddingPanelState extends State<AuctionBiddingPanel> {
  int _selectedTeam = 0;
  late double _bidAmount;
  static const double _step = 10;
  bool _placing = false;
  Timer? _cutoffTicker;

  Match get _m => widget.match;

  double get _minBid {
    final r = _m.bidRange;
    if (r == null || r.isEmpty) return 50;
    return r.reduce((a, b) => a < b ? a : b);
  }

  double get _maxBid {
    final r = _m.bidRange;
    if (r == null || r.isEmpty) return 500;
    return r.reduce((a, b) => a > b ? a : b);
  }

  /// Upper bound for the stepper: match cap and available wallet when known.
  double get _effectiveMaxBid {
    final cap = _maxBid;
    final w = widget.walletBalance;
    if (w == null) return cap;
    return math.min(cap, w);
  }

  bool get _hasValidBidRange => _effectiveMaxBid >= _minBid;

  String? get _selectedMatchBidTeamDocumentId {
    if (_selectedTeam == 0) return widget.matchTeam1DocumentId?.trim();
    return widget.matchTeam2DocumentId?.trim();
  }

  bool get _sideIdsOk {
    final a = widget.matchTeam1DocumentId?.trim();
    final b = widget.matchTeam2DocumentId?.trim();
    return a != null && a.isNotEmpty && b != null && b.isNotEmpty;
  }

  /// Payout multiplier for one side — Firestore `odds` is `[team1, team2]`.
  double _oddsForSide(int sideIndex) {
    assert(sideIndex == 0 || sideIndex == 1);
    final list = _m.odds;
    if (list != null && list.length >= 2) {
      final o = list[sideIndex];
      if (o > 0) return o;
    } else if (list != null && list.length == 1 && list[0] > 0) {
      return list[0];
    }
    return 2.5;
  }

  /// Payout multiplier for the currently selected side.
  double get _decimalOdds => _oddsForSide(_selectedTeam);

  double get _potentialReturn => _bidAmount * _decimalOdds;

  @override
  void initState() {
    super.initState();
    final mid = (_minBid + _maxBid) / 2;
    final em = _effectiveMaxBid;
    _bidAmount = em >= _minBid ? mid.clamp(_minBid, em) : _minBid;
    if (widget.match.matchDate != null) {
      _cutoffTicker = Timer.periodic(const Duration(seconds: 30), (_) {
        if (!mounted) return;
        setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _cutoffTicker?.cancel();
    super.dispose();
  }

  bool get _selectionValid {
    final id = _selectedMatchBidTeamDocumentId;
    return id != null && id.isNotEmpty;
  }

  bool get _bidAlreadyPlaced => widget.existingBid != null;

  /// Cannot change side: already bid, or within 30 min of match start.
  bool get _pickFrozen => _bidAlreadyPlaced || isMatchBiddingCutoffReached(widget.match);

  bool get _bidAmountLocked => _pickFrozen;

  /// Grey CTA (locked / closed).
  bool get _bidCtaInactive => _bidAlreadyPlaced || isMatchBiddingCutoffReached(widget.match);

  bool get _confirmEnabled {
    if (widget.existingBidLoading) return false;
    if (_bidAlreadyPlaced) return false;
    if (isMatchBiddingCutoffReached(widget.match)) return false;
    if (_placing) return false;
    if (!widget.isAuthenticated || !widget.hasTeam) return false;
    if (widget.onPlaceBid == null) return false;
    if (!_sideIdsOk || !_selectionValid) return false;
    if (!_hasValidBidRange) return false;
    final w = widget.walletBalance;
    if (w != null && _bidAmount > w) return false;
    if (widget.walletLoading) return false;
    return true;
  }

  @override
  void didUpdateWidget(AuctionBiddingPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.existingBid != oldWidget.existingBid) {
      final e = widget.existingBid;
      if (e != null) {
        final t1 = widget.matchTeam1DocumentId?.trim();
        final t2 = widget.matchTeam2DocumentId?.trim();
        var team = _selectedTeam;
        if (e.matchBidTeamDocumentId == t1) {
          team = 0;
        } else if (e.matchBidTeamDocumentId == t2) {
          team = 1;
        }
        final amt = e.bidAmount > 0
            ? e.bidAmount.clamp(_minBid, _maxBid)
            : _bidAmount;
        setState(() {
          _selectedTeam = team;
          _bidAmount = amt;
        });
      }
    }
    if (oldWidget.walletBalance != widget.walletBalance || oldWidget.match != widget.match) {
      if (_bidAlreadyPlaced) return;
      final max = _effectiveMaxBid;
      final min = _minBid;
      if (max >= min && (_bidAmount > max || _bidAmount < min)) {
        setState(() => _bidAmount = _bidAmount.clamp(min, max));
      }
    }
  }

  void _nudge(double delta) {
    setState(() {
      _bidAmount = (_bidAmount + delta).clamp(_minBid, _effectiveMaxBid);
    });
  }

  Future<void> _confirmBid() async {
    final cb = widget.onPlaceBid;
    if (cb == null || _placing) return;
    final matchBidId = _selectedMatchBidTeamDocumentId;
    if (matchBidId == null || matchBidId.isEmpty) return;
    if (!_hasValidBidRange) return;
    if (widget.walletBalance != null && _bidAmount > widget.walletBalance!) return;

    setState(() => _placing = true);
    try {
      await cb(_bidAmount, matchBidId, _decimalOdds);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        AppSnackBars.success(
          'Bid confirmed: ₹${_bidAmount.round()} on ${_selectedTeam == 0 ? widget.team1Code : widget.team2Code} @ ${_decimalOdds.toStringAsFixed(2)}x',
        ),
      );
    } on InsufficientBalanceException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        AppSnackBars.warning('Insufficient balance for this bid.'),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        AppSnackBars.warning('Could not place bid: $e'),
      );
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  String _limitLabel() {
    final lo = _minBid.round();
    final hi = _effectiveMaxBid.round();
    return 'LIMIT: $lo - $hi';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildPredictionSection(),
        const SizedBox(height: 20),
        _buildBidInputSection(),
        const SizedBox(height: 20),
        _buildWalletSection(),
        const SizedBox(height: 20),
        _buildMarketSentimentSection(),
      ],
    );
  }

  Widget _buildPredictionSection() {
    final team1Name = widget.team1Name;
    final team2Name = widget.team2Name;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: _predictionPanel,
        borderRadius: BorderRadius.all(Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'PLACE YOUR\nPREDICTION',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Icon(Icons.trending_up, color: Colors.green.withValues(alpha: 0.5), size: 40),
            ],
          ),
          const SizedBox(height: 20),
          const Text('PREDICT WINNER', style: TextStyle(color: Colors.grey, fontSize: 10)),
          if (_bidAlreadyPlaced) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  Icon(Icons.lock_outline, color: Colors.amber.shade200, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Your pick is set for this match. You cannot change it.',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 11, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (isMatchBiddingCutoffReached(widget.match)) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                children: [
                  Icon(Icons.schedule, color: Colors.orange.shade200, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Bidding closes 30 minutes before match start. New bids are no longer accepted.',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 11, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          _buildSelectionButton(
            team1Name.toUpperCase(),
            _m.team1Id,
            _m.team1,
            widget.team1Color,
            _oddsForSide(0),
            _selectedTeam == 0,
            _pickFrozen ? null : () => setState(() => _selectedTeam = 0),
          ),
          const SizedBox(height: 12),
          _buildSelectionButton(
            team2Name.toUpperCase(),
            _m.team2Id,
            _m.team2,
            widget.team2Color,
            _oddsForSide(1),
            _selectedTeam == 1,
            _pickFrozen ? null : () => setState(() => _selectedTeam = 1),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSelectionButton(
    String name,
    String? matchTeamId,
    String? matchTeamDisplayName,
    Color fallbackColor,
    double decimalOdds,
    bool isSelected,
    VoidCallback? onTap,
  ) {
    final locked = onTap == null;
    final borderColor = locked
        ? (isSelected ? _accent.withValues(alpha: 0.85) : Colors.white.withValues(alpha: 0.06))
        : (isSelected ? _accent : Colors.white10);
    return Opacity(
      opacity: locked && !isSelected ? 0.45 : 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 2),
            color: isSelected ? Colors.transparent : Colors.white.withValues(alpha: 0.05),
          ),
          child: Row(
          children: [
            SizedBox(
              width: 30,
              height: 30,
              child: TeamLogoAsset(
                teamId: matchTeamId,
                teamDisplayName: matchTeamDisplayName,
                size: 30,
                borderRadius: 4,
                fallback: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: fallbackColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    name.isNotEmpty ? name[0] : '?',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
            Text(
              '${decimalOdds.toStringAsFixed(2)}x',
              style: TextStyle(
                color: Colors.green.withValues(alpha: 0.85),
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 8),
            if (isSelected) const Icon(Icons.check_circle, color: _accent, size: 20),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildBidInputSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _bidAlreadyPlaced
                    ? 'YOUR BID (₹) — LOCKED'
                    : (isMatchBiddingCutoffReached(widget.match) ? 'BID AMOUNT (₹) — CLOSED' : 'BID AMOUNT (₹)'),
                style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.yellow.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _bidAlreadyPlaced
                      ? 'PLACED'
                      : (isMatchBiddingCutoffReached(widget.match) ? 'CLOSED' : _limitLabel()),
                  style: const TextStyle(color: Colors.orangeAccent, fontSize: 9),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(12)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _bidAmount.round().toString(),
                  style: const TextStyle(color: _accent, fontSize: 28, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: !_bidAmountLocked && _bidAmount > _minBid ? () => _nudge(-_step) : null,
                      icon: Icon(Icons.remove, color: _bidAmountLocked ? Colors.grey.shade800 : Colors.grey),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: !_bidAmountLocked && _bidAmount < _effectiveMaxBid ? () => _nudge(_step) : null,
                      icon: Icon(Icons.add, color: _bidAmountLocked ? Colors.grey.shade800 : Colors.white),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'POTENTIAL RETURN',
            style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withValues(alpha: 0.1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '₹ ${_potentialReturn.toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: _accent, borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    '${_decimalOdds.toStringAsFixed(2)}x PAYOUT',
                    style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            height: 60,
            decoration: BoxDecoration(
              gradient: _bidCtaInactive
                  ? null
                  : const LinearGradient(colors: [Color(0xFF81C784), Color(0xFF4CAF50)]),
              color: _bidCtaInactive ? const Color(0xFF2C3235) : null,
              borderRadius: BorderRadius.circular(16),
              boxShadow: _bidCtaInactive
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.green.withValues(alpha: 0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
            ),
            child: ElevatedButton.icon(
              onPressed: _confirmEnabled ? _confirmBid : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                disabledBackgroundColor: Colors.transparent,
                disabledForegroundColor: Colors.white54,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: _placing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : Icon(
                      _bidCtaInactive ? Icons.lock : Icons.verified,
                      color: _bidCtaInactive ? Colors.white54 : Colors.black,
                      size: 20,
                    ),
              label: Text(
                _bidAlreadyPlaced
                    ? 'BID ALREADY PLACED'
                    : (isMatchBiddingCutoffReached(widget.match)
                        ? 'BIDDING CLOSED'
                        : (_placing ? 'PLACING…' : 'CONFIRM BID')),
                style: TextStyle(
                  color: _bidCtaInactive ? Colors.white54 : Colors.black,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletSection() {
    final w = widget.walletBalance;
    final loading = widget.walletLoading;
    String balanceLine;
    String subline = 'Available for bidding';
    if (!widget.isAuthenticated) {
      balanceLine = '—';
      subline = 'Sign in to use your team wallet';
    } else if (!widget.hasTeam) {
      balanceLine = '—';
      subline = 'No team linked to your profile';
    } else if (loading) {
      balanceLine = '…';
    } else if (w != null) {
      balanceLine = '₹${w.toStringAsFixed(2)}';
    } else {
      balanceLine = '—';
    }

    final progress = (!loading && w != null && w > 0)
        ? (math.min(_bidAmount, w) / w).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text(
                'COMMAND CENTER WALLET',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              SizedBox(width: 8),
              Icon(Icons.grid_view_rounded, color: Colors.white, size: 14),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(balanceLine, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                  Text(subline, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
              Container(
                height: 45,
                width: 45,
                decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.add, color: _accent),
              ),
            ],
          ),
          if (widget.isAuthenticated && widget.hasTeam && w != null && w > 0) ...[
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: Colors.white10,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.yellow.shade700),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'THIS BID: ₹${_bidAmount.toStringAsFixed(0)}',
                  style: const TextStyle(color: Colors.grey, fontSize: 10),
                ),
                Text(
                  'BALANCE: ₹${w.toStringAsFixed(0)}',
                  style: const TextStyle(color: Colors.grey, fontSize: 10),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMarketSentimentSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(24)),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'MARKET SENTIMENT',
                style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  Icon(Icons.circle, color: Colors.green, size: 8),
                  SizedBox(width: 4),
                  Text('LIVE', style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          _sentimentRow(
            teamIdLabel: _sentimentTeamIdLabel(widget.match.team1Id, widget.team1Code),
            bidCount: '${widget.bidsTeam1}',
            accentColor: widget.team1Color,
            matchTeamId: widget.match.team1Id,
            matchTeamDisplayName: widget.match.team1,
          ),
          const SizedBox(height: 16),
          _sentimentRow(
            teamIdLabel: _sentimentTeamIdLabel(widget.match.team2Id, widget.team2Code),
            bidCount: '${widget.bidsTeam2}',
            accentColor: widget.team2Color,
            matchTeamId: widget.match.team2Id,
            matchTeamDisplayName: widget.match.team2,
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(12)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, color: Colors.yellow, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'If your pick wins: payout = stake × ${_decimalOdds.toStringAsFixed(2)}.',
                    style: const TextStyle(color: Colors.white70, fontSize: 10, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Prefer Firestore `team_*_id` (e.g. RR, MI); fall back to display code.
  static String _sentimentTeamIdLabel(String? teamId, String codeFallback) {
    final t = teamId?.trim();
    if (t != null && t.isNotEmpty) return t.toUpperCase();
    return codeFallback.length > 6 ? codeFallback.substring(0, 6) : codeFallback;
  }

  Widget _sentimentRow({
    required String teamIdLabel,
    required String bidCount,
    required Color accentColor,
    required String? matchTeamId,
    required String? matchTeamDisplayName,
  }) {
    final chip = teamIdLabel.length > 3 ? teamIdLabel.substring(0, 3) : teamIdLabel;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        TeamLogoAsset(
          teamId: matchTeamId,
          teamDisplayName: matchTeamDisplayName,
          size: 36,
          borderRadius: 8,
          fallback: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              chip,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            teamIdLabel,
            style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
        Text(
          bidCount,
          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
