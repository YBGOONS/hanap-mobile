import 'package:flutter/material.dart';
import '../../theme/dashboard_theme.dart';
import 'dashboard_widgets.dart';

const _stepLabels = ["Posted", "Accepted", "Arrived", "In Progress", "Completed"];

int _stepIndexForStatus(String status) => switch (status) {
      'open' => 0,
      'accepted' => 1,
      'arrived' => 2,
      'in_progress' => 3,
      'completed' => 4,
      _ => -1,
    };

/// 5-step job lifecycle tracker (open → accepted → arrived → in_progress →
/// completed). A `cancelled` (or otherwise unrecognized) status doesn't fit
/// a forward progression, so it falls back to a plain status badge instead.
class JobStepProgress extends StatelessWidget {
  final String status;
  const JobStepProgress({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final stepIndex = _stepIndexForStatus(status);
    if (stepIndex == -1) {
      return Align(alignment: Alignment.centerLeft, child: DashboardStatusBadge(status: status));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 0; i < _stepLabels.length; i++) ...[
              if (i != 0) const SizedBox(width: 4),
              Expanded(
                child: Container(
                  height: 5,
                  decoration: BoxDecoration(
                    color: i <= stepIndex ? DashboardColors.primary : DashboardColors.border,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (var i = 0; i < _stepLabels.length; i++)
              Expanded(
                child: Text(
                  _stepLabels[i],
                  textAlign: i == 0
                      ? TextAlign.left
                      : i == _stepLabels.length - 1
                          ? TextAlign.right
                          : TextAlign.center,
                  style: DashboardText.body(
                    size: 10,
                    weight: i <= stepIndex ? FontWeight.w700 : FontWeight.w400,
                    color: i <= stepIndex ? DashboardColors.primary : DashboardColors.muted,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
