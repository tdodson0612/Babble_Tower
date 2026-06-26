// lib/domain/entities/verse.dart

class Verse {
  /// Verse number within the chapter (1-based).
  final int number;

  /// Full verse text — always in the target language (L2).
  final String text;

  const Verse({
    required this.number,
    required this.text,
  });

  @override
  String toString() => 'Verse($number)';
}