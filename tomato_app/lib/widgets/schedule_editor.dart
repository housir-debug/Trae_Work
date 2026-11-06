// widgets/schedule_editor.dart - 时间块编辑弹层
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/utils.dart';
import '../models/schedule_event.dart';
import '../providers/schedule_provider.dart';
import '../providers/settings_provider.dart';
import 'ui.dart';

Future<void> showScheduleEditor(BuildContext context, {ScheduleEvent? event}) async {
  await showAppSheet<void>(
    context,
    child: _ScheduleEditor(existing: event),
  );
}

class _ScheduleEditor extends StatefulWidget {
  final ScheduleEvent? existing;

  const _ScheduleEditor({this.existing});

  @override
  State<_ScheduleEditor> createState() => _ScheduleEditorState();
}

class _ScheduleEditorState extends State<_ScheduleEditor> {
  late final TextEditingController _title;
  late final TextEditingController _note;
  late int _start;
  late int _end;
  late ScheduleCategory _category;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _note = TextEditingController(text: e?.note ?? '');
    final now = DateTime.now();
    final rounded = ((now.hour * 60 + now.minute + 29) ~/ 30) * 30;
    _start = e?.startMinute ?? rounded.clamp(6 * 60, 22 * 60).toInt();
    _end = e?.endMinute ?? (_start + 60);
    _category = e?.category ?? ScheduleCategory.work;
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickTime({required bool isStart}) async {
    final current = isStart ? _start : _end;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
    );
    if (picked == null) return;
    final minutes = picked.hour * 60 + picked.minute;
    setState(() {
      if (isStart) {
        _start = minutes;
        if (_end <= _start) _end = _start + 30;
      } else {
        _end = minutes > _start ? minutes : _start + 30;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<SettingsProvider>().currentTheme;
    final isEditing = widget.existing != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          isEditing ? '编辑日程' : '规划时间块',
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: theme.foreground),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _title,
          autofocus: !isEditing,
          maxLength: 40,
          style: TextStyle(fontSize: 14, color: theme.foreground),
          decoration: appInput(context: context, hint: '这段时间用来做什么?')
              .copyWith(counterText: ''),
        ),
        const SizedBox(height: 12),
        Text('分类', style: TextStyle(fontSize: 12, color: theme.muted)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: ScheduleCategory.values.map((c) {
            return PillChip(
              label: c.label,
              icon: c.icon,
              color: c.color,
              selected: _category == c,
              onTap: () => setState(() => _category = c),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _TimeBox(
                label: '开始',
                value: timeText(_start),
                onTap: () => _pickTime(isStart: true),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _TimeBox(
                label: '结束',
                value: timeText(_end),
                onTap: () => _pickTime(isStart: false),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('时长',
                    style: TextStyle(fontSize: 10, color: theme.muted)),
                const SizedBox(height: 2),
                Text(
                  durationText(_end - _start),
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.primary),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _note,
          maxLines: 2,
          style: TextStyle(fontSize: 13, color: theme.foreground),
          decoration: appInput(context: context, hint: '备注(可选)'),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            if (isEditing)
              TextButton(
                onPressed: () async {
                  final ok = await showConfirmDialog(context,
                      title: '删除这个时间块?', danger: true, confirmText: '删除');
                  if (!ok || !context.mounted) return;
                  await context
                      .read<ScheduleProvider>()
                      .delete(widget.existing!.id);
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('删除',
                    style: TextStyle(color: Color(0xFFFF5252))),
              ),
            const Spacer(),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('取消', style: TextStyle(color: theme.muted)),
            ),
            const SizedBox(width: 8),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _category.color,
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _save,
              child: Text(isEditing ? '保存' : '添加到日程'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      showToast(context, '请填写日程标题');
      return;
    }
    final provider = context.read<ScheduleProvider>();
    final base = widget.existing ??
        ScheduleEvent(
          dateKey: dateKey(DateTime.now()),
          title: title,
          startMinute: _start,
          endMinute: _end,
        );
    final result = base.copyWith(
      title: title,
      startMinute: _start,
      endMinute: _end,
      category: _category,
      note: _note.text.trim(),
    );
    if (widget.existing == null) {
      await provider.add(result);
    } else {
      await provider.update(result);
    }
    if (mounted) {
      showToast(context, '日程已保存');
      Navigator.pop(context);
    }
  }
}

class _TimeBox extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _TimeBox({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<SettingsProvider>().currentTheme;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: theme.muted)),
          const SizedBox(height: 3),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: theme.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(value,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: theme.foreground)),
                Icon(Icons.access_time, size: 14, color: theme.muted),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
