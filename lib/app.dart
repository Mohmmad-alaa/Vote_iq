import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/di/injection_container.dart';
import 'core/theme/app_theme.dart';
import 'presentation/auth/cubit/auth_cubit.dart';
import 'presentation/auth/cubit/auth_state.dart';
import 'presentation/auth/screens/login_screen.dart';
import 'presentation/dashboard/cubit/dashboard_cubit.dart';
import 'presentation/home/home_screen.dart';
import 'presentation/sync/cubit/sync_cubit.dart';
import 'presentation/lookup/cubit/lookup_cubit.dart';
import 'presentation/voters/cubit/voters_cubit.dart';

/// Root application widget.
class VoteIQApp extends StatelessWidget {
  const VoteIQApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthCubit>(
          create: (_) => sl<AuthCubit>()..checkAuthStatus(),
        ),
        BlocProvider<SyncCubit>(
          create: (_) => sl<SyncCubit>()..startMonitoring(),
        ),
      ],
      child: MaterialApp(
        title: 'Vote IQ — متابعة الناخبين',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: child!,
          );
        },
        home: BlocBuilder<AuthCubit, AuthState>(
          builder: (context, state) {
            if (state is AuthLoading || state is AuthInitial) {
              return const _SplashScreen();
            }
            if (state is AuthAuthenticated) {
              return MultiBlocProvider(
                providers: [
                  BlocProvider<VotersCubit>(
                    create: (_) => sl<VotersCubit>()
                      ..loadVoters()
                      ..subscribeToRealtime(),
                  ),
                  BlocProvider<DashboardCubit>(
                    create: (_) => sl<DashboardCubit>()..loadStats(),
                  ),
                  BlocProvider<LookupCubit>(
                    create: (_) => sl<LookupCubit>()..loadAll(),
                  ),
                ],
                child: HomeScreen(agent: state.agent),
              );
            }
            return const LoginScreen();
          },
        ),
      ),
    );
  }
}

/// Splash screen shown while checking auth status.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.how_to_vote_rounded,
              size: 80,
              color: Colors.white,
            ),
            SizedBox(height: 24),
            Text(
              'Vote IQ',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'متابعة الناخبين',
              style: TextStyle(
                fontSize: 18,
                color: Colors.white70,
              ),
            ),
            SizedBox(height: 40),
            CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}
