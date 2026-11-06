// widgets/heatmap_calendar.dart - 活动热力图
import 'package:flutter/material.dart';

import '../core/utils.dart';

class HeatmapCalendar extends StatelessWidget {
  final Map<String, int> values;
  final Color baseColor;
  final int weeks;

  const HeatmapCalendar({
    super.key,
    required this.values,
    required this.baseColor,
    this.weeks = 12,
  });

  @override
  Widget build(BuildContext context) {
    final today = startOfDay(DateTime.now());
    final start = startOfWeek(today)
        .subtract(Duration(days: (weeks - 1) * 7));
    final maxValue = values.values.isEmpty
        ? 0
        : values.values.reduce((a, b) => a > b ? a : b);

    int level(String key) {
      final v = values[key] ?? 0;
      if (v <= 0) return 0;
      if (maxValue <= 0) return 1;
      final l = (v / maxValue * 4).ceil();
      return l.clamp(1, 4).toInt();
    }

    Color cellColor(int lv) {
      if (lv == 0) return baseColor.withOpacity(0.06);
      return baseColor.withOpacity(0.22 + 0.18 * lv);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                for (int i = 0; i < 7; ++i)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1.5),
                    child: Text(
                      i == 0 ? '一' : (i == 6 ? '日' : ' '),
                      style: TextStyle(
                          fontSize: 9,
                          color: baseColor.withOpacity(0.55)),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (int w = 0; w < weeks; ++w)
                    Column(
                      children: [
                        for (int d = 0; d < 7; ++d)
                          Padding(
                            padding: const EdgeInsets.all(1.5),
                            child: _Cell(
                              color: cellColor(level(
                                  dateKey(start.add(Duration(days: w * 7 + d))))),
                              future: start
                                  .add(Duration(days: w * 7 + d))
                                  .isAfter(today),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('少',
                style:
                    TextStyle(fontSize: 9, color: baseColor.withOpacity(0.5))),
            const SizedBox(width: 4),
            for (int i = 0; i < 5; ++i)
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                decoration: BoxDecoration(
                  color: i == 0
                      ? baseColor.withOpacity(0.06)
                      : baseColor.withOpacity(0.22 + 0.18 * i),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            const SizedBox(width: 4),
            Text('多',
                style:
                    TextStyle(fontSize: 9, color: baseColor.withOpacity(0.5))),
          ],
        ),
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  final Color color;
  final bool future;

  const _Cell({required this.color, required this.future});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 13,
      height: 13,
      decoration: BoxDecoration(
        color: future ? Colors.transparent : color,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}
