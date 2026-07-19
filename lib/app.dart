// lib/app.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants/app_colors.dart';
import 'data/services/notification_service.dart';
import 'presentation/providers/settings_provider.dart';
import 'presentation/providers/user_profile_provider.dart';
import 'presentation/screens/progress/readability_screen.dart';
import 'presentation/screens/progress/progress_dashboard_screen.dart';
import 'presentation/screens/onboarding/alphabet_grid_screen.dart';
import 'presentation/screens/onboarding/alphabet_screen.dart';
import 'presentation/screens/home/home_screen.dart';
import 'presentation/screens/reader/reader_screen.dart';
import 'presentation/screens/reader/verse_quiz_screen.dart';
import 'presentation/screens/review/review_session_screen.dart';
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
          seedColor: AppColors.light.primary,
          secondary: AppColors.light.secondary,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        extensions: const [AppColors.light],
      ),
      darkTheme: ThemeData(
        scaffoldBackgroundColor: AppColors.dark.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.dark.primary,
          secondary: AppColors.dark.secondary,
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
          case '/alphabet_grid':
            // Opens as a Settings reference view (fromSettings: true)
            // when pushed from Settings, otherwise the root redirect
            // sends here fresh on cold launch.
            final fromSettings = settings.arguments == true;
            return MaterialPageRoute(
              builder: (_) =>
                  AlphabetGridScreen(fromSettings: fromSettings),
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
              settings: settings,
            );
          case '/review':
            // Spaced-repetition review session. Takes no arguments —
            // unlike /verse_quiz, it computes its own due-word list
            // internally (see ReviewSessionScreen._initSession) rather
            // than depending on a caller to pass verse-scoped words.
            return MaterialPageRoute(
              builder: (_) => const ReviewSessionScreen(),
            );
          case '/vocabulary':
            return MaterialPageRoute(
              builder: (_) => const VocabularyScreen(),
            );
          case '/readability':
            return MaterialPageRoute(
              builder: (_) => const ReadabilityScreen(),
            );
          case '/progress':
            return MaterialPageRoute(
              builder: (_) => const ProgressDashboardScreen(),
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
// Root redirect — now sends every user (new and returning) to the alphabet
// grid first. The grid's bottom buttons handle the fork:
//   - New user  → "Start Learning" → /alphabet (flashcard flow)
//   - Returning → "Go to Home"     → /home
//
// This replaces the old inline AlphabetScreen/HomeScreen decision here.
//
// Also the app's single entry point for one-time startup side effects —
// currently just kicking off NotificationService.instance.init(), fired
// once per app process (guarded by _notificationInitStarted below) and
// deliberately NOT awaited: requesting notification permission must never
// block the splash → grid/home redirect.
// ---------------------------------------------------------------------------

bool _notificationInitStarted = false;

class _RootRedirect extends ConsumerWidget {
  const _RootRedirect();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!_notificationInitStarted) {
      _notificationInitStarted = true;
      // Fire-and-forget: permission dialog (if the OS shows one) appears
      // over whatever screen is up by the time the user responds to it.
      // Errors are swallowed here rather than surfaced, since a failed
      // notification setup should never block or interrupt onboarding —
      // same fail-safe posture as every other optional-data path in this
      // app (Phase 10 morphology, Phase 12 word families, etc.).
      NotificationService.instance.init().catchError((_) {});
    }

    final profileState = ref.watch(userProfileProvider);
    final colors = context.colors;

    // Still loading from Hive — show splash
    if (profileState.isLoading) {
      return Scaffold(
        backgroundColor: colors.background,
        body: Center(
          child: CircularProgressIndicator(color: colors.primary),
        ),
      );
    }

    // Always open on the alphabet grid. The grid decides where to go next
    // based on whether the user has completed the alphabet lesson.
    return const AlphabetGridScreen(fromSettings: false);
  }
}