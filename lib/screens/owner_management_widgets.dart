import 'package:flutter/material.dart';

import '../auth/demo_session.dart';
import '../booking/demo_booking.dart';
import '../widgets/design.dart';
import 'home_navigation.dart';

void ownerOpen(BuildContext context, Widget page) =>
    Navigator.push(context, MaterialPageRoute<void>(builder: (_) => page));

class OwnerBar extends StatelessWidget implements PreferredSizeWidget {
  const OwnerBar({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon = Icons.add,
    this.onAction,
    this.large = false,
  });
  final String title, subtitle;
  final IconData icon;
  final VoidCallback? onAction;
  final bool large;
  @override
  Size get preferredSize => Size.fromHeight(large ? 88 : 56);
  @override
  Widget build(BuildContext context) => AppBar(
    backgroundColor: AppColors.green,
    foregroundColor: Colors.white,
    centerTitle: true,
    elevation: 0,
    toolbarHeight: preferredSize.height,
    leading: BackButton(onPressed: () => Navigator.maybePop(context)),
    title: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          subtitle,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 10,
            color: Color(0xFFC5EFDC),
          ),
        ),
      ],
    ),
    actions: [
      if (onAction != null)
        IconButton(
          tooltip: title,
          onPressed: onAction,
          icon: Icon(icon, size: 20),
        ),
      const SizedBox(width: 8),
    ],
  );
}

class OwnerHeader extends StatelessWidget {
  const OwnerHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon = Icons.add,
    this.onAction,
  });
  final String title, subtitle;
  final IconData icon;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.green,
    child: SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Quay lại',
              onPressed: () => HomeNavigation.returnHome(context),
              icon: const Icon(Icons.chevron_left, color: Colors.white),
            ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFFC5EFDC),
                    ),
                  ),
                ],
              ),
            ),
            if (onAction != null)
              IconButton(
                tooltip: title,
                onPressed: onAction,
                icon: Icon(icon, size: 20, color: Colors.white),
              )
            else
              const SizedBox(width: 48),
          ],
        ),
      ),
    ),
  );
}

class OwnerNavigation extends StatelessWidget {
  const OwnerNavigation({super.key, this.selected = 0});
  final int selected;
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Colors.white,
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            for (var i = 0; i < 5; i++)
              Expanded(
                child: InkWell(
                  key: Key('owner-nav-$i'),
                  onTap: () => HomeNavigation.openTab(context, i),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FigmaIcon(
                        ['70656', 'ae34c', '8c511', '96aba', 'd96ab'][i],
                        size: 20,
                        color: selected == i
                            ? AppColors.green
                            : AppColors.faint,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          'Trang chủ',
                          'Bản đồ',
                          'Khám phá',
                          'Nổi bật',
                          'Tài khoản',
                        ][i],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 9,
                          color: selected == i
                              ? AppColors.green
                              : AppColors.faint,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class OwnerCard extends StatelessWidget {
  const OwnerCard({
    super.key,
    required this.child,
    this.padding = 12,
    this.onTap,
  });
  final Widget child;
  final double padding;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: EdgeInsets.all(padding),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppColors.border),
      boxShadow: const [
        BoxShadow(
          color: Color(0x06000000),
          blurRadius: 6,
          offset: Offset(0, 3),
        ),
      ],
    ),
    child: Material(
      type: MaterialType.transparency,
      child: onTap == null ? child : InkWell(onTap: onTap, child: child),
    ),
  );
}

class OwnerBadge extends StatelessWidget {
  const OwnerBadge(this.label, {super.key, this.warning = false});
  final String label;
  final bool warning;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
    decoration: BoxDecoration(
      color: warning ? const Color(0xFFFFF4DC) : const Color(0xFFE5F6ED),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w600,
        color: warning ? const Color(0xFF8B580E) : AppColors.darkGreen,
      ),
    ),
  );
}

class OwnerHeading extends StatelessWidget {
  const OwnerHeading(this.title, {super.key, this.action, this.onTap});
  final String title;
  final String? action;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
        if (action != null) ...[
          const SizedBox(width: 8),
          Flexible(
            child: InkWell(
              onTap: onTap,
              child: Text(
                action!,
                style: const TextStyle(fontSize: 10, color: AppColors.green),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

class OwnerVenueContext extends StatelessWidget {
  const OwnerVenueContext({super.key});
  @override
  Widget build(BuildContext context) => const OwnerCard(
    child: Row(
      children: [
        Icon(Icons.location_on_outlined, color: AppColors.green, size: 20),
        SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DemoBooking.venue,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 3),
              Text(
                DemoBooking.address,
                style: TextStyle(fontSize: 9, color: AppColors.muted),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget ownerButton(
  String text,
  VoidCallback? onPressed, {
  Key? key,
  bool filled = false,
}) => filled
    ? FilledButton(
        key: key,
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      )
    : TextButton(
        key: key,
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.ink,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

Widget ownerLine(String title, String value) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 5),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(fontSize: 11, color: AppColors.muted),
        ),
      ),
      const SizedBox(width: 8),
      Flexible(
        child: Text(
          value,
          textAlign: TextAlign.end,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        ),
      ),
    ],
  ),
);

Widget ownerChip(String text, bool selected, VoidCallback onTap, {Key? key}) =>
    ChoiceChip(
      key: key,
      label: Text(
        text,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 10,
          color: selected ? Colors.white : AppColors.muted,
        ),
      ),
      selected: selected,
      showCheckmark: false,
      selectedColor: AppColors.green,
      backgroundColor: Colors.white,
      side: BorderSide(color: selected ? AppColors.green : AppColors.border),
      shape: const StadiumBorder(),
      visualDensity: VisualDensity.compact,
      onSelected: (_) => onTap(),
    );

String ownerInitials(String name) => name
    .trim()
    .split(RegExp(r'\s+'))
    .reversed
    .take(2)
    .toList()
    .reversed
    .map((w) => w.characters.first)
    .join()
    .toUpperCase();

bool ownerLarge(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(12) > 17;
bool isOwner(DemoSession s) => s.user != null && s.role == DemoRole.owner;
