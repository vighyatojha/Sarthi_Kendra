// lib/core/sarthi_ui.dart
// Shared look for the request / booking / chat / trust screens, matching the
// rest of the app (deep-purple gradient header, soft grey page, white rounded
// cards). IDENTICAL in both apps.

import 'package:flutter/material.dart';

class SarthiColors {
  SarthiColors._();
  static const Color purple = Color(0xFF7C3AED);
  static const Color purpleDark = Color(0xFF5B21B6);
  static const Color purpleLight = Color(0xFFEDE9FE);
  static const Color ink = Color(0xFF1F2937);
  static const Color body = Color(0xFF374151);
  static const Color muted = Color(0xFF6B7280);
  static const Color faint = Color(0xFF9CA3AF);
  static const Color page = Color(0xFFF4F6FB);
  static const Color green = Color(0xFF059669);
  static const Color greenLight = Color(0xFFD1FAE5);
  static const Color red = Color(0xFFDC2626);
  static const Color redLight = Color(0xFFFEE2E2);
  static const Color amber = Color(0xFFD97706);
  static const Color amberLight = Color(0xFFFEF3C7);

  static const LinearGradient header = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1E0640), Color(0xFF3B0764), Color(0xFF5B21B6)],
  );
  static const LinearGradient accent = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFA78BFA), Color(0xFF7C3AED)],
  );
}

/// White rounded card with the app's soft shadow.
BoxDecoration sarthiCard({Color color = Colors.white, double radius = 18, Color? border}) => BoxDecoration(
  color: color,
  borderRadius: BorderRadius.circular(radius),
  border: border == null ? null : Border.all(color: border),
  boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 10, offset: Offset(0, 3))],
);

/// Gradient app bar for pushed screens (back arrow, title, optional subtitle).
class SarthiAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String subtitle;
  final List<Widget> actions;
  final bool showBack;
  const SarthiAppBar({
    super.key,
    required this.title,
    this.subtitle = '',
    this.actions = const [],
    this.showBack = true,
  });

  @override
  Size get preferredSize => Size.fromHeight(subtitle.isEmpty ? 60 : 68);

  @override
  Widget build(BuildContext context) {
    final canPop = showBack && Navigator.of(context).canPop();
    return Container(
      decoration: const BoxDecoration(gradient: SarthiColors.header),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: preferredSize.height,
          child: Row(children: [
            if (canPop)
              IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                splashRadius: 22,
              )
            else
              const SizedBox(width: 20),
            Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                if (subtitle.isNotEmpty)
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.75))),
              ]),
            ),
            ...actions,
            const SizedBox(width: 8),
          ]),
        ),
      ),
    );
  }
}

/// Round translucent icon button for use inside gradient headers.
class SarthiHeaderButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool active;
  const SarthiHeaderButton({super.key, required this.icon, this.onTap, this.active = false});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 36,
      height: 36,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: active ? Colors.white : Colors.white.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: active ? SarthiColors.purple : Colors.white, size: 18),
    ),
  );
}

/// Big gradient header for bottom-nav tabs: title, optional pill tabs, and the
/// rounded "sheet" edge the page content sits on.
class SarthiTabHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final TabController? tabController;
  final List<String> tabs;
  final List<Widget> actions;
  final Widget? below;
  const SarthiTabHeader({
    super.key,
    required this.title,
    this.subtitle = '',
    this.tabController,
    this.tabs = const [],
    this.actions = const [],
    this.below,
  });

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Container(
      decoration: const BoxDecoration(gradient: SarthiColors.header),
      child: SafeArea(
        bottom: false,
        child: Column(children: [
          Padding(
            padding: EdgeInsets.fromLTRB(canPop ? 8 : 20, 10, 16, 10),
            child: Row(children: [
              if (canPop)
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                  splashRadius: 22,
                ),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 19, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.2)),
                  if (subtitle.isNotEmpty)
                    Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.72))),
                ]),
              ),
              ...actions,
            ]),
          ),
          if (below != null) below!,
          if (tabController != null && tabs.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SarthiPillTabs(controller: tabController!, tabs: tabs),
            ),
          Container(
            height: 24,
            margin: const EdgeInsets.only(top: 10),
            decoration: const BoxDecoration(
              color: SarthiColors.page,
              borderRadius: BorderRadius.only(topLeft: Radius.circular(26), topRight: Radius.circular(26)),
            ),
          ),
        ]),
      ),
    );
  }
}

/// White pill tab bar used inside gradient headers.
class SarthiPillTabs extends StatelessWidget {
  final TabController controller;
  final List<String> tabs;
  const SarthiPillTabs({super.key, required this.controller, required this.tabs});

  @override
  Widget build(BuildContext context) => Container(
    height: 42,
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.13),
      borderRadius: BorderRadius.circular(26),
    ),
    padding: const EdgeInsets.all(3),
    child: TabBar(
      controller: controller,
      indicator: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 2))],
      ),
      indicatorPadding: EdgeInsets.zero,
      dividerColor: Colors.transparent,
      indicatorSize: TabBarIndicatorSize.tab,
      labelColor: SarthiColors.purple,
      unselectedLabelColor: Colors.white.withValues(alpha: 0.70),
      labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12.5),
      tabs: [for (final t in tabs) Tab(text: t)],
    ),
  );
}

/// Small rounded label, e.g. a booking status.
class SarthiChip extends StatelessWidget {
  final String text;
  final Color color;
  final Color? background;
  final IconData? icon;
  const SarthiChip(this.text, {super.key, required this.color, this.background, this.icon});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: background ?? color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
    ),
    // One Text (icon as a WidgetSpan) so long labels end with "…" when space is tight.
    child: Text.rich(
      TextSpan(children: [
        if (icon != null)
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(padding: const EdgeInsets.only(right: 3), child: Icon(icon, size: 11, color: color)),
          ),
        TextSpan(text: text),
      ]),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: color),
    ),
  );
}

/// Grey uppercase section label.
class SarthiSectionLabel extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SarthiSectionLabel(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 10, 2, 8),
    child: Row(children: [
      Expanded(
        child: Text(text.toUpperCase(),
            style: const TextStyle(
                fontSize: 10.5, fontWeight: FontWeight.bold, color: SarthiColors.faint, letterSpacing: 1.2)),
      ),
      if (trailing != null) trailing!,
    ]),
  );
}

/// Centered icon + message for empty lists.
class SarthiEmpty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  const SarthiEmpty({super.key, required this.icon, required this.title, this.message = '', this.action});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 120),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 76,
          height: 76,
          decoration: const BoxDecoration(color: SarthiColors.purpleLight, shape: BoxShape.circle),
          child: Icon(icon, size: 34, color: SarthiColors.purple),
        ),
        const SizedBox(height: 16),
        Text(title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: SarthiColors.ink)),
        if (message.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12.5, color: SarthiColors.faint, height: 1.45)),
        ],
        if (action != null) ...[const SizedBox(height: 16), action!],
      ]),
    ),
  );
}

/// Circle avatar with a photo, or the first letter on the purple gradient.
class SarthiAvatar extends StatelessWidget {
  final String name;
  final String photoUrl;
  final double size;
  final bool dimmed;
  const SarthiAvatar({super.key, required this.name, this.photoUrl = '', this.size = 48, this.dimmed = false});

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    return Opacity(
      opacity: dimmed ? 0.5 : 1,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: SarthiColors.accent,
          image: photoUrl.isNotEmpty ? DecorationImage(image: NetworkImage(photoUrl), fit: BoxFit.cover) : null,
        ),
        child: photoUrl.isEmpty
            ? Center(
            child: Text(initial,
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: size * 0.38)))
            : null,
      ),
    );
  }
}

/// Full-width gradient button.
class SarthiButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool busy;
  final List<Color>? colors;
  const SarthiButton({super.key, required this.label, this.icon, this.onPressed, this.busy = false, this.colors});

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: GestureDetector(
        onTap: enabled ? onPressed : null,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: colors ?? const [Color(0xFF6D28D9), Color(0xFF8B5CF6)]),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(color: Color(0x337C3AED), blurRadius: 12, offset: Offset(0, 4))],
          ),
          child: Center(
            child: busy
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Row(mainAxisSize: MainAxisSize.min, children: [
              if (icon != null) ...[Icon(icon, color: Colors.white, size: 18), const SizedBox(width: 8)],
              Text(label, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// "12:40", "Yesterday", "3/10".
String sarthiShortTime(DateTime? dt) {
  if (dt == null) return '';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(dt.year, dt.month, dt.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    return '$h:${dt.minute.toString().padLeft(2, '0')} ${dt.hour < 12 ? 'AM' : 'PM'}';
  }
  if (diff == 1) return 'Yesterday';
  return '${dt.day}/${dt.month}';
}