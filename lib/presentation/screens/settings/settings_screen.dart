// lib/presentation/screens/settings/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: colors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Settings',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        children: [
          // ── Appearance ──────────────────────────────────────────────────
          _SectionHeader(label: 'Appearance', colors: colors),
          _ToggleTile(
            title: 'Dark mode',
            subtitle: 'Use a dark color scheme throughout the app',
            value: settings.darkMode,
            colors: colors,
            onChanged: (_) =>
                ref.read(settingsProvider.notifier).toggleDarkMode(),
          ),
          const SizedBox(height: 24),

          // ── Reading ─────────────────────────────────────────────────────
          _SectionHeader(label: 'Reading', colors: colors),
          _ToggleTile(
            title: 'Show known words',
            subtitle: 'Display words you\'ve already mastered',
            value: settings.showKnownWords,
            colors: colors,
            onChanged: (_) => ref
                .read(settingsProvider.notifier)
                .toggleShowKnownWords(),
          ),
          _ToggleTile(
            title: 'Haptic feedback',
            subtitle: 'Vibrate lightly on word tap',
            value: settings.hapticFeedback,
            colors: colors,
            onChanged: (_) =>
                ref.read(settingsProvider.notifier).toggleHaptic(),
          ),
          const SizedBox(height: 16),
          _SliderTile(
            title: 'Text size',
            value: settings.textScale,
            min: 0.8,
            max: 1.6,
            colors: colors,
            onChanged: (v) =>
                ref.read(settingsProvider.notifier).setTextScale(v),
          ),
          const SizedBox(height: 24),

          // ── About ───────────────────────────────────────────────────────
          _SectionHeader(label: 'About', colors: colors),
          _InfoTile(
            title: 'Greek text source',
            subtitle: 'Byzantine Majority Text (Koine Greek) — public domain',
            colors: colors,
          ),
          _InfoTile(
            title: 'Version',
            subtitle: '1.0.0',
            colors: colors,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String label;
  final AppColors colors;
  const _SectionHeader({required this.label, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
          color: colors.textSecondary,
        ),
      ),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final AppColors colors;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.colors,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title,
          style: TextStyle(fontSize: 15, color: colors.textPrimary)),
      subtitle: Text(subtitle,
          style: TextStyle(fontSize: 13, color: colors.textSecondary)),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: colors.primary,
      ),
    );
  }
}

class _SliderTile extends StatelessWidget {
  final String title;
  final double value;
  final double min;
  final double max;
  final AppColors colors;
  final ValueChanged<double> onChanged;

  const _SliderTile({
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.colors,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title,
                style: TextStyle(fontSize: 15, color: colors.textPrimary)),
            Text(
              '${(value * 100).round()}%',
              style: TextStyle(fontSize: 13, color: colors.textSecondary),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: 8,
          activeColor: colors.primary,
          inactiveColor: colors.border,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final AppColors colors;
  const _InfoTile({
    required this.title,
    required this.subtitle,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title,
          style: TextStyle(fontSize: 15, color: colors.textPrimary)),
      subtitle: Text(subtitle,
          style: TextStyle(fontSize: 13, color: colors.textSecondary)),
    );
  }
}