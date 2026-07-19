// lib/presentation/providers/review_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/usecases/spaced_repetition_usecase.dart';
import 'language_provider.dart';
import 'vocabulary_provider.dart' show vocabularyServiceProvider;

/// Number of vocabulary words currently due for spaced-repetition review
/// (see SpacedRepetitionUseCase) — for badge display on the Home,
/// Vocabulary, and Progress screens' entry points into /review.
///
/// autoDispose deliberately, with no cross-screen caching: due-ness
/// changes continuously (a word becomes due the moment its interval
/// elapses, and the whole due set can change the instant a review
/// session completes), so a stale cached count would be actively
/// misleading rather than just imprecise. Each screen that watches
/// this gets a fresh read.
final dueWordsCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final pairKey = ref.watch(languageProvider).pairKey;
  final service = ref.watch(vocabularyServiceProvider);
  final allWords = await service.getAll(pairKey);
  return const SpacedRepetitionUseCase().dueCount(allWords);
});