// widgets/journal_sheet.dart - 每日复盘编辑
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/utils.dart';
import '../models/journal_entry.dart';
import '../providers/journal_provider.dart';
import '../providers/settings_provider.dart';
import 'ui.dart';

Future<void> showJournalEditor(BuildContext context) async {
  await showAppSheet<void>(
    context,
    child: const _JournalEditor(),
  );
}

class _JournalEditor extends StatefulWidget {
  const _JournalEditor();

  @override
  State<_JournalEditor> createState() => _JournalEditorState();
}

class _JournalEditorState extends State<_JournalEditor> {
  late final TextEditingController _highlight;
  late final TextEditingController _gratitude;
  late final TextEditingController _note;
  late int _mood;
  late int _energy;

  @override
  void initState() {
    super.initState();
    final entry = context.read<JournalProvider>().todayEntry;
    _highlight = TextEditingController(text: entry?.highlight ?? '');
    _gratitude = TextEditingController(text: entry?.gratitude ?? '');
    _note = TextEditingController(text: entry?.note ?? '');
    _mood = entry?.mood ?? 3;
    _energy = entry?.energy ?? 3;
  }

  @override
  void dispose() {
    _highlight.dispose();
    _gratitude.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<SettingsProvider>().currentTheme;
    final existing = context.read<JournalProvider>().todayEntry;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text('今日复盘',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: theme.foreground)),
            const Spacer(),
            Text(friendlyDate(DateTime.now()),
                style: TextStyle(fontSize: 11, color: theme.muted)),
          ],
        ),
        const SizedBox(height: 16),
        Text('此刻心情', style: TextStyle(fontSize: 12, color: theme.muted)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: JournalEntry.moodEmojis.asMap().entries.map((e) {
            final selected = _mood == e.key + 1;
            return GestureDetector(
              onTap: () => setState(() => _mood = e.key + 1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: selected
                      ? theme.primary.withOpacity(0.14)
                      : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  e.value,
                  style: TextStyle(
                    fontSize: selected ? 30 : 24,
                    height: 1.1,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Text('精力', style: TextStyle(fontSize: 12, color: theme.muted)),
            const Spacer(),
            Text('$_energy / 5',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.primary)),
          ],
        ),
        Slider(
          value: _energy.toDouble(),
          min: 1,
          max: 5,
          divisions: 4,
          activeColor: theme.primary,
          onChanged: (v) => setState(() => _energy = v.round()),
        ),
        TextField(
          controller: _highlight,
          style: TextStyle(fontSize: 13, color: theme.foreground),
          decoration: appInput(
            context: context,
            hint: '今天最值得记住的一件事 ✨',
            prefix: Icon(Icons.star_border, size: 16, color: theme.accent),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _gratitude,
          style: TextStyle(fontSize: 13, color: theme.foreground),
          decoration: appInput(
            context: context,
            hint: '值得感恩的人或事',
            prefix: Icon(Icons.favorite_border,
                size: 16, color: theme.primary),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _note,
          maxLines: 3,
          style: TextStyle(fontSize: 13, color: theme.foreground),
          decoration: appInput(
            context: context,
            hint: '复盘: 哪里做得好? 明天可以怎么改进?',
          ),
        ),
        const SizedBox(height: 18),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: theme.primary,
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _save,
          child: Text(existing == null ? '保存今日复盘' : '更新今日复盘'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final provider = context.read<JournalProvider>();
    final entry = JournalEntry(
      id: provider.todayEntry?.id,
      dateKey: dateKey(DateTime.now()),
      mood: _mood,
      energy: _energy,
      highlight: _highlight.text.trim(),
      gratitude: _gratitude.text.trim(),
      note: _note.text.trim(),
    );
    await provider.save(entry);
    if (mounted) {
      showToast(context, '复盘已记录');
      Navigator.pop(context);
    }
  }
}
