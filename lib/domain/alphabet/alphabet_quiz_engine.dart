// lib/domain/alphabet/alphabet_quiz_engine.dart

import 'dart:math';
import '../../core/constants/alphabet_data.dart';

/// The three distinct things a learner needs to do with a letter:
///   - recognize: given its name, pick the letter out visually
///   - soundOut: given the letter, pick its correct pronunciation
///   - name: given the letter, pick its traditional name
/// Deliberately orthogonal — [recognize] and [name] are inverses of each
/// other (name->letter vs. letter->name), reinforcing bidirectionally,
/// while [soundOut] tests a genuinely separate skill (sound, not label).
enum LetterSkill { recognize, soundOut, name }

/// One multiple-choice question about a single letter/skill combination.
class AlphabetQuestion {
  final LetterEntry target;
  final LetterSkill skill;
  final String prompt;

  /// Exactly 4 options, already shuffled; [correctIndex] points at the
  /// right one.
  final List<String> options;
  final int correctIndex;

  const AlphabetQuestion({
    required this.target,
    required this.skill,
    required this.prompt,
    required this.options,
    required this.correctIndex,
  });
}

/// Drives the alphabet-learning flow end-to-end: groups all 24 letters
/// into chunks of 5 (last chunk 4), and for each group runs a teach
/// phase (flashcard-style, one letter at a time) followed by a quiz
/// phase (15 questions — 3 skills × 5 letters, shuffled together).
///
/// Deliberately NOT built on QuizEngine/QuizWord — a letter isn't a
/// vocabulary word with a translation, and forcing it into that shape
/// would misuse an abstraction built for something else. This mirrors
/// the same reasoning that made ReviewSessionEngine a sibling to
/// QuizEngine rather than a graft-on.
///
/// No pass/fail gate between groups — completing a group's quiz (any
/// score) moves to the next group. The only hard gate on reaching
/// verses is finishing all groups OR the screen-level "Skip" action,
/// same as the flow this replaces.
///
/// Pure — no file I/O, no Hive, no Flutter widget imports — same
/// reasoning as QuizEngine staying I/O-free.
class AlphabetQuizEngine {
  AlphabetQuizEngine({List<LetterEntry>? letters, Random? random})
      : _letters = letters ?? greekAlphabetData.letters,
        _random = random ?? Random() {
    _groups = _chunk(_letters, 5);
  }

  final List<LetterEntry> _letters;
  final Random _random;
  late final List<List<LetterEntry>> _groups;

  int _groupIndex = 0;
  bool _inQuizPhase = false;
  int _teachIndex = 0;

  List<AlphabetQuestion> _quizQueue = [];
  int _quizPosition = 0;
  int _quizCorrect = 0;

  // ── Group / phase state ─────────────────────────────────────────────

  int get groupCount => _groups.length;
  int get currentGroupNumber => _groupIndex + 1;
  List<LetterEntry> get currentGroup => _groups[_groupIndex];
  bool get isTeachPhase => !_inQuizPhase;
  bool get isQuizPhase => _inQuizPhase;
  bool get isLastGroup => _groupIndex == _groups.length - 1;

  // ── Teach phase ──────────────────────────────────────────────────────

  LetterEntry get currentTeachLetter => currentGroup[_teachIndex];
  int get teachIndex => _teachIndex;
  int get teachTotal => currentGroup.length;
  bool get isLastTeachLetterInGroup => _teachIndex == currentGroup.length - 1;

  /// Moves to the next letter in this group's teach phase, or — once
  /// every letter in the group has been shown — starts this group's
  /// quiz phase instead.
  void advanceTeach() {
    if (_teachIndex < currentGroup.length - 1) {
      _teachIndex++;
    } else {
      _quizQueue = _buildQuizQueue(currentGroup);
      _quizPosition = 0;
      _quizCorrect = 0;
      _inQuizPhase = true;
    }
  }

  // ── Quiz phase ───────────────────────────────────────────────────────

  int get quizTotal => _quizQueue.length;
  int get quizPosition => _quizPosition;
  int get quizCorrect => _quizCorrect;
  bool get isGroupQuizComplete => _quizPosition >= _quizQueue.length;

  AlphabetQuestion? get currentQuestion =>
      isGroupQuizComplete ? null : _quizQueue[_quizPosition];

  /// Records the answer to the current question and advances. Call
  /// [isGroupQuizComplete] afterward to check whether this group is
  /// done, and [isLastGroup] to check whether that means the WHOLE
  /// alphabet is done.
  void submitQuizAnswer(int selectedIndex) {
    final q = _quizQueue[_quizPosition];
    if (selectedIndex == q.correctIndex) _quizCorrect++;
    _quizPosition++;
  }

  /// Moves on to the next group's teach phase. Only call when
  /// [isGroupQuizComplete] is true and [isLastGroup] is false.
  void advanceGroup() {
    _groupIndex++;
    _teachIndex = 0;
    _inQuizPhase = false;
  }

  // ── Quiz construction ────────────────────────────────────────────────

  List<AlphabetQuestion> _buildQuizQueue(List<LetterEntry> group) {
    final questions = <AlphabetQuestion>[];
    for (final letter in group) {
      questions.add(_buildQuestion(letter, LetterSkill.recognize));
      questions.add(_buildQuestion(letter, LetterSkill.soundOut));
      questions.add(_buildQuestion(letter, LetterSkill.name));
    }
    questions.shuffle(_random);
    return questions;
  }

  AlphabetQuestion _buildQuestion(LetterEntry target, LetterSkill skill) {
    // Distractors drawn from the FULL 24-letter alphabet, not just this
    // group of 5 — the last group only has 4 letters, which wouldn't be
    // enough to supply 3 distractors on its own, and there's no reason
    // to limit review to only the current group anyway.
    final pool = _letters.where((l) => l.character != target.character).toList()
      ..shuffle(_random);
    final choices = [target, ...pool.take(3)]..shuffle(_random);
    // LetterEntry has no == override, so this is reference equality —
    // exactly right, since `target` is the same const instance found
    // in `choices`. Robust against any two letters ever sharing
    // identical display text (name/pronunciation), unlike matching by
    // string value would be.
    final correctIndex = choices.indexOf(target);

    late final String prompt;
    late final List<String> options;
    switch (skill) {
      case LetterSkill.recognize:
        prompt = 'Which letter is "${target.name}"?';
        options = choices.map(_displayChar).toList();
        break;
      case LetterSkill.soundOut:
        prompt = 'How does "${_displayChar(target)}" sound?';
        options = choices.map(_shortPronunciation).toList();
        break;
      case LetterSkill.name:
        prompt = 'What is this letter called?\n${_displayChar(target)}';
        options = choices.map((e) => e.name).toList();
        break;
    }

    return AlphabetQuestion(
      target: target,
      skill: skill,
      prompt: prompt,
      options: options,
      correctIndex: correctIndex,
    );
  }

  String _displayChar(LetterEntry e) =>
      e.uppercase != null ? '${e.uppercase} ${e.character}' : e.character;

  /// Same truncation AlphabetGridScreen's tile uses, for the same reason
  /// — keeps a long pronunciation description short enough to read as
  /// one MC option (e.g. 'Like "v" in modern Greek; "b" in ancient'
  /// becomes 'Like "v" in modern Greek').
  String _shortPronunciation(LetterEntry e) {
    final full = e.pronunciation;
    final semicolonIndex = full.indexOf(';');
    return semicolonIndex != -1 ? full.substring(0, semicolonIndex).trim() : full;
  }

  static List<List<LetterEntry>> _chunk(List<LetterEntry> list, int size) {
    final result = <List<LetterEntry>>[];
    for (var i = 0; i < list.length; i += size) {
      final end = (i + size > list.length) ? list.length : i + size;
      result.add(list.sublist(i, end));
    }
    return result;
  }
}