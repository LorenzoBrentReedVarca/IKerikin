import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';

/// Soft aurora-style backdrop behind screen content.
///
/// Wrap a Scaffold body with this to add depth and warmth without competing
/// with the content on top.
class AuroraBackground extends StatelessWidget {
  const AuroraBackground({super.key, required this.child, this.intensity = 1});

  final Widget child;

  /// 0..1 multiplier for how strongly the backdrop tint shows through.
  final double intensity;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final wash = intensity.clamp(0.0, 1.0);
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: AppTheme.auroraGradient(context),
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  scheme.surface.withValues(alpha: dark ? .35 : .28),
                  scheme.surface.withValues(
                    alpha: (dark ? .62 : .52) + ((1 - wash) * .18),
                  ),
                ],
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// Route header used at the top of every interior screen, styled after
/// Kombai's `.route-bar`: a plain, near-white bar carrying the small
/// rainbow IKeriKin wordmark, a short kicker and title, and a row of
/// page-level action buttons — never the big gradient hero the Home tab
/// uses for its own masthead.
class HeroBanner extends StatelessWidget {
  const HeroBanner({
    super.key,
    required this.title,
    this.kicker,
    this.subtitle,
    this.actions = const [],
  });
  final String title;

  /// Short uppercase label shown above [title], e.g. "Your learning space".
  final String? kicker;

  /// Optional supporting sentence shown below the title row.
  final String? subtitle;

  /// Page-level shortcut buttons (settings, search, and the like).
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: dark
            ? scheme.surfaceContainerLowest
            : Colors.white.withValues(alpha: .86),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: .5)),
      ),
      child: Row(
        children: [
          const BubbleWordmark(fontSize: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (kicker != null)
                  Text(
                    kicker!.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.3,
                    ),
                  ),
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          for (final action in actions) ...[const SizedBox(width: 6), action],
        ],
      ),
    );
  }
}

/// Multicolor AI mark used for generative actions throughout the app.
class GeminiSparkleIcon extends StatelessWidget {
  const GeminiSparkleIcon({super.key, this.size = 24});

  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: const _GeminiSparklePainter(),
  );
}

class _GeminiSparklePainter extends CustomPainter {
  const _GeminiSparklePainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF4285F4),
          Color(0xFF9B72CB),
          Color(0xFFD96570),
          Color(0xFFF4B400),
        ],
      ).createShader(Offset.zero & size);
    final center = Offset(size.width * .48, size.height * .48);
    final path = Path()
      ..moveTo(center.dx, 0)
      ..quadraticBezierTo(center.dx, center.dy, size.width, center.dy)
      ..quadraticBezierTo(center.dx, center.dy, center.dx, size.height)
      ..quadraticBezierTo(center.dx, center.dy, 0, center.dy)
      ..quadraticBezierTo(center.dx, center.dy, center.dx, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_GeminiSparklePainter oldDelegate) => false;
}

/// Storybook-style rainbow bubble-letter rendering of the app name, echoing
/// IKeriKin's illustrated branding art. Each letter gets its own brand
/// color, a white outline, and a gentle alternating tilt.
class BubbleWordmark extends StatelessWidget {
  const BubbleWordmark({super.key, this.text = 'IKeriKin', this.fontSize = 40});

  final String text;
  final double fontSize;

  static const _colors = [
    AppTheme.brandPink,
    AppTheme.brandAmber,
    Color(0xFF6FCB6A),
    AppTheme.brandTeal,
    AppTheme.brandCoral,
    AppTheme.brandViolet,
    Color(0xFFFFC24B),
    Color(0xFF4FC3F7),
  ];

  @override
  Widget build(BuildContext context) {
    final letters = text.split('');
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final (i, letter) in letters.indexed)
          Transform.rotate(
            angle: (i.isEven ? -1 : 1) * 0.06,
            child: _BubbleLetter(
              letter: letter,
              color: _colors[i % _colors.length],
              fontSize: fontSize,
            ),
          ),
      ],
    );
  }
}

/// Rainbow per-letter title text in [BubbleWordmark]'s palette, built on
/// real text layout (one [TextSpan] per letter within a single paragraph)
/// so dynamic or multi-word titles wrap at word boundaries like normal
/// text instead of splitting a word mid-letter the way a [Wrap] of
/// individually-sized letter widgets would.
class ColorfulTitle extends StatelessWidget {
  const ColorfulTitle({super.key, required this.text, this.fontSize = 24});
  final String text;
  final double fontSize;

  TextSpan _paragraph({required bool stroke}) {
    final letters = text.characters.toList();
    return TextSpan(
      children: [
        for (final (i, letter) in letters.indexed)
          TextSpan(
            text: letter,
            style: GoogleFonts.nunito(
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              height: 1.15,
              foreground: stroke
                  ? (Paint()
                      ..style = PaintingStyle.stroke
                      ..strokeWidth = fontSize * .13
                      ..color = Colors.white)
                  : null,
              color: stroke
                  ? null
                  : BubbleWordmark._colors[i % BubbleWordmark._colors.length],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Text.rich(_paragraph(stroke: true)),
      Text.rich(_paragraph(stroke: false)),
    ],
  );
}

class _BubbleLetter extends StatelessWidget {
  const _BubbleLetter({
    required this.letter,
    required this.color,
    required this.fontSize,
  });
  final String letter;
  final Color color;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final base = GoogleFonts.nunito(
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      height: 1,
    );
    return Stack(
      children: [
        Text(
          letter,
          style: base.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = fontSize * .13
              ..color = Colors.white,
          ),
        ),
        Text(letter, style: base.copyWith(color: color)),
      ],
    );
  }
}

/// Responsive centered content area with safe horizontal padding.
class ResponsiveBody extends StatelessWidget {
  const ResponsiveBody({
    super.key,
    required this.child,
    this.maxWidth = 1400,
    this.padding,
  });
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(20),
          child: child,
        ),
      ),
    ),
  );
}

/// A responsive grid that keeps dashboard items readable without hardcoding
/// phone or tablet column counts.
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    super.key,
    required this.children,
    this.minItemWidth = 150,
    this.spacing = 10,
    this.childAspectRatio = 1.25,
    this.itemHeight,
    this.staggered = true,
  });

  final List<Widget> children;
  final double minItemWidth;
  final double spacing;
  final double childAspectRatio;

  /// Fixed tile height. When set it wins over [childAspectRatio], which keeps
  /// wide rows such as profile facts from stretching on a single column.
  final double? itemHeight;

  /// Whether tiles cascade in one after another on first appearance, rather
  /// than all popping in at once.
  final bool staggered;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns =
          ((constraints.maxWidth + spacing) / (minItemWidth + spacing))
              .floor()
              .clamp(1, children.length);
      final itemWidth =
          (constraints.maxWidth - spacing * (columns - 1)) / columns;
      // Grow the tiles with the accessibility text scale so enlarged labels
      // never overflow their card.
      final scale = (MediaQuery.textScalerOf(context).scale(14) / 14).clamp(
        1.0,
        1.6,
      );
      final extent = (itemHeight ?? itemWidth / childAspectRatio) * scale;
      return GridView.count(
        crossAxisCount: columns,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: spacing,
        crossAxisSpacing: spacing,
        childAspectRatio: itemWidth / extent,
        children: staggered
            ? [
                for (final (index, child) in children.indexed)
                  AnimatedAppear(delay: staggerDelay(index), child: child),
              ]
            : children,
      );
    },
  );
}

/// Resolves a child's `gender` string to the matching illustrated avatar
/// asset, when one exists.
String? genderAvatarAsset(String? gender) {
  switch (gender?.trim().toLowerCase()) {
    case 'male':
    case 'boy':
      return 'assets/branding/boy_icon.jpg';
    case 'female':
    case 'girl':
      return 'assets/branding/girl_icon.jpg';
    default:
      return null;
  }
}

/// Child photo with a consistent fallback used throughout parent dashboards:
/// the child's own photo when set, otherwise the illustrated boy/girl mark
/// matching their profile's gender, otherwise their name's initial.
class ChildAvatar extends StatelessWidget {
  const ChildAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.gender,
    this.radius = 28,
  });

  final String name;
  final String? photoUrl;
  final String? gender;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final genderAsset = photoUrl == null ? genderAvatarAsset(gender) : null;
    final ImageProvider? backgroundImage = photoUrl != null
        ? NetworkImage(photoUrl!)
        : genderAsset != null
        ? AssetImage(genderAsset)
        : null;
    return Semantics(
      label: 'Photo of $name',
      image: true,
      child: CircleAvatar(
        radius: radius,
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        backgroundImage: backgroundImage,
        child: backgroundImage == null
            ? (name.trim().isEmpty
                  ? Icon(Icons.child_care_rounded, size: radius)
                  : Text(
                      name.trim().characters.first.toUpperCase(),
                      style: TextStyle(
                        fontSize: radius * .85,
                        fontWeight: FontWeight.w800,
                      ),
                    ))
            : null,
      ),
    );
  }
}

/// Compact section heading with an optional eyebrow label, subtitle, and
/// trailing action.
class SectionHeading extends StatelessWidget {
  const SectionHeading({
    super.key,
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.action,
  });
  final String title;
  final String? eyebrow;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (eyebrow != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    eyebrow!.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4,
                    ),
                  ),
                ),
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        ?action,
      ],
    );
  }
}

/// Bordered icon button used in a [HeroBanner]'s action row, matching
/// Kombai's `.route-action` shortcut buttons on their plain light bar.
class MastheadAction extends StatelessWidget {
  const MastheadAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      style: IconButton.styleFrom(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: .6)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius),
        ),
      ),
      icon: Icon(icon),
    );
  }
}

/// Progress indicator paired with a short explanation of what is happening.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message});
  final String? message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

/// Friendly asynchronous state renderer.
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    super.key,
    required this.value,
    required this.data,
    this.empty,
  });
  final AsyncSnapshot<T> value;
  final Widget Function(T data) data;
  final Widget? empty;

  @override
  Widget build(BuildContext context) {
    if (value.hasError) return ErrorView(message: value.error.toString());
    if (!value.hasData) return const Center(child: CircularProgressIndicator());
    return data(value.data as T);
  }
}

/// Consistent empty state for first-use experiences.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.brandViolet.withValues(alpha: .25),
                      AppTheme.brandPink.withValues(alpha: .25),
                    ],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.brandViolet.withValues(alpha: .25),
                      blurRadius: 24,
                      spreadRadius: -4,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  size: 48,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 18),
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (action != null) ...[
                const SizedBox(height: 22),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: action!,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Friendly error state with an optional retry action.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => EmptyState(
    icon: Icons.cloud_off_rounded,
    title: 'Something went wrong',
    message: message.replaceFirst('Exception: ', ''),
    action: onRetry == null
        ? null
        : FilledButton.tonal(
            onPressed: onRetry,
            child: const Text('Try again'),
          ),
  );
}

/// Adapts a decorative accent color so it stays legible in dark mode.
Color readableAccent(BuildContext context, Color accent) =>
    Theme.of(context).brightness == Brightness.dark
    ? Color.lerp(accent, Colors.white, .45)!
    : accent;

/// True when the platform or system requests reduced motion.
bool prefersReducedMotion(BuildContext context) =>
    MediaQuery.of(context).disableAnimations;

/// Fades and slides its [child] in on first build, skipping the motion when
/// the user has requested reduced motion. Pass an increasing [delay] across
/// a list of these to make the items cascade in one after another instead
/// of all popping in at once.
class AnimatedAppear extends StatefulWidget {
  const AnimatedAppear({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 420),
    this.delay = Duration.zero,
  });
  final Widget child;
  final Duration duration;
  final Duration delay;

  @override
  State<AnimatedAppear> createState() => _AnimatedAppearState();
}

class _AnimatedAppearState extends State<AnimatedAppear>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  bool _dependenciesReady = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // MediaQuery isn't available yet in initState, so the reduced-motion
    // check has to happen here instead — guarded to run only once.
    if (_dependenciesReady) return;
    _dependenciesReady = true;
    if (prefersReducedMotion(context)) {
      _controller.value = 1;
    } else if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    return AnimatedBuilder(
      animation: curved,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: curved.value,
        child: Transform.translate(
          offset: Offset(0, (1 - curved.value) * 16),
          child: child,
        ),
      ),
    );
  }
}

/// A short, fixed stagger step shared by every cascading list in the app,
/// so entrance timing feels consistent from screen to screen.
const staggerStep = Duration(milliseconds: 45);

/// Caps how many items in a long list get a staggered delay, so a 50-row
/// list doesn't take seconds to finish appearing — items past this index
/// all animate in together at the capped delay.
Duration staggerDelay(int index, {int max = 8}) =>
    staggerStep * index.clamp(0, max);

/// Wraps [child] with a playful squash-and-pop feedback on tap, making
/// buttons and cards feel more tactile for young learners. Purely visual —
/// pass [onTap] to also handle the tap; the widget still reports taps via
/// its own [GestureDetector] when no [onTap] is supplied it simply skips
/// the callback while keeping the animation on child gestures beneath it.
class BouncyTap extends StatefulWidget {
  const BouncyTap({
    super.key,
    required this.child,
    this.onTap,
    this.scale = .92,
  });
  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  @override
  State<BouncyTap> createState() => _BouncyTapState();
}

class _BouncyTapState extends State<BouncyTap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 120),
    lowerBound: 0,
    upperBound: 1,
  );

  void _set(bool pressed) {
    if (prefersReducedMotion(context)) return;
    if (pressed) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      child: AnimatedBuilder(
        animation: _controller,
        child: widget.child,
        builder: (context, child) {
          final t = Curves.easeOut.transform(_controller.value);
          final scale = 1 - (1 - widget.scale) * t;
          return Transform.scale(scale: scale, child: child);
        },
      ),
    );
  }
}

/// Animates a number counting up (or down) to [value] whenever it changes,
/// instead of the digits jumping straight to the new figure. Used for XP,
/// coins, streaks, and other stats that should feel earned rather than
/// simply displayed.
class AnimatedCounter extends StatelessWidget {
  const AnimatedCounter({
    super.key,
    required this.value,
    this.style,
    this.prefix = '',
    this.suffix = '',
    this.duration = const Duration(milliseconds: 700),
  });
  final int value;
  final TextStyle? style;
  final String prefix;
  final String suffix;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final reduced = prefersReducedMotion(context);
    return TweenAnimationBuilder<double>(
      key: ValueKey(value),
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: reduced ? Duration.zero : duration,
      curve: Curves.easeOutCubic,
      builder: (context, animated, _) =>
          Text('$prefix${animated.round()}$suffix', style: style),
    );
  }
}

/// Raises [child] slightly with a soft shadow while a mouse hovers over it,
/// giving cards and tiles a sense of depth on desktop and web. A no-op on
/// touch-only devices, since hover never fires there.
class HoverLift extends StatefulWidget {
  const HoverLift({
    super.key,
    required this.child,
    this.lift = 3,
    this.scale = 1.015,
  });
  final Widget child;
  final double lift;
  final double scale;

  @override
  State<HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<HoverLift> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final reduced = prefersReducedMotion(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: reduced ? Duration.zero : const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        transform: Matrix4.identity()
          ..translate(0.0, _hovering && !reduced ? -widget.lift : 0.0)
          ..scale(_hovering && !reduced ? widget.scale : 1.0),
        transformAlignment: Alignment.center,
        child: widget.child,
      ),
    );
  }
}

/// Labeled dashboard metric card.
class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.color,
  });
  final IconData icon;
  final String value;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = readableAccent(context, color ?? theme.colorScheme.primary);
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: HoverLift(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accent.withValues(alpha: .22),
                accent.withValues(alpha: .04),
              ],
            ),
            border: Border.all(color: accent.withValues(alpha: .22)),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: .10),
                blurRadius: 14,
                offset: const Offset(0, 6),
                spreadRadius: -8,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                  border: Border.all(color: accent.withValues(alpha: .20)),
                ),
                child: Icon(icon, size: 22, color: accent),
              ),
              const Spacer(),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(scale: animation, child: child),
                  ),
                  child: Text(
                    value,
                    key: ValueKey(value),
                    maxLines: 1,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: accent,
                    ),
                  ),
                ),
              ),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Displays feedback after the current frame to avoid build-phase mutations.
void showMessage(BuildContext context, String message, {bool error = false}) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;
    final scheme = Theme.of(context).colorScheme;
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: Duration(seconds: error ? 6 : 3),
          backgroundColor: error ? scheme.errorContainer : null,
          content: Row(
            children: [
              Icon(
                error
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_outline_rounded,
                color: error
                    ? scheme.onErrorContainer
                    : scheme.onInverseSurface,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message.replaceFirst('Exception: ', ''),
                  style: TextStyle(
                    color: error ? scheme.onErrorContainer : null,
                  ),
                ),
              ),
            ],
          ),
          action: SnackBarAction(
            label: 'Dismiss',
            textColor: error ? scheme.onErrorContainer : null,
            onPressed: messenger.hideCurrentSnackBar,
          ),
        ),
      );
  });
}
