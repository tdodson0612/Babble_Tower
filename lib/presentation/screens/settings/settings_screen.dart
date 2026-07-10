// lib/presentation/screens/settings/settings_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/services/backup_file_service.dart';
import '../../../data/services/export_service.dart';
import '../../../data/services/notification_service.dart';
import '../../../domain/usecases/backup_usecase.dart';
import '../../providers/language_provider.dart';
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
          // ── Appearance ─────────────────────────────────────────────────
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

          // ── Reading ────────────────────────────────────────────────────
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

          // ── Learning ───────────────────────────────────────────────────
          // Phase 8: quick-reference entry point for the alphabet grid.
          _SectionHeader(label: 'Learning', colors: colors),
          _NavTile(
            title: 'Greek Alphabet',
            subtitle: 'View all 24 letters with pronunciation',
            icon: Icons.translate_rounded,
            colors: colors,
            onTap: () => Navigator.of(context).pushNamed(
              '/alphabet_grid',
              arguments: true, // fromSettings: true — shows back button
            ),
          ),
          const SizedBox(height: 24),

          // ── Notifications ──────────────────────────────────────────────
          // "Future ideas" item from the handoff doc's to-do list. Time is
          // user-configurable (per conversation); permission was already
          // requested at first app launch — see app.dart's _RootRedirect —
          // so this toggle only ever schedules/cancels, never re-prompts.
          _SectionHeader(label: 'Notifications', colors: colors),
          const _NotificationSection(),
          const SizedBox(height: 24),

          // ── Data ───────────────────────────────────────────────────────
          // "Future ideas" item from the handoff doc's to-do list. Manual
          // backup/restore rather than real cloud sync — see the JSON
          // dump + share-sheet approach in backup_usecase.dart's doc
          // comment for why. Self-contained widget so this screen didn't
          // need converting to a StatefulWidget just for two buttons.
          _SectionHeader(label: 'Data', colors: colors),
          const _DataSection(),
          const SizedBox(height: 24),

          // ── About ──────────────────────────────────────────────────────
          _SectionHeader(label: 'About', colors: colors),
          _InfoTile(
            title: 'Greek text source',
            subtitle:
                'Byzantine Majority Text (Koine Greek) — public domain',
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
// Data section — back up / restore
// ---------------------------------------------------------------------------

class _DataSection extends ConsumerStatefulWidget {
  const _DataSection();

  @override
  ConsumerState<_DataSection> createState() => _DataSectionState();
}

class _DataSectionState extends ConsumerState<_DataSection> {
  bool _backingUp = false;
  bool _restoring = false;

  Future<void> _backUp() async {
    if (_backingUp) return;
    setState(() => _backingUp = true);
    try {
      final pairKey = ref.read(languageProvider).pairKey;
      final backup = await const BackupUseCase().buildBackup(pairKey);
      final jsonStr = const JsonEncoder.withIndent('  ').convert(backup);
      final timestamp = DateTime.now().toIso8601String().split('T').first;

      await const ExportService().exportAndShare(
        content: jsonStr,
        fileName: 'babble_tower_backup_$timestamp.json',
        subject: 'Babble Tower Backup',
      );
    } catch (_) {
      _showSnack('Backup failed. Please try again.');
    } finally {
      if (mounted) setState(() => _backingUp = false);
    }
  }

  Future<void> _restore() async {
    if (_restoring) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore from backup?'),
        content: const Text(
          'This replaces your current progress, vocabulary, and settings '
          'with the contents of the backup file. This cannot be undone. '
          'Restart the app after restoring for all changes to take effect.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _restoring = true);
    try {
      final backup = await const BackupFileService().pickAndReadJson();
      if (backup == null) return; // user cancelled the file picker

      await const BackupUseCase().restoreBackup(backup);
      _showSnack('Restore complete. Please restart the app.');
    } on FormatException catch (e) {
      _showSnack(e.message);
    } catch (_) {
      _showSnack('Restore failed. Please check the file and try again.');
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      children: [
        _ActionTile(
          title: 'Back Up Data',
          subtitle: 'Save your progress and vocabulary to a file',
          icon: Icons.backup_outlined,
          busy: _backingUp,
          colors: colors,
          onTap: _backUp,
        ),
        _ActionTile(
          title: 'Restore Data',
          subtitle: 'Load progress and vocabulary from a backup file',
          icon: Icons.restore_outlined,
          busy: _restoring,
          colors: colors,
          onTap: _restore,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Notifications section — daily streak reminder toggle + time picker
// ---------------------------------------------------------------------------

class _NotificationSection extends ConsumerStatefulWidget {
  const _NotificationSection();

  @override
  ConsumerState<_NotificationSection> createState() =>
      _NotificationSectionState();
}

class _NotificationSectionState extends ConsumerState<_NotificationSection> {
  bool _loading = true;
  bool _enabled = false;
  int _hour = 20;
  int _minute = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await NotificationService.instance.isEnabled();
    final (hour, minute) = await NotificationService.instance.reminderTime();
    if (!mounted) return;
    setState(() {
      _enabled = enabled;
      _hour = hour;
      _minute = minute;
      _loading = false;
    });
  }

  /// Optimistically flips the switch, then confirms the change actually
  /// took with NotificationService. If that throws (plugin/channel
  /// error, anything), rolls the switch back to its previous state and
  /// surfaces a message — mirrors the try/catch pattern _DataSection
  /// already uses above, so a failed schedule/cancel can't leave the
  /// UI silently showing "on" while nothing is actually scheduled.
  Future<void> _toggle(bool value) async {
    final previous = _enabled;
    setState(() => _enabled = value);
    try {
      await NotificationService.instance.setEnabled(value);
    } catch (_) {
      if (mounted) {
        setState(() => _enabled = previous);
        _showSnack('Couldn\'t update the reminder. Please try again.');
      }
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _hour, minute: _minute),
    );
    if (picked == null) return;

    final previousHour = _hour;
    final previousMinute = _minute;
    setState(() {
      _hour = picked.hour;
      _minute = picked.minute;
    });
    try {
      await NotificationService.instance.setReminderTime(
        picked.hour,
        picked.minute,
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _hour = previousHour;
          _minute = previousMinute;
        });
        _showSnack('Couldn\'t update the reminder time. Please try again.');
      }
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String get _timeLabel {
    final tod = TimeOfDay(hour: _hour, minute: _minute);
    final displayHour = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
    final minuteStr = tod.minute.toString().padLeft(2, '0');
    final period = tod.period == DayPeriod.am ? 'AM' : 'PM';
    return '$displayHour:$minuteStr $period';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (_loading) return const SizedBox.shrink();

    return Column(
      children: [
        _ToggleTile(
          title: 'Daily streak reminder',
          subtitle: 'A nudge to keep your reading streak alive',
          value: _enabled,
          colors: colors,
          onChanged: _toggle,
        ),
        if (_enabled)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Reminder time',
                style: TextStyle(fontSize: 15, color: colors.textPrimary)),
            subtitle: Text(_timeLabel,
                style: TextStyle(fontSize: 13, color: colors.textSecondary)),
            trailing: Icon(Icons.chevron_right, color: colors.border),
            onTap: _pickTime,
          ),
      ],
    );
  }
}

/// Like _NavTile, but for a triggered action rather than navigation —
/// shows a small spinner in place of the leading icon while [busy].
class _ActionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool busy;
  final AppColors colors;
  final VoidCallback onTap;

  const _ActionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.busy,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: colors.highlight,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: busy
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colors.accent,
                ),
              )
            : Icon(icon, size: 18, color: colors.accent),
      ),
      title: Text(title,
          style: TextStyle(fontSize: 15, color: colors.textPrimary)),
      subtitle: Text(subtitle,
          style: TextStyle(fontSize: 13, color: colors.textSecondary)),
      onTap: busy ? null : onTap,
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
                style:
                    TextStyle(fontSize: 15, color: colors.textPrimary)),
            Text(
              '${(value * 100).round()}%',
              style:
                  TextStyle(fontSize: 13, color: colors.textSecondary),
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

/// Tappable tile that navigates somewhere — used for the Learning section.
class _NavTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final AppColors colors;
  final VoidCallback onTap;

  const _NavTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: colors.highlight,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 18, color: colors.accent),
      ),
      title: Text(title,
          style: TextStyle(fontSize: 15, color: colors.textPrimary)),
      subtitle: Text(subtitle,
          style: TextStyle(fontSize: 13, color: colors.textSecondary)),
      trailing: Icon(Icons.chevron_right, color: colors.border),
      onTap: onTap,
    );
  }
}