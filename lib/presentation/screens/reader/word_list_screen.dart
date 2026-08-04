// lib/presentation/screens/reader/word_list_screen.dart

import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../domain/usecases/word_list_usecase.dart';

/// Navigation arguments for the /word_list route.
class WordListArgs {
  final String verseText;
  const WordListArgs({required this.verseText});
}

/// Shown once, before a block's verse content is displayed for the
/// first time — forward-progress path only, never in review mode (see
/// reader_screen.dart and the project handoff doc's "Word List Page"
/// section). Covers the WHOLE block's combined text, not a single
/// verse: a block that groups several verses together shows one page
/// listing every unique word across all of them, repeats across verses
/// deduped too.
///
/// Hand-built Column/Row layout rather than DataTable — safer for
/// Greek text sizing/wrapping on mobile.
class WordListScreen extends StatefulWidget {
  final WordListArgs args;

  const WordListScreen({super.key, required this.args});

  @override
  State<WordListScreen> createState() => _WordListScreenState();
}

class _WordListScreenState extends State<WordListScreen> {
  static const _useCase = WordListUseCase();
  late final Future<List<WordListRow>> _rowsFuture;

  @override
  void initState() {
    super.initState();
    _rowsFuture = _useCase.build(widget.args.verseText);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'Words in this passage',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 17,
          ),
        ),
      ),
      body: FutureBuilder<List<WordListRow>>(
        future: _rowsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = snapshot.data ?? const <WordListRow>[];
          if (rows.isEmpty) {
            // No recognizable Greek tokens — don't block the reader on
            // an empty page; the Continue button below still works.
            return Center(
              child: Text(
                'No new words to preview here.',
                style: TextStyle(color: colors.textSecondary),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            itemCount: rows.length + 1,
            separatorBuilder: (_, __) => Divider(color: colors.border),
            itemBuilder: (context, i) {
              if (i == 0) return _HeaderRow(colors: colors);
              return _WordListRowTile(row: rows[i - 1]);
            },
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Continue to verse',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  final AppColors colors;
  const _HeaderRow({required this.colors});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: colors.textSecondary,
      letterSpacing: 0.4,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 96, child: Text('GREEK', style: style)),
          const SizedBox(width: 12),
          Expanded(child: Text('TRANSLATION', style: style)),
        ],
      ),
    );
  }
}

class _WordListRowTile extends StatelessWidget {
  final WordListRow row;
  const _WordListRowTile({required this.row});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greek word + pronunciation
          SizedBox(
            width: 96,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.greek,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                if (row.pronunciation.isNotEmpty)
                  Text(
                    row.pronunciation,
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Literal translation + other possible meanings
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.translation.isNotEmpty ? row.translation : '—',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: row.translation.isNotEmpty
                        ? colors.primary
                        : colors.border,
                    fontStyle: row.translation.isNotEmpty
                        ? FontStyle.normal
                        : FontStyle.italic,
                  ),
                ),
                if (row.otherMeanings.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    row.otherMeanings.join(', '),
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}