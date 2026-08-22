import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'common_widgets.dart';

/// Identifies which playful backdrop a screen should use, so every tab in
/// the app reads as its own colorful place rather than a repeated shell.
enum SceneKind { home, learn, create, progress, profile, dictionary }

class _SceneConfig {
  const _SceneConfig({required this.colors, required this.icons});

  final List<Color> colors;
  final List<IconData> icons;
}

const Map<SceneKind, _SceneConfig> _scenes = {
  SceneKind.home: _SceneConfig(
    colors: [AppTheme.brandTeal, AppTheme.brandAmber, AppTheme.brandViolet],
    icons: [
      Icons.cloud_rounded,
      Icons.wb_sunny_rounded,
      Icons.star_rounded,
      Icons.favorite_rounded,
    ],
  ),
  SceneKind.learn: _SceneConfig(
    colors: [AppTheme.brandViolet, AppTheme.brandPink],
    icons: [
      Icons.menu_book_rounded,
      Icons.edit_rounded,
      Icons.star_rounded,
      Icons.lightbulb_rounded,
    ],
  ),
  SceneKind.create: _SceneConfig(
    colors: [AppTheme.brandAmber, AppTheme.brandCoral, AppTheme.brandPink],
    icons: [
      Icons.auto_awesome_rounded,
      Icons.star_rounded,
      Icons.bolt_rounded,
      Icons.celebration_rounded,
    ],
  ),
  SceneKind.progress: _SceneConfig(
    colors: [AppTheme.brandTeal, AppTheme.brandAmber],
    icons: [
      Icons.emoji_events_rounded,
      Icons.military_tech_rounded,
      Icons.star_rounded,
      Icons.local_fire_department_rounded,
    ],
  ),
  SceneKind.profile: _SceneConfig(
    colors: [AppTheme.brandPink, AppTheme.brandCoral],
    icons: [
      Icons.favorite_rounded,
      Icons.pets_rounded,
      Icons.star_rounded,
      Icons.emoji_emotions_rounded,
    ],
  ),
  SceneKind.dictionary: _SceneConfig(
    colors: [AppTheme.brandViolet, AppTheme.brandTeal],
    icons: [
      Icons.abc_rounded,
      Icons.translate_rounded,
      Icons.menu_book_rounded,
      Icons.star_rounded,
    ],
  ),
};

class _Sprite {
  const _Sprite({
    required this.icon,
    required this.x,
    required this.size,
    required this.loops,
    required this.phase,
    required this.sway,
    required this.colorIndex,
  });

  final IconData icon;
  final double x;
  final double size;
  final int loops;
  final double phase;
  final double sway;
  final int colorIndex;
}

List<_Sprite> _buildSprites(SceneKind scene) {
  final config = _scenes[scene]!;
  final rand = math.Random(scene.index * 97 + 13);
  return List.generate(7, (i) {
    return _Sprite(
      icon: config.icons[i % config.icons.length],
      x: rand.nextDouble(),
      size: 14 + rand.nextDouble() * 14,
      loops: 1 + rand.nextInt(2),
      phase: rand.nextDouble(),
      sway: 10 + rand.nextDouble() * 18,
      colorIndex: i % config.colors.length,
    );
  });
}

/// A themed, gently animated backdrop for a full screen: a tinted aurora
/// wash plus a scene-specific cast of floating icons, and — on Home — a
/// pair of running dogs and a child curled up reading a book. Everything
/// paints at low opacity behind [child] and freezes when the platform asks
/// for reduced motion.
class SceneBackground extends StatefulWidget {
  const SceneBackground({
    super.key,
    required this.scene,
    required this.child,
    this.intensity = 1,
  });

  final SceneKind scene;
  final Widget child;
  final double intensity;

  @override
  State<SceneBackground> createState() => _SceneBackgroundState();
}

class _SceneBackgroundState extends State<SceneBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 28),
  )..repeat();
  late final List<_Sprite> _sprites = _buildSprites(widget.scene);
  bool _reduced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = prefersReducedMotion(context);
    if (reduced != _reduced) {
      _reduced = reduced;
      if (reduced) {
        _controller.stop();
      } else if (!_controller.isAnimating) {
        _controller.repeat();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = _scenes[widget.scene]!;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AuroraBackground(
      intensity: widget.intensity,
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) => CustomPaint(
                    painter: _ScenePainter(
                      t: _controller.value,
                      config: config,
                      sprites: _sprites,
                      dark: dark,
                    ),
                  ),
                ),
              ),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

class _ScenePainter extends CustomPainter {
  _ScenePainter({
    required this.t,
    required this.config,
    required this.sprites,
    required this.dark,
  });

  final double t;
  final _SceneConfig config;
  final List<_Sprite> sprites;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    _paintSprites(canvas, size);
  }

  void _paintSprites(Canvas canvas, Size size) {
    for (final sprite in sprites) {
      final local = (t * sprite.loops + sprite.phase) % 1.0;
      final y = size.height * (1 - local);
      final x =
          size.width * sprite.x +
          math.sin(local * math.pi * 2) * sprite.sway;
      final alpha = (math.sin(local * math.pi) * (dark ? 0.22 : 0.16)).clamp(
        0.0,
        1.0,
      );
      if (alpha <= 0.01) continue;
      final color = config.colors[sprite.colorIndex % config.colors.length]
          .withValues(alpha: alpha);
      final painter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(sprite.icon.codePoint),
          style: TextStyle(
            fontSize: sprite.size,
            fontFamily: sprite.icon.fontFamily,
            package: sprite.icon.fontPackage,
            color: color,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(canvas, Offset(x - painter.width / 2, y - painter.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _ScenePainter oldDelegate) => oldDelegate.t != t;
}
