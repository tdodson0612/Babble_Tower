// lib/data/services/word_family_service.dart

import 'dart:convert';
import 'package:flutter/services.dart';
import '../../domain/entities/word_family.dart';

/// Loads assets/word_families/lexicon.json (built by build_word_families.py
/// from Strong's dictionary's structured derivation data) and looks up
/// root/cognate relationships by lemma. Mirrors MorphologyService's
/// load-once-cache-forever pattern deliberately — same kind of static,
/// build-time-generated asset, same "safe to call, never throws, empty
/// result just means no data" contract.
///
/// IMPORTANT: this is keyed by *citation* lemma (e.g. "λόγος"), not
/// inflected surface form (e.g. "λόγον", "λόγῳ"). The only reliable
/// source of a word's lemma anywhere in this app is ParsingWord.lemma
/// (Phase 10's MorphGNT alignment) — WordEntry.lemma is always empty,
/// since el_en.json is flat strings with no lemma data (see project
/// handoff doc's Dictionary Architecture section). Callers MUST resolve
/// a lemma via morphology data before calling [lookup]; passing a raw
/// surface form will almost always miss.
///
/// KNOWN LIMITATION, confirmed via direct data investigation (see
/// diagnose_lemma_mismatch.py / _v2.py, and the raw Strong's XML):
/// MorphGNT and Strong's dictionary sometimes disagree on which
/// inflected form is "the" citation form for the same underlying word
/// (e.g. MorphGNT lemmatizes to δεσμός, Strong's cites δεσμόν; MorphGNT
/// has θορυβάζω, Strong's has θορυβέω). This is a genuine disagreement
/// between two independently-built resources, not an encoding bug —
/// there's no safe mechanical fix for it (fuzzy/edit-distance matching
/// risks confidently showing WRONG family data, since a one-letter
/// difference in Greek often means a genuinely different grammatical
/// form). [lookup] correctly returns null for these; the UI correctly
/// shows nothing rather than guessing.
class WordFamilyService {
  Map<String, dynamic>? _lexicon;

  /// Returns family data for [lemma], or null if this lemma has no
  /// recorded relations (isolated root — see build_word_families.py,
  /// only words with at least one relation are included), the lexicon
  /// doesn't recognize the spelling, or the spelling genuinely differs
  /// between MorphGNT and Strong's citation form (see class doc's
  /// known limitation). Never throws.
  Future<WordFamily?> lookup(String lemma) async {
    if (lemma.isEmpty) return null;
    final lexicon = await _load();
    final raw = lexicon[_precompose(lemma)];
    if (raw == null) return null;
    return WordFamily.fromJson(lemma, raw as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> _load() async {
    if (_lexicon != null) return _lexicon!;
    try {
      final raw = await rootBundle
          .loadString('assets/word_families/lexicon.json');
      final decoded = json.decode(raw) as Map<String, dynamic>;
      // Precompose every key once at load time, so a lookup key built
      // from either encoding convention lands on the same map entry.
      // See [_precompose]'s doc for why this is needed.
      _lexicon = {
        for (final entry in decoded.entries)
          _precompose(entry.key): entry.value,
      };
    } catch (_) {
      // Missing file (build_word_families.py hasn't been run) — treat as
      // "no data" everywhere, not an error, same as MorphologyService.
      _lexicon = const {};
    }
    return _lexicon!;
  }

  /// Precomposes two known DECOMPOSED combining-mark sequences into
  /// their single-codepoint equivalents.
  ///
  /// The same visible character (e.g. "ΐ", iota with dialytika and
  /// tonos) can be encoded two byte-different ways: as one precomposed
  /// codepoint, or as a base letter followed by two separate combining
  /// marks. Confirmed directly this session, by dumping actual
  /// codepoints from both assets/morphology/*.json and
  /// assets/word_families/lexicon.json, that this exact
  /// (base + diaeresis + acute) decomposed pattern is why 5 real
  /// lemmas — πρωΐ, πρωΐα, περιΐστημι, πραΰς, διΐστημι — failed an
  /// exact-string-match lookup despite being spelled "the same way" on
  /// screen. This is a small, explicit, dependency-free fix (matching
  /// this codebase's existing hand-written-diacritic-map style, e.g.
  /// KoinePhoneticService's _baseLetter) rather than pulling in a full
  /// Unicode-normalization package for two known character sequences.
  String _precompose(String s) {
    return s
        .replaceAll('\u03B9\u0308\u0301', '\u0390') // ι + diaeresis + acute -> ΐ
        .replaceAll('\u03C5\u0308\u0301', '\u03B0'); // υ + diaeresis + acute -> ΰ
  }
}