import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../features/auth/presentation/screens/login_screen.dart';
import '../features/auth/presentation/screens/registration_screen.dart';
import 'auction_command_shell.dart';
import '../features/bids/data/datasources/bids_firestore_data_source.dart';
import '../features/match_schedule/data/datasources/match_schedule_firestore_data_source.dart';
import '../features/match_schedule/data/repositories/match_schedule_repository_impl.dart';
import '../features/match_schedule/domain/repositories/match_schedule_repository.dart';
import '../features/teams/data/datasources/teams_firestore_data_source.dart';
import '../features/teams/data/repositories/team_repository_impl.dart';
import '../features/teams/domain/repositories/team_repository.dart';
import '../features/users/data/datasources/users_firestore_data_source.dart';
import '../features/users/data/repositories/user_profile_repository_impl.dart';
import '../features/users/domain/repositories/user_profile_repository.dart';
import 'theme/app_colors.dart';

class AuctionCommandApp extends StatelessWidget {
  const AuctionCommandApp({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = MatchScheduleRepositoryImpl(
      MatchScheduleFirestoreDataSource(),
      BidsFirestoreDataSource(),
    );
    final teamsDataSource = TeamsFirestoreDataSource();
    final teamRepository = TeamRepositoryImpl(teamsDataSource);
    final userProfileRepository = UserProfileRepositoryImpl(
      UsersFirestoreDataSource(),
      teamsDataSource,
    );

    return MaterialApp(
      title: 'Auction',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: AppColors.scaffoldBackground,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.neonGreen,
          surface: AppColors.surface,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: AppColors.cardDark,
          behavior: SnackBarBehavior.floating,
          contentTextStyle: const TextStyle(
            color: Color(0xFFFFE082),
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: const Color(0xFFFFE082).withValues(alpha: 0.42)),
          ),
        ),
      ),
      home: _AuthGate(
        matchScheduleRepository: repository,
        teamRepository: teamRepository,
        userProfileRepository: userProfileRepository,
      ),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate({
    required this.matchScheduleRepository,
    required this.teamRepository,
    required this.userProfileRepository,
  });

  final MatchScheduleRepository matchScheduleRepository;
  final TeamRepository teamRepository;
  final UserProfileRepository userProfileRepository;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: AppColors.neonGreen),
            ),
          );
        }
        if (snapshot.hasData) {
          return AuctionCommandShell(
            matchScheduleRepository: matchScheduleRepository,
            teamRepository: teamRepository,
          );
        }
        return LoginScreen(
          userProfileRepository: userProfileRepository,
          onRegister: () {
            Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => RegistrationScreen(
                  teamRepository: teamRepository,
                  onLoginTap: () => Navigator.of(context).pop(),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
