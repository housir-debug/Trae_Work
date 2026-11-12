// 复盘历史
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/utils.dart';
import '../models/journal_entry.dart';
import '../providers/journal_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/backgrounds.dart';
import '../widgets/journal_sheet.dart';
import '../widgets/ui.dart';

class JournalHistoryScreen extends StatelessWidget {
  const JournalHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<SettingsProvider>().currentTheme;
    final sp = context.watch<SettingsProvider>();
    final settings = sp.settings;
    final journal = context.watch<JournalProvider>();
    final entries = journal.entries;

    final groups = <String, List<JournalEntry>>{};
    for (final e in entries) {
      final d = DateTime.tryParse(e.dateKey);
      final key = d == null ? '未知' : '${d.year}年${d.month}月';
      groups.putIfAbsent(key, () => []).add(e);
    }

    final overlay = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness:
          theme.isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness:
          theme.isDark ? Brightness.dark : Brightness.light,
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        AppBackground(settings: settings, theme: theme),
        AnnotatedRegion<SystemUiOverlayStyle>(
          value: overlay,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              foregroundColor: theme.foreground,
              title: Text('复盘历史',
                  style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: theme.foreground)),
            ),
            body: entries.isEmpty
                ? const EmptyHint(
                    icon: Icons.menu_book_outlined,
                    text: '还没有复盘记录\n每天晚上花几分钟, 记录心情与收获',
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
                    children: [
                      for (final g in groups.entries) ...[
                        SectionHeader(
                          title: g.key,
                          subtitle: '${g.value.length} 天',
                          margin: const EdgeInsets.fromLTRB(0, 18, 0, 8),
                        ),
                        ...g.value.map((e) => _EntryTile(entry: e)),
                      ],
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

class _EntryTile extends StatelessWidget {
  final JournalEntry entry;

  const _EntryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<SettingsProvider>().currentTheme;
    final date = DateTime.tryParse(entry.dateKey);
    final preview = entry.highlight.isNotEmpty
        ? entry.highlight
        : entry.note.isNotEmpty
            ? entry.note
            : entry.gratitude.isNotEmpty
                ? entry.gratitude
                : '这一天没有留下文字';

    return AppCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      onTap: () => _showDetail(context, entry),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.primary.withOpacity(0.09),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Text(entry.moodEmoji, style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      date == null ? entry.dateKey : shortDate(date),
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: theme.foreground),
                    ),
                    const SizedBox(width: 6),
                    if (date != null)
                      Text(weekdayFull(date),
                          style:
                              TextStyle(fontSize: 10, color: theme.muted)),
                    const Spacer(),
                    Text('精力 ${entry.energy}/5',
                        style: TextStyle(fontSize: 10, color: theme.muted)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  preview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, height: 1.4, color: theme.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDetail(BuildContext context, JournalEntry entry) async {
    final theme = context.read<SettingsProvider>().currentTheme;
    final date = DateTime.tryParse(entry.dateKey);
    await showAppSheet<void>(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(entry.moodEmoji, style: const TextStyle(fontSize: 26)),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    date == null
                        ? entry.dateKey
                        : '${shortDate(date)} ${weekdayFull(date)}',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: theme.foreground),
                  ),
                  Text('心情 ${entry.mood}/5 · 精力 ${entry.energy}/5',
                      style: TextStyle(fontSize: 10, color: theme.muted)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _block(context, '高光时刻', entry.highlight, Icons.star_border),
          _block(context, '值得感恩', entry.gratitude, Icons.favorite_border),
          _block(context, '复盘反思', entry.note, Icons.edit_note),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    showJournalEditor(context, entry: entry);
                  },
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('编辑'),
                ),
              ),
              Expanded(
                child: TextButton.icon(
                  onPressed: () async {
                    final ok = await showConfirmDialog(context,
                        title: '删除这天的复盘?',
                        danger: true,
                        confirmText: '删除');
                    if (!ok || !context.mounted) return;
                    await context.read<JournalProvider>().delete(entry.id);
                    if (context.mounted) Navigator.pop(context);
                  },
                  icon: const Icon(Icons.delete_outline,
                      size: 16, color: Color(0xFFFF5252)),
                  label: const Text('删除',
                      style: TextStyle(color: Color(0xFFFF5252))),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _block(
      BuildContext context, String title, String text, IconData icon) {
    if (text.isEmpty) return const SizedBox.shrink();
    final theme = context.watch<SettingsProvider>().currentTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: theme.primary),
              const SizedBox(width: 5),
              Text(title,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.primary)),
            ],
          ),
          const SizedBox(height: 5),
          Text(text,
              style: TextStyle(
                  fontSize: 13, height: 1.6, color: theme.foreground)),
        ],
      ),
    );
  }
}
