import 'package:flutter/material.dart';

import '../widgets/design.dart';
import 'home_navigation.dart';

String adminDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
String adminTime(DateTime d) =>
    '${adminDate(d)} · ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
String adminDecision(String value) =>
    const {
      'approved': 'Đã phê duyệt',
      'supplement': 'Yêu cầu bổ sung',
      'rejected': 'Đã từ chối',
    }[value] ??
    'Đã ghi nhận';

PreferredSizeWidget adminReviewBar(
  BuildContext context,
  String title,
  String subtitle, {
  VoidCallback? onNotifications,
}) => AppBar(
  backgroundColor: AppColors.green,
  foregroundColor: Colors.white,
  centerTitle: true,
  toolbarHeight: MediaQuery.textScalerOf(context).scale(1) > 1.4 ? 98 : 64,
  leading: IconButton(
    tooltip: 'Quay lại',
    icon: const Icon(Icons.chevron_left),
    onPressed: () {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      } else {
        HomeNavigation.returnHome(context);
      }
    },
  ),
  title: Column(
    children: [
      Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      Text(
        subtitle,
        style: const TextStyle(fontSize: 10),
        textAlign: TextAlign.center,
      ),
    ],
  ),
  actions: [
    if (onNotifications != null)
      IconButton(
        tooltip: 'Thông báo quản trị',
        onPressed: onNotifications,
        icon: const Icon(Icons.notifications_outlined, size: 20),
      ),
  ],
);

class AdminReviewCard extends StatelessWidget {
  const AdminReviewCard({
    super.key,
    this.title,
    required this.children,
    this.onTap,
  });
  final String? title;
  final List<Widget> children;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.ink,
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.green,
              textStyle: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (title != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    title!,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ...children,
            ],
          ),
        ),
      ),
    ),
  );
}

class AdminReviewNote extends StatelessWidget {
  const AdminReviewNote(this.text, {super.key, this.warning = false});
  final String text;
  final bool warning;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: warning ? const Color(0xFFFFF7E5) : const Color(0xFFE5F5EC),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 11,
        height: 1.5,
        color: warning ? const Color(0xFF855200) : AppColors.darkGreen,
      ),
    ),
  );
}

class AdminReviewChip extends StatelessWidget {
  const AdminReviewChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });
  final Widget label;
  final bool selected;
  final ValueChanged<bool> onSelected;
  @override
  Widget build(BuildContext context) => ChoiceChip(
    label: label,
    labelStyle: TextStyle(
      fontSize: 10,
      color: selected ? Colors.white : AppColors.muted,
    ),
    selected: selected,
    onSelected: onSelected,
    showCheckmark: false,
    selectedColor: AppColors.green,
    backgroundColor: Colors.white,
    side: BorderSide(color: selected ? AppColors.green : AppColors.border),
    shape: const StadiumBorder(),
    visualDensity: VisualDensity.compact,
  );
}

class AdminReviewNavigation extends StatelessWidget {
  const AdminReviewNavigation({super.key, this.selected = 2});
  final int selected;
  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          for (var i = 0; i < 5; i++)
            Expanded(
              child: InkWell(
                onTap: () => HomeNavigation.openTab(context, i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        const [
                          Icons.grid_view_outlined,
                          Icons.layers_outlined,
                          Icons.fact_check_outlined,
                          Icons.bar_chart_outlined,
                          Icons.person_outline,
                        ][i],
                        color: i == selected
                            ? AppColors.green
                            : AppColors.faint,
                        size: 20,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        const [
                          'Tổng quan',
                          'Quản lý',
                          'Duyệt',
                          'Báo cáo',
                          'Tài khoản',
                        ][i],
                        style: TextStyle(
                          fontSize: 9,
                          color: i == selected
                              ? AppColors.green
                              : AppColors.faint,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
