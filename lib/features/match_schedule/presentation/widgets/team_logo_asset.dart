import 'package:flutter/material.dart';

/// PNG in [assets/teams] named **`{CODE}.png`** where CODE matches [team_1_id] / [team_2_id]
/// (same as `teams.team_id` in Firestore), e.g. **RCB** → `assets/teams/RCB.png`.
///
/// If [teamId] is missing or looks like a Firestore auto-id (long alphanumeric), we fall back to
/// [teamDisplayName] (e.g. "Royal Challengers Bangalore" → `RCB.png`).
String? teamLogoAssetPath(String? teamId) =>
    teamLogoAssetPathForMatch(teamId: teamId, teamDisplayName: null);

/// Resolves an asset path for a match side using `team_*_id` and optional display name.
String? teamLogoAssetPathForMatch({
  String? teamId,
  String? teamDisplayName,
}) {
  final fromId = _pathFromTeamId(teamId);
  if (fromId != null) return fromId;
  return _pathFromTeamName(teamDisplayName);
}

/// Firestore document ids are typically 20+ chars; short codes (MI, RCB, PBKS) are &lt; 12.
const int _maxTeamIdLengthForAsset = 12;

String? _pathFromTeamId(String? teamId) {
  final raw = teamId?.trim();
  if (raw == null || raw.isEmpty) return null;
  final safe = raw.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
  if (safe.isEmpty) return null;
  if (safe.length > _maxTeamIdLengthForAsset) return null;
  return 'assets/teams/${safe.toUpperCase()}.png';
}

/// Substrings and full-name hints → asset code (order: longer phrases first).
const _nameHints = <(String, String)>[
  ('ROYAL CHALLENGERS', 'RCB'),
  ('CHENNAI SUPER KINGS', 'CSK'),
  ('SUPER KINGS', 'CSK'),
  ('CHENNAI', 'CSK'),
  ('MUMBAI INDIANS', 'MI'),
  ('MUMBAI', 'MI'),
  ('KOLKATA KNIGHT RIDERS', 'KKR'),
  ('KNIGHT RIDERS', 'KKR'),
  ('KOLKATA', 'KKR'),
  ('SUNRISERS HYDERABAD', 'SRH'),
  ('SUNRISERS', 'SRH'),
  ('HYDERABAD', 'SRH'),
  ('PUNJAB KINGS', 'PBKS'),
  ('PUNJAB', 'PBKS'),
  ('DELHI CAPITALS', 'DC'),
  ('DELHI', 'DC'),
  ('RAJASTHAN ROYALS', 'RR'),
  ('RAJASTHAN', 'RR'),
  ('GUJARAT TITANS', 'GT'),
  ('GUJARAT', 'GT'),
  ('LUCKNOW SUPER GIANTS', 'LSG'),
  ('LUCKNOW', 'LSG'),
  ('SUPER GIANTS', 'LSG'),
];

const _knownCodes = <String>{
  'RCB', 'CSK', 'MI', 'KKR', 'SRH', 'PBKS', 'DC', 'RR', 'GT', 'LSG',
};

String? _pathFromTeamName(String? teamDisplayName) {
  final n = teamDisplayName?.trim();
  if (n == null || n.isEmpty) return null;
  final u = n.toUpperCase();
  for (final token in u.split(RegExp(r'\s+'))) {
    final t = token.replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (t.isNotEmpty && _knownCodes.contains(t)) {
      return 'assets/teams/$t.png';
    }
  }
  for (final (hint, code) in _nameHints) {
    if (u.contains(hint)) return 'assets/teams/$code.png';
  }
  return null;
}

/// Local asset logo with icon fallback when the file is missing or [teamId] is empty.
class TeamLogoAsset extends StatelessWidget {
  const TeamLogoAsset({
    super.key,
    required this.teamId,
    this.teamDisplayName,
    required this.fallback,
    this.size = 70,
    this.borderRadius = 8,
    this.desaturate = false,
    this.fit = BoxFit.contain,
  });

  final String? teamId;
  /// Optional `team_1` / `team_2` label from the match — used when [teamId] is missing or not a short code.
  final String? teamDisplayName;
  final Widget fallback;
  final double size;
  final double borderRadius;
  final bool desaturate;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final path = teamLogoAssetPathForMatch(
      teamId: teamId,
      teamDisplayName: teamDisplayName,
    );
    Widget child;
    if (path == null) {
      child = fallback;
    } else {
      child = Image.asset(
        path,
        width: size,
        height: size,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => fallback,
        gaplessPlayback: true,
      );
    }

    child = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: child,
    );

    if (desaturate) {
      child = ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.35, 0.5, 0.1, 0, 0,
          0.15, 0.45, 0.1, 0, 0,
          0.05, 0.15, 0.4, 0, 0,
          0, 0, 0, 1, 0,
        ]),
        child: child,
      );
    }

    return SizedBox(width: size, height: size, child: child);
  }
}
