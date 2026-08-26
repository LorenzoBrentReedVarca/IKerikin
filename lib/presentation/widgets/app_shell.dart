import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:go_router/go_router.dart';

import '../../application/providers.dart';
import '../../core/theme/app_theme.dart';
import 'common_widgets.dart';

/// A primary application destination rendered in the bottom bar.
class _Destination {
  const _Destination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.tooltip,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String tooltip;
}

/// Navigation shell shared by primary application destinations, styled after
/// Kombai's wooden dock: a solid warm plank bar carrying five always-labeled
/// stops, with the active stop lit by a violet pill.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  static const _destinations = [
    _Destination(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      label: 'Home',
      tooltip: 'Home dashboard',
    ),
    _Destination(
      icon: Icons.menu_book_outlined,
      selectedIcon: Icons.menu_book_rounded,
      label: 'Lessons',
      tooltip: 'Browse the lesson library',
    ),
    _Destination(
      icon: Icons.auto_fix_high_outlined,
      selectedIcon: Icons.auto_fix_high_rounded,
      label: 'Create',
      tooltip: 'Create an AI lesson',
    ),
    _Destination(
      icon: Icons.insights_outlined,
      selectedIcon: Icons.insights_rounded,
      label: 'Progress',
      tooltip: 'View learning progress',
    ),
    _Destination(
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
      label: 'Profile',
      tooltip: 'Child profile and settings',
    ),
  ];

  static final FlutterTts _tts = FlutterTts();

  void _go(BuildContext context, WidgetRef ref, int index) {
    if (!prefersReducedMotion(context)) HapticFeedback.selectionClick();
    if (index != navigationShell.currentIndex &&
        ref.read(accessibilityProvider).voiceNavigation) {
      _tts.speak(_destinations[index].label);
    }
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final largeButtons = ref.watch(accessibilityProvider).largeButtons;
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: _SignpostNavBar(
        key: const ValueKey('primary-navigation'),
        currentIndex: navigationShell.currentIndex,
        destinations: _destinations,
        large: largeButtons,
        onSelected: (index) => _go(context, ref, index),
      ),
    );
  }
}

/// Bottom navigation styled after Kombai's wooden dock: a solid warm plank
/// bar with all five stops always labeled, and the active stop lit by a
/// violet pill.
class _SignpostNavBar extends StatelessWidget {
  const _SignpostNavBar({
    super.key,
    required this.currentIndex,
    required this.destinations,
    required this.large,
    required this.onSelected,
  });

  final int currentIndex;
  final List<_Destination> destinations;
  final bool large;
  final ValueChanged<int> onSelected;

  static const _woodDark = Color(0xFF5D3D28);
  static const _woodDarkNight = Color(0xFF3E2A16);

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: dark ? _woodDarkNight : _woodDark,
        border: const Border(top: BorderSide(color: Color(0x7A2F1C10))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? .4 : .22),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: large ? 88 : 74,
          child: Row(
            children: [
              for (final (index, destination) in destinations.indexed)
                Expanded(
                  child: _DockItem(
                    key: ValueKey(destination.label),
                    destination: destination,
                    selected: index == currentIndex,
                    onTap: () => onSelected(index),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A single dock stop: icon above label, always visible, with the active
/// stop lit by a violet pill — matching Kombai's `.dock-item` treatment.
class _DockItem extends StatelessWidget {
  const _DockItem({
    super.key,
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _Destination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final reduced = prefersReducedMotion(context);
    final labelColor = selected
        ? Colors.white
        : const Color(0xFFFFF8F0).withValues(alpha: .82);
    return Semantics(
      button: true,
      selected: selected,
      label: destination.tooltip,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 3),
          child: AnimatedContainer(
            duration: reduced
                ? Duration.zero
                : const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: selected ? AppTheme.brandViolet : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                destination.label == 'Create' && !selected
                    ? _PulsingSparkle(
                        size: 22,
                        icon: destination.icon,
                        color: labelColor,
                      )
                    : Icon(
                        selected ? destination.selectedIcon : destination.icon,
                        color: labelColor,
                        size: 22,
                      ),
                const SizedBox(height: 2),
                Text(
                  destination.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: labelColor,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A gentle, continuous breathing pulse on the Create tab's wand mark so
/// it quietly invites a tap without demanding attention.
class _PulsingSparkle extends StatefulWidget {
  const _PulsingSparkle({
    required this.size,
    required this.icon,
    required this.color,
  });
  final double size;
  final IconData icon;
  final Color color;

  @override
  State<_PulsingSparkle> createState() => _PulsingSparkleState();
}

class _PulsingSparkleState extends State<_PulsingSparkle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (prefersReducedMotion(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: Icon(widget.icon, size: widget.size, color: widget.color),
      builder: (context, child) => Transform.scale(
        scale: 1 + Curves.easeInOut.transform(_controller.value) * .12,
        child: child,
      ),
    );
  }
}
