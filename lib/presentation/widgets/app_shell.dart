import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    required this.color,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String tooltip;

  /// Signpost sign color for this destination, echoing the color-coded
  /// arrow signs in IKeriKin's storybook branding art.
  final Color color;
}

/// Navigation shell shared by primary application destinations, styled as a
/// colorful storybook signpost.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  static const _destinations = [
    _Destination(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      label: 'Home',
      tooltip: 'Home dashboard',
      color: AppTheme.brandAmber,
    ),
    _Destination(
      icon: Icons.menu_book_outlined,
      selectedIcon: Icons.menu_book_rounded,
      label: 'Lessons',
      tooltip: 'Browse the lesson library',
      color: Color(0xFF6FCB6A),
    ),
    _Destination(
      icon: Icons.auto_awesome_outlined,
      selectedIcon: Icons.auto_awesome_rounded,
      label: 'Create',
      tooltip: 'Create an AI lesson',
      color: AppTheme.brandCoral,
    ),
    _Destination(
      icon: Icons.insights_outlined,
      selectedIcon: Icons.insights_rounded,
      label: 'Progress',
      tooltip: 'View learning progress',
      color: AppTheme.brandTeal,
    ),
    _Destination(
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
      label: 'Profile',
      tooltip: 'Child profile and settings',
      color: AppTheme.brandPink,
    ),
  ];

  void _go(BuildContext context, int index) {
    if (!prefersReducedMotion(context)) HapticFeedback.selectionClick();
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
        onSelected: (index) => _go(context, index),
      ),
    );
  }
}

/// Bottom navigation styled as a wooden signpost: a warm plank bar carrying
/// a row of color-coded arrow-shaped signs, one per destination.
class _SignpostNavBar extends StatefulWidget {
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

  /// Text style used for the revealed label, kept in sync with [_SignItem]
  /// so width measurements below match what actually gets painted.
  static const _labelStyle = TextStyle(
    fontWeight: FontWeight.w800,
    fontSize: 12,
  );

  /// Measures how much extra width a destination's label needs once
  /// revealed, so long names like "Progress" never get clipped and short
  /// ones like "Home" don't carry unused blank space.
  static double _labelExtra(String label) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: _labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    return painter.width + 7 /* left padding */ + 6 /* breathing room */;
  }

  @override
  State<_SignpostNavBar> createState() => _SignpostNavBarState();
}

class _SignpostNavBarState extends State<_SignpostNavBar> {
  // A mouse hovering a sign previews it the same way selecting it does,
  // instead of popping up a separate tooltip bubble.
  int? _hoveredIndex;

  void _setHovered(int index, bool hovering) {
    setState(() {
      if (hovering) {
        _hoveredIndex = index;
      } else if (_hoveredIndex == index) {
        _hoveredIndex = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: dark
              ? const [Color(0xFF5C4022), Color(0xFF3E2A16)]
              : const [Color(0xFFC08552), Color(0xFF8C5A34)],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
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
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 10, 6, 6),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final revealed = <int>{widget.currentIndex, ?_hoveredIndex};
              final revealedExtra = revealed.fold<double>(
                0,
                (sum, index) =>
                    sum +
                    _SignpostNavBar._labelExtra(
                      widget.destinations[index].label,
                    ),
              );
              final paddingOverhead =
                  widget.destinations.length * 2 * _SignItem.horizontalPadding;
              final compactWidth =
                  (constraints.maxWidth - revealedExtra - paddingOverhead) /
                  widget.destinations.length;
              return Row(
                children: [
                  for (final (index, destination) in widget.destinations.indexed)
                    _SignItem(
                      key: ValueKey(destination.label),
                      destination: destination,
                      selected: index == widget.currentIndex,
                      active: revealed.contains(index),
                      large: widget.large,
                      compactWidth: compactWidth,
                      expandedExtra: _SignpostNavBar._labelExtra(
                        destination.label,
                      ),
                      onTap: () => widget.onSelected(index),
                      onHoverChanged: (hovering) =>
                          _setHovered(index, hovering),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// A single signpost sign: icon-only at rest, so a row of five reads as a
/// clean row of arrow markers on any device — then widens to reveal its
/// name once tapped, so the current destination is never ambiguous.
class _SignItem extends StatelessWidget {
  const _SignItem({
    super.key,
    required this.destination,
    required this.selected,
    required this.active,
    required this.large,
    required this.compactWidth,
    required this.expandedExtra,
    required this.onTap,
    required this.onHoverChanged,
  });

  final _Destination destination;
  final bool selected;

  /// Whether this sign should currently show its expanded, label-revealing
  /// state — true when [selected], and also true while a mouse hovers it,
  /// so pointing at a sign previews it the same way tapping it does instead
  /// of popping up a separate tooltip.
  final bool active;
  final bool large;
  final double compactWidth;
  final double expandedExtra;
  final VoidCallback onTap;
  final ValueChanged<bool> onHoverChanged;

  /// Horizontal breathing room on each side of a sign. Callers computing
  /// how much width is available for signs must subtract this too, or the
  /// row overflows by exactly `2 * horizontalPadding * destinations.length`.
  static const horizontalPadding = 3.0;

  @override
  Widget build(BuildContext context) {
    final reduced = prefersReducedMotion(context);
    final baseHeight = large ? 66.0 : 56.0;
    return MouseRegion(
      onEnter: (_) => onHoverChanged(true),
      onExit: (_) => onHoverChanged(false),
      child: Semantics(
        button: true,
        selected: selected,
        label: destination.tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: active ? 1 : 0),
            duration: reduced
                ? Duration.zero
                : const Duration(milliseconds: 260),
            curve: Curves.easeOutBack,
            builder: (context, t, _) {
              // The bouncy overshoot in [t] is intentional for the pop/tilt
              // effects below, but width and opacity reject values outside
              // 0..1, so they use a clamped copy instead.
              final reveal = t.clamp(0.0, 1.0);
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                ),
                child: Transform.translate(
                  offset: Offset(0, -6 * t),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: compactWidth + expandedExtra * reveal,
                      height: baseHeight + 6 * t,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            destination.color.withValues(
                              alpha: .4 + .5 * t,
                            ),
                            destination.color.withValues(
                              alpha: .12 + .18 * t,
                            ),
                          ],
                        ),
                        boxShadow: t <= 0.01
                            ? null
                            : [
                                BoxShadow(
                                  color: destination.color.withValues(
                                    alpha: .45,
                                  ),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _NavIcon(
                            selected: selected,
                            child: destination.label == 'Create'
                                ? (selected
                                      ? const GeminiSparkleIcon(size: 22)
                                      : const _PulsingSparkle(size: 20))
                                : Icon(
                                    selected
                                        ? destination.selectedIcon
                                        : destination.icon,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                          ),
                          ClipRect(
                            child: SizedBox(
                              width: expandedExtra * reveal,
                              child: OverflowBox(
                                minWidth: 0,
                                maxWidth: expandedExtra + 60,
                                alignment: Alignment.centerLeft,
                                child: Opacity(
                                  opacity: reveal,
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 7),
                                    child: Text(
                                      destination.label,
                                      maxLines: 1,
                                      softWrap: false,
                                      overflow: TextOverflow.clip,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Pops the destination icon in with a playful overshoot when it becomes
/// selected, instead of the flat swap Material gives by default.
class _NavIcon extends StatelessWidget {
  const _NavIcon({required this.selected, required this.child});
  final bool selected;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (prefersReducedMotion(context)) return child;
    return TweenAnimationBuilder<double>(
      key: ValueKey(selected),
      tween: Tween(begin: selected ? 0.6 : 1, end: 1),
      duration: const Duration(milliseconds: 320),
      curve: Curves.elasticOut,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: child,
    );
  }
}

/// A gentle, continuous breathing pulse on the Create tab's sparkle mark so
/// it quietly invites a tap without demanding attention.
class _PulsingSparkle extends StatefulWidget {
  const _PulsingSparkle({required this.size});
  final double size;

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
      child: GeminiSparkleIcon(size: widget.size),
      builder: (context, child) => Transform.scale(
        scale: 1 + Curves.easeInOut.transform(_controller.value) * .12,
        child: child,
      ),
    );
  }
}
