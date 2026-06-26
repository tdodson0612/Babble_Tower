// lib/app.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants/app_colors.dart';
import 'data/services/prefs_service.dart';
import 'presentation/providers/settings_provider.dart';
import 'presentation/providers/user_profile_provider.dart';
import 'presentation/screens/onboarding/alphabet_screen.dart';
import 'presentation/screens/home/home_screen.dart';
import 'presentation/screens/reader/reader_screen.dart';
import 'presentation/screens/reader/verse_quiz_screen.dart';
import 'presentation/screens/vocabulary/vocabulary_screen.dart';
import 'presentation/screens/settings/settings_screen.dart';

class BabbleTowerApp extends ConsumerWidget {
  const BabbleTowerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final darkMode = ref.watch(settingsProvider.select((s) => s.darkMode));

    return MaterialApp(
      title: 'Babble Tower',
      debugShowCheckedModeBanner: false,
      themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.light.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor:   AppColors.light.primary,
          brightness:  Brightness.light,
        ),
        useMaterial3: true,
        extensions: const [AppColors.light],
      ),
      darkTheme: ThemeData(
        scaffoldBackgroundColor: AppColors.dark.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor:  AppColors.dark.primary,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        extensions: const [AppColors.dark],
      ),
      initialRoute: '/',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(
              builder: (_) => const _RootRedirect(),
            );
          case '/alphabet':
            return MaterialPageRoute(
              builder: (_) => const AlphabetScreen(),
            );
          case '/home':
            return MaterialPageRoute(
              builder: (_) => const HomeScreen(),
            );
          case '/reader':
            return MaterialPageRoute(
              builder: (_) => const ReaderScreen(),
            );
          case '/verse_quiz':
            return MaterialPageRoute(
              builder: (_) => const VerseQuizScreen(),
            );
          case '/vocabulary':
            return MaterialPageRoute(
              builder: (_) => const VocabularyScreen(),
            );
          case '/settings':
            return MaterialPageRoute(
              builder: (_) => const SettingsScreen(),
            );
          default:
            return MaterialPageRoute(
              builder: (_) => const _RootRedirect(),
            );
        }
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Root redirect
// ---------------------------------------------------------------------------

class _RootRedirect extends ConsumerWidget {
  const _RootRedirect();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(userProfileProvider);
    final colors       = context.colors;

    if (profileState.isLoading) {
      return Scaffold(
        backgroundColor: colors.background,
        body: Center(
          child: CircularProgressIndicator(color: colors.primary),
        ),
      );
    }

    final alphabetDone =
        PrefsService.alphabetDone || profileState.hasCompletedAlphabet;

    if (!alphabetDone) {
      return const AlphabetScreen();
    }

    return const HomeScreen();
  }
}
