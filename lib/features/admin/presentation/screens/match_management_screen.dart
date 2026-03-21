import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../match_schedule/domain/entities/match.dart';
import '../../../match_schedule/domain/repositories/match_schedule_repository.dart';
import '../../../teams/domain/entities/team.dart';
import '../../../teams/domain/repositories/team_repository.dart';
import '../../../users/data/datasources/users_firestore_data_source.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_snack_bars.dart';
import '../../../../app/widgets/auction_command_app_bar.dart';

/// Admin-only: create and edit matches in Firestore `matches`. [users] `admin: true` gates access.
class MatchManagementScreen extends StatefulWidget {
  const MatchManagementScreen({
    super.key,
    required this.matchScheduleRepository,
    required this.teamRepository,
    required this.usersDataSource,
  });

  final MatchScheduleRepository matchScheduleRepository;
  final TeamRepository teamRepository;
  final UsersFirestoreDataSource usersDataSource;

  @override
  State<MatchManagementScreen> createState() => _MatchManagementScreenState();
}

class _MatchManagementScreenState extends State<MatchManagementScreen> {
  final _matchNoController = TextEditingController();
  final _venueController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  /// Only teams with `tournament == IPL` in Firestore.
  static const String _iplTournament = 'IPL';

  static const List<String> _statusChoices = ['OPEN', 'LOCKED', 'COMPLETED'];

  static const List<String> _tournamentChoices = ['IPL'];
  static const List<int> _seasonChoices = [2024, 2025, 2026, 2027, 2028];

  /// UI keys → Firestore `result`: `null` when pending.
  static const List<String> _resultUiKeys = ['pending', 'team_1', 'team_2', 'draw'];

  /// Min / max bid (₹): **100 … 2000** in steps of **100**.
  static final List<double> _bidPresets = List<double>.generate(
    20,
    (i) => (100 * (i + 1)).toDouble(),
  );

  /// Payout multipliers **1.00× … 15.00×** in steps of **0.25**; persisted as `odds`: `[home, away]`.
  static final List<double> _oddsChoices = List<double>.generate(
    57,
    (i) => double.parse((1.0 + i * 0.25).toStringAsFixed(2)),
  );
  static const double _defaultOdds = 2.0;

  List<Team> _teams = [];
  Team? _team1;
  Team? _team2;
  double _selectedOddsHome = _defaultOdds;
  double _selectedOddsAway = _defaultOdds;
  DateTime? _scheduledAt;
  String? _editingDocumentId;
  /// IPL team venues; match venue may be extra ([_orphanVenue]).
  String? _orphanVenue;
  String? _selectedVenue;
  String _selectedStatus = 'OPEN';
  String _selectedTournament = 'IPL';
  int _selectedSeason = 2026;
  String _selectedResultKey = 'pending';
  double _bidMin = 100;
  double _bidMax = 2000;
  bool _loadingTeams = true;
  bool _submitting = false;

  static const _surface = Color(0xFF161B22);
  static const _fieldFill = Color(0xFF21262D);

  @override
  void initState() {
    super.initState();
    _loadTeams();
  }

  Future<void> _loadTeams() async {
    try {
      final list = await widget.teamRepository.getAllTeams(tournament: _iplTournament);
      list.sort((a, b) => (a.name ?? a.teamId ?? '').compareTo(b.name ?? b.teamId ?? ''));
      if (mounted) {
        setState(() {
          _teams = list;
          _loadingTeams = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingTeams = false);
    }
  }

  /// Same franchise / squad — compares `team_id`, then document id, then normalized name.
  bool _isSameTeam(Team a, Team b) {
    final idA = a.teamId?.trim();
    final idB = b.teamId?.trim();
    if (idA != null && idA.isNotEmpty && idB != null && idB.isNotEmpty) {
      return idA == idB;
    }
    final docA = a.documentId.trim();
    final docB = b.documentId.trim();
    if (docA.isNotEmpty && docB.isNotEmpty) return docA == docB;
    final nA = a.name?.trim();
    final nB = b.name?.trim();
    if (nA != null && nA.isNotEmpty && nB != null && nB.isNotEmpty) {
      return nA.toLowerCase() == nB.toLowerCase();
    }
    return false;
  }

  List<Team> get _teamsForAway {
    final home = _team1;
    if (home == null) return _teams;
    return _teams.where((t) => !_isSameTeam(t, home)).toList();
  }

  /// Resolves [ _team2 ] to an item present in the away dropdown list (same logical team).
  Team? get _effectiveAwayDropdownValue {
    final away = _team2;
    if (away == null) return null;
    for (final t in _teamsForAway) {
      if (_isSameTeam(t, away)) return t;
    }
    return null;
  }

  double _nearestOddsChoice(double? value) {
    if (value == null || value <= 0) return _defaultOdds;
    var best = _oddsChoices.first;
    var bestDiff = (best - value).abs();
    for (final o in _oddsChoices) {
      final d = (o - value).abs();
      if (d < bestDiff) {
        bestDiff = d;
        best = o;
      }
    }
    return best;
  }

  /// Prefer Firestore `venue`, then `home_ground` on the team document.
  String? _venueFromTeam(Team t) {
    final v = t.venue?.trim();
    if (v != null && v.isNotEmpty) return v;
    final h = t.homeGround?.trim();
    if (h != null && h.isNotEmpty) return h;
    return null;
  }

  List<String> _venuesFromIplTeams() {
    final set = <String>{};
    for (final t in _teams) {
      final v = _venueFromTeam(t);
      if (v != null) set.add(v);
    }
    final list = set.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  List<String> get _venueDropdownItems {
    final base = _venuesFromIplTeams();
    if (_orphanVenue != null &&
        _orphanVenue!.isNotEmpty &&
        !base.contains(_orphanVenue)) {
      return [...base, _orphanVenue!]
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    }
    return base;
  }

  String? get _effectiveVenueDropdownValue {
    final v = _selectedVenue;
    if (v == null) return null;
    return _venueDropdownItems.contains(v) ? v : null;
  }

  String _normalizeStatus(String? s) {
    final u = (s ?? '').trim().toUpperCase();
    if (_statusChoices.contains(u)) return u;
    return 'OPEN';
  }

  String _resultUiFromMatch(Match m) {
    final r = m.result?.trim().toLowerCase() ?? '';
    if (r.isEmpty) return 'pending';
    if (r == 'team_1' || r == 'team1') return 'team_1';
    if (r == 'team_2' || r == 'team2') return 'team_2';
    if (r == 'draw') return 'draw';
    return 'pending';
  }

  String? _resultForFirestore() =>
      _selectedResultKey == 'pending' ? null : _selectedResultKey;

  /// Result dropdown shows selected home/away names (not generic “Team 1 wins”).
  String _resultDropdownLabel(String key) {
    switch (key) {
      case 'pending':
        return 'Pending';
      case 'team_1':
        final n = _team1?.name?.trim();
        return (n != null && n.isNotEmpty) ? n : 'Home side';
      case 'team_2':
        final n = _team2?.name?.trim();
        return (n != null && n.isNotEmpty) ? n : 'Away side';
      case 'draw':
        return 'Draw';
      default:
        return key;
    }
  }

  double _nearestBidPreset(double? v) {
    if (v == null || v <= 0) return _bidPresets.first;
    var best = _bidPresets.first;
    var bestDiff = (best - v).abs();
    for (final p in _bidPresets) {
      final d = (p - v).abs();
      if (d < bestDiff) {
        bestDiff = d;
        best = p;
      }
    }
    return best;
  }

  void _onBidMinChanged(double? v) {
    if (v == null) return;
    setState(() {
      _bidMin = v;
      if (_bidMin >= _bidMax) {
        final greater = _bidPresets.where((x) => x > _bidMin).toList();
        if (greater.isNotEmpty) {
          _bidMax = greater.first;
        } else {
          _bidMax = _bidPresets.last;
          _bidMin = _bidPresets.length >= 2 ? _bidPresets[_bidPresets.length - 2] : _bidPresets.first;
        }
      }
    });
  }

  void _onBidMaxChanged(double? v) {
    if (v == null) return;
    setState(() {
      _bidMax = v;
      if (_bidMax <= _bidMin) {
        final lesser = _bidPresets.where((x) => x < _bidMax).toList();
        if (lesser.isNotEmpty) {
          _bidMin = lesser.last;
        } else {
          _bidMin = _bidPresets.first;
          _bidMax = _bidPresets.length >= 2 ? _bidPresets[1] : _bidPresets.last;
        }
      }
    });
  }

  @override
  void dispose() {
    _matchNoController.dispose();
    _venueController.dispose();
    super.dispose();
  }

  void _clearForm() {
    setState(() {
      _editingDocumentId = null;
      _matchNoController.clear();
      _venueController.clear();
      _orphanVenue = null;
      _selectedVenue = null;
      _selectedStatus = 'OPEN';
      _selectedTournament = 'IPL';
      _selectedSeason = 2026;
      _selectedResultKey = 'pending';
      _bidMin = 100;
      _bidMax = 2000;
      _scheduledAt = null;
      _team1 = null;
      _team2 = null;
      _selectedOddsHome = _defaultOdds;
      _selectedOddsAway = _defaultOdds;
    });
  }

  void _beginEdit(Match m) {
    Team? find(String? id, String? name) {
      if (id != null && id.isNotEmpty) {
        for (final t in _teams) {
          if (t.teamId == id) return t;
        }
      }
      if (name != null && name.isNotEmpty) {
        for (final t in _teams) {
          if (t.name == name) return t;
        }
      }
      return null;
    }

    setState(() {
      _editingDocumentId = m.documentId;
      _matchNoController.text = m.matchNo ?? '';
      _venueController.clear();
      final fromTeams = _venuesFromIplTeams();
      final vn = m.venue?.trim();
      _orphanVenue =
          (vn != null && vn.isNotEmpty && !fromTeams.contains(vn)) ? vn : null;
      _selectedVenue = (vn != null && vn.isNotEmpty) ? vn : null;
      _selectedStatus = _normalizeStatus(m.status);
      _selectedTournament =
          (m.tournament != null && m.tournament!.trim().isNotEmpty)
              ? m.tournament!.trim()
              : 'IPL';
      if (!_tournamentChoices.contains(_selectedTournament)) {
        _selectedTournament = 'IPL';
      }
      _selectedSeason = m.season ?? 2026;
      if (!_seasonChoices.contains(_selectedSeason)) {
        _selectedSeason = 2026;
      }
      _selectedResultKey = _resultUiFromMatch(m);
      final br = m.bidRange;
      if (br != null && br.length >= 2) {
        _bidMin = _nearestBidPreset(br[0]);
        _bidMax = _nearestBidPreset(br[1]);
        if (_bidMin >= _bidMax) {
          _bidMin = _bidPresets.first;
          _bidMax = _bidPresets.last;
        }
      } else {
        _bidMin = 100;
        _bidMax = 2000;
      }
      if (_venueDropdownItems.isEmpty && vn != null && vn.isNotEmpty) {
        _venueController.text = vn;
      }
      _scheduledAt = m.matchDate ?? m.bidEndTime;
      _team1 = find(m.team1Id, m.team1);
      _team2 = find(m.team2Id, m.team2);
      final list = m.odds;
      if (list != null && list.length >= 2) {
        _selectedOddsHome = _nearestOddsChoice(list[0]);
        _selectedOddsAway = _nearestOddsChoice(list[1]);
      } else if (list != null && list.isNotEmpty) {
        _selectedOddsHome = _nearestOddsChoice(list[0]);
        _selectedOddsAway = _nearestOddsChoice(list[0]);
      } else {
        _selectedOddsHome = _defaultOdds;
        _selectedOddsAway = _defaultOdds;
      }
    });
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final initial = _scheduledAt ?? now;
    final d = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initial.hour, minute: initial.minute),
    );
    if (t == null || !mounted) return;
    setState(() {
      _scheduledAt = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    });
  }

  String _scheduleLabel() {
    final d = _scheduledAt;
    if (d == null) return 'Select date and time';
    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    final m = months[d.month - 1];
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$m ${d.day}, ${d.year} | $hh:$mm';
  }

  String _teamCode(Team? t) {
    final id = t?.teamId?.trim();
    if (id != null && id.length >= 3) return id.substring(0, 3).toUpperCase();
    final n = t?.name?.trim();
    if (n == null || n.length < 3) return '—';
    return n.substring(0, 3).toUpperCase();
  }

  Team? _findTeamByMatchSide(String? teamId, String? teamName) {
    if (teamId != null && teamId.isNotEmpty) {
      for (final t in _teams) {
        if (t.teamId == teamId) return t;
      }
    }
    if (teamName != null && teamName.isNotEmpty) {
      for (final t in _teams) {
        if (t.name == teamName) return t;
      }
    }
    return null;
  }

  String _codeForMatch(String? teamId, String? teamName) =>
      _teamCode(_findTeamByMatchSide(teamId, teamName));

  String _formatCardSchedule(DateTime? d) {
    if (d == null) return 'TBD';
    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    final m = months[d.month - 1];
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$m ${d.day}, ${d.year} | $hh:$mm';
  }

  Future<void> _confirmSchedule() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;
    final t1 = _team1;
    final t2 = _team2;
    if (t1 == null || t2 == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppSnackBars.warning('Select both teams'),
      );
      return;
    }
    if (_isSameTeam(t1, t2)) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppSnackBars.warning('A team cannot play itself — pick two different squads'),
      );
      return;
    }
    final when = _scheduledAt;
    if (when == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppSnackBars.warning('Pick date and time'),
      );
      return;
    }

    final name1 = t1.name ?? t1.teamId ?? 'Team 1';
    final name2 = t2.name ?? t2.teamId ?? 'Team 2';
    // Persist Firestore document ids so `team_1_id` / `team_2_id` match `bids.match_bid_id` (picked side).
    final id1 = t1.documentId.trim().isNotEmpty ? t1.documentId.trim() : (t1.teamId ?? '');
    final id2 = t2.documentId.trim().isNotEmpty ? t2.documentId.trim() : (t2.teamId ?? '');

    final odds = <double>[_selectedOddsHome, _selectedOddsAway];

    final venueItems = _venueDropdownItems;
    late final String venueStr;
    if (venueItems.isNotEmpty) {
      final pick = _effectiveVenueDropdownValue ?? _selectedVenue;
      if (pick == null || pick.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppSnackBars.warning('Select a venue'),
        );
        return;
      }
      venueStr = pick.trim();
    } else {
      venueStr = _venueController.text.trim();
      if (venueStr.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppSnackBars.warning('Enter a venue (no venues on IPL team documents yet)'),
        );
        return;
      }
    }

    if (_bidMin >= _bidMax) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppSnackBars.warning('Bid range: minimum must be less than maximum'),
      );
      return;
    }
    final bidRange = <double>[_bidMin, _bidMax];
    final resultFs = _resultForFirestore();

    setState(() => _submitting = true);
    try {
      if (_editingDocumentId != null) {
        await widget.matchScheduleRepository.updateMatch(
          documentId: _editingDocumentId!,
          matchNo: _matchNoController.text.trim(),
          matchDate: when,
          venue: venueStr,
          team1Name: name1,
          team1Id: id1,
          team2Name: name2,
          team2Id: id2,
          odds: odds,
          bidRange: bidRange,
          status: _selectedStatus,
          tournament: _selectedTournament,
          season: _selectedSeason,
          result: resultFs,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            AppSnackBars.success('Fixture updated'),
          );
        }
      } else {
        await widget.matchScheduleRepository.createMatch(
          matchNo: _matchNoController.text.trim(),
          matchDate: when,
          venue: venueStr,
          team1Name: name1,
          team1Id: id1,
          team2Name: name2,
          team2Id: id2,
          odds: odds,
          bidRange: bidRange,
          status: _selectedStatus,
          tournament: _selectedTournament,
          season: _selectedSeason,
          result: resultFs,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            AppSnackBars.success('Match scheduled'),
          );
        }
      }
      _clearForm();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppSnackBars.warning('Failed: $e'),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('Not signed in')),
      );
    }

    return StreamBuilder<bool>(
      stream: widget.usersDataSource.watchIsAdmin(uid),
      builder: (context, adminSnap) {
        if (adminSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.scaffoldBackground,
            appBar: AuctionCommandAppBar(
              backgroundColor: Colors.transparent,
              accentColor: AppColors.neonGreen,
            ),
            body: Center(child: CircularProgressIndicator(color: AppColors.neonGreen)),
          );
        }
        if (adminSnap.data != true) {
          return Scaffold(
            backgroundColor: AppColors.scaffoldBackground,
            appBar: const AuctionCommandAppBar(
              backgroundColor: Colors.transparent,
              accentColor: AppColors.neonGreen,
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Admin access only. Set users/$uid field admin: true in Firestore.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[400], fontSize: 15),
                ),
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: AppColors.scaffoldBackground,
          appBar: const AuctionCommandAppBar(
            backgroundColor: Colors.transparent,
            accentColor: AppColors.neonGreen,
          ),
          body: _loadingTeams
              ? const Center(child: CircularProgressIndicator(color: AppColors.neonGreen))
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        Text(
                          _editingDocumentId == null ? 'MATCH\nMANAGEMENT' : 'EDIT\nFIXTURE',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            height: 1.1,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Schedule, edit, and finalize tournament fixtures from the centralized command center.',
                          style: TextStyle(color: Colors.grey[400], fontSize: 14),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.neonGreen,
                            foregroundColor: Colors.black,
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: _clearForm,
                          child: const Text('+ ADD NEW MATCH', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(height: 40),
                        _buildCreateFixtureForm(),
                        const SizedBox(height: 40),
                        const Text(
                          'LIVE & UPCOMING FIXTURES',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 20),
                        StreamBuilder<List<Match>>(
                          stream: widget.matchScheduleRepository.watchMatches(),
                          builder: (context, snap) {
                            if (snap.hasError) {
                              return Text('Error: ${snap.error}', style: const TextStyle(color: Colors.redAccent));
                            }
                            final list = snap.data ?? [];
                            if (list.isEmpty) {
                              return Text(
                                'No matches yet.',
                                style: TextStyle(color: Colors.grey[500]),
                              );
                            }
                            return Column(
                              children: [
                                for (final m in list)
                                  _MatchFixtureCard(
                                    match: m,
                                    teamCode1: _codeForMatch(m.team1Id, m.team1),
                                    teamCode2: _codeForMatch(m.team2Id, m.team2),
                                    schedule: _formatCardSchedule(m.matchDate ?? m.bidEndTime),
                                    odds: m.odds,
                                    onEdit: () => _beginEdit(m),
                                  ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildCreateFixtureForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.calendar_today, color: AppColors.neonGreen, size: 18),
              SizedBox(width: 8),
              Text(
                'CREATE FIXTURE',
                style: TextStyle(color: AppColors.neonGreen, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildLabel('MATCH NUMBER'),
          TextFormField(
            controller: _matchNoController,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration('e.g. M-104'),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Required';
              return null;
            },
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('TOURNAMENT'),
                    InputDecorator(
                      decoration: _inputDecoration('Tournament'),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          dropdownColor: _surface,
                          value: _tournamentChoices.contains(_selectedTournament)
                              ? _selectedTournament
                              : 'IPL',
                          items: _tournamentChoices
                              .map(
                                (t) => DropdownMenuItem(
                                  value: t,
                                  child: Text(
                                    t,
                                    style: const TextStyle(color: Colors.white, fontSize: 14),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (t) {
                            if (t != null) setState(() => _selectedTournament = t);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('SEASON'),
                    InputDecorator(
                      decoration: _inputDecoration('Year'),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          isExpanded: true,
                          dropdownColor: _surface,
                          value: _seasonChoices.contains(_selectedSeason)
                              ? _selectedSeason
                              : 2026,
                          items: _seasonChoices
                              .map(
                                (y) => DropdownMenuItem(
                                  value: y,
                                  child: Text(
                                    '$y',
                                    style: const TextStyle(color: Colors.white, fontSize: 14),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (y) {
                            if (y != null) setState(() => _selectedSeason = y);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildLabel('SCHEDULE (DATE & TIME)'),
          InkWell(
            onTap: _pickDateTime,
            borderRadius: BorderRadius.circular(8),
            child: InputDecorator(
              decoration: _inputDecoration(_scheduleLabel()),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _scheduleLabel(),
                      style: TextStyle(
                        color: _scheduledAt == null ? Colors.white54 : Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const Icon(Icons.event, color: Colors.white38),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildLabel('VENUE'),
          if (_venueDropdownItems.isNotEmpty) ...[
            InputDecorator(
              decoration: _inputDecoration('Select venue'),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  menuMaxHeight: 280,
                  dropdownColor: _surface,
                  value: _effectiveVenueDropdownValue,
                  hint: const Text(
                    'Select venue',
                    style: TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                  items: _venueDropdownItems
                      .map(
                        (v) => DropdownMenuItem(
                          value: v,
                          child: Text(
                            v,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _selectedVenue = v),
                ),
              ),
            ),
          ] else ...[
            TextFormField(
              controller: _venueController,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration(
                'No venues on IPL teams — type venue name',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                return null;
              },
            ),
          ],
          const SizedBox(height: 16),
          _buildLabel('TEAM 01 (HOME)'),
          InputDecorator(
            decoration: _inputDecoration('Select team'),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Team>(
                isExpanded: true,
                dropdownColor: _surface,
                value: _team1,
                hint: const Text('Select team', style: TextStyle(color: Colors.white54, fontSize: 14)),
                items: _teams
                    .map(
                      (t) => DropdownMenuItem(
                        value: t,
                        child: Text(
                          t.name ?? t.teamId ?? '?',
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (t) {
                  setState(() {
                    _team1 = t;
                    if (t != null && _team2 != null && _isSameTeam(t, _team2!)) {
                      _team2 = null;
                    }
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildLabel('TEAM 02 (AWAY)'),
          InputDecorator(
            decoration: _inputDecoration('Select team'),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Team>(
                isExpanded: true,
                dropdownColor: _surface,
                value: _effectiveAwayDropdownValue,
                hint: const Text('Select team', style: TextStyle(color: Colors.white54, fontSize: 14)),
                items: _teamsForAway
                    .map(
                      (t) => DropdownMenuItem(
                        value: t,
                        child: Text(
                          t.name ?? t.teamId ?? '?',
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (t) => setState(() => _team2 = t),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildLabel('BID RANGE (MIN · MAX) ₹'),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        'MIN',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[500],
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    InputDecorator(
                      decoration: _inputDecoration('Min'),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<double>(
                          isExpanded: true,
                          dropdownColor: _surface,
                          value: _bidPresets.contains(_bidMin)
                              ? _bidMin
                              : _nearestBidPreset(_bidMin),
                          items: _bidPresets
                              .map(
                                (p) => DropdownMenuItem(
                                  value: p,
                                  child: Text(
                                    p.toStringAsFixed(0),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: _onBidMinChanged,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 10, right: 10, top: 28),
                child: Text(
                  '·',
                  style: TextStyle(color: Colors.grey[600], fontSize: 20, height: 1),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        'MAX',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[500],
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    InputDecorator(
                      decoration: _inputDecoration('Max'),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<double>(
                          isExpanded: true,
                          dropdownColor: _surface,
                          value: _bidPresets.contains(_bidMax)
                              ? _bidMax
                              : _nearestBidPreset(_bidMax),
                          items: _bidPresets
                              .map(
                                (p) => DropdownMenuItem(
                                  value: p,
                                  child: Text(
                                    p.toStringAsFixed(0),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: _onBidMaxChanged,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildLabel('ODDS (HOME · AWAY)'),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        'HOME',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[500],
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    InputDecorator(
                      decoration: _inputDecoration('—'),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<double>(
                          isExpanded: true,
                          dropdownColor: _surface,
                          value: _nearestOddsChoice(_selectedOddsHome),
                          hint: const Text('—', style: TextStyle(color: Colors.white54, fontSize: 14)),
                          items: _oddsChoices
                              .map(
                                (o) => DropdownMenuItem(
                                  value: o,
                                  child: Text(
                                    '${o.toStringAsFixed(2)}x',
                                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (o) {
                            if (o != null) setState(() => _selectedOddsHome = o);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 10, right: 10, top: 28),
                child: Text(
                  '·',
                  style: TextStyle(color: Colors.grey[600], fontSize: 20, height: 1),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        'AWAY',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[500],
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    InputDecorator(
                      decoration: _inputDecoration('—'),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<double>(
                          isExpanded: true,
                          dropdownColor: _surface,
                          value: _nearestOddsChoice(_selectedOddsAway),
                          hint: const Text('—', style: TextStyle(color: Colors.white54, fontSize: 14)),
                          items: _oddsChoices
                              .map(
                                (o) => DropdownMenuItem(
                                  value: o,
                                  child: Text(
                                    '${o.toStringAsFixed(2)}x',
                                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (o) {
                            if (o != null) setState(() => _selectedOddsAway = o);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildLabel('STATUS'),
          InputDecorator(
            decoration: _inputDecoration('Match status'),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                dropdownColor: _surface,
                value: _statusChoices.contains(_selectedStatus) ? _selectedStatus : 'OPEN',
                items: _statusChoices
                    .map(
                      (s) => DropdownMenuItem(
                        value: s,
                        child: Text(
                          s,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (s) {
                  if (s != null) setState(() => _selectedStatus = s);
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildLabel('RESULT'),
          InputDecorator(
            decoration: _inputDecoration('Match result'),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                dropdownColor: _surface,
                value: _resultUiKeys.contains(_selectedResultKey)
                    ? _selectedResultKey
                    : 'pending',
                items: _resultUiKeys
                    .map(
                      (k) => DropdownMenuItem(
                        value: k,
                        child: Text(
                          _resultDropdownLabel(k),
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (k) {
                  if (k == null) return;
                  setState(() {
                    _selectedResultKey = k;
                    if (k != 'pending') {
                      _selectedStatus = 'COMPLETED';
                    }
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.white24),
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: _submitting ? null : _confirmSchedule,
            child: _submitting
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.neonGreen),
                  )
                : Text(
                    _editingDocumentId == null ? 'CONFIRM SCHEDULE' : 'SAVE CHANGES',
                    style: const TextStyle(color: AppColors.neonGreen),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
        ),
      );

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white54, fontSize: 14),
      filled: true,
      fillColor: _fieldFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
    );
  }
}

class _MatchFixtureCard extends StatelessWidget {
  const _MatchFixtureCard({
    required this.match,
    required this.teamCode1,
    required this.teamCode2,
    required this.schedule,
    this.odds,
    required this.onEdit,
  });

  final Match match;
  final String teamCode1;
  final String teamCode2;
  final String schedule;
  final List<double>? odds;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final t1 = match.team1 ?? '—';
    final t2 = match.team2 ?? '—';
    final no = match.matchNo ?? match.documentId;
    final o = odds;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'MATCH $no',
                  style: const TextStyle(fontSize: 10, color: AppColors.neonGreen),
                ),
              ),
              Text(
                (match.status ?? 'OPEN').toUpperCase(),
                style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildTeam(t1, teamCode1),
              const Text('VS', style: TextStyle(color: AppColors.neonGreen, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic)),
              _buildTeam(t2, teamCode2),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.access_time, size: 14, color: Colors.grey),
              const SizedBox(width: 6),
              Text(schedule, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
          if (o != null && o.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'ODDS ',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
                if (o.length >= 2) ...[
                  Text(
                    o[0].toStringAsFixed(2),
                    style: const TextStyle(
                      color: AppColors.neonGreen,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text('  ·  ', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  Text(
                    o[1].toStringAsFixed(2),
                    style: const TextStyle(
                      color: AppColors.neonGreen,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ] else
                  Text(
                    o[0].toStringAsFixed(2),
                    style: const TextStyle(
                      color: AppColors.neonGreen,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          const Divider(color: Colors.white10),
          TextButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit, size: 16, color: Colors.white70),
            label: const Text('EDIT FIXTURE', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  Widget _buildTeam(String name, String code) {
    return Expanded(
      child: Column(
        children: [
          Text(
            name.split(' ').join('\n'),
            textAlign: TextAlign.center,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1),
          ),
          const SizedBox(height: 4),
          Text(code, style: const TextStyle(color: Colors.grey, fontSize: 10)),
        ],
      ),
    );
  }
}
