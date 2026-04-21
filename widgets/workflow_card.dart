// widgets/workflow_card.dart
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_config.dart';
import '../state/app_state.dart';

class WorkflowCard extends StatefulWidget {
  const WorkflowCard({super.key});

  @override
  State<WorkflowCard> createState() => _WorkflowCardState();
}

const double _baseHeight = 95;

class _WorkflowCardState extends State<WorkflowCard>
    with TickerProviderStateMixin {
  static const _modes = WorkflowMode.values;

  late final Map<WorkflowMode, AnimationController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = {
      WorkflowMode.sleep: AnimationController(
        vsync: this,
        duration: const Duration(seconds: 10),
      )..repeat(),
      WorkflowMode.relax: AnimationController(
        vsync: this,
        duration: const Duration(seconds: 4),
      )..repeat(reverse: true),
      WorkflowMode.work: AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1400),
      )..repeat(reverse: true),
    };
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _swipe(DragEndDetails details, AppState appState) {
    final dx = details.primaryVelocity ?? 0;
    if (dx == 0) return;
    final current = AppSettings.instance.workflowM;
    final idx = _modes.indexOf(current);
    final next = (idx + (dx < 0 ? 1 : -1)).clamp(0, _modes.length - 1);
    if (next == idx) return;
    appState.setWorkflowMode(_modes[next]);
  }

  void _tap(int dir, AppState appState) {
    final idx = _modes.indexOf(AppSettings.instance.workflowM);
    final next = (idx + dir).clamp(0, _modes.length - 1);
    if (next == idx) return;
    appState.setWorkflowMode(_modes[next]);
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final current = AppSettings.instance.workflowM;
    final idx = _modes.indexOf(current);
    final anim = _controllers[current]!;

    return GestureDetector(
      onHorizontalDragEnd: (d) => _swipe(d, appState),
      child: SizedBox(
        height: _baseHeight * 2,
        child: Card(
          elevation: 10,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(AppConfig.instance.cardBorderRadius),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                _ArrowButton(
                  direction: -1,
                  visible: idx > 0,
                  onTap: () => _tap(-1, appState),
                ),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.max, // was min
                    mainAxisAlignment: MainAxisAlignment
                        .spaceBetween, // push dots up, icon down
                    children: [
                      _DotsRow(modes: _modes, current: current),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _ModeIcon(mode: current, animation: anim),
                          const SizedBox(width: 30),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: Text(
                              key: ValueKey(current),
                              _label(current),
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4), // bottom breathing room
                    ],
                  ),
                ),
                _ArrowButton(
                  direction: 1,
                  visible: idx < _modes.length - 1,
                  onTap: () => _tap(1, appState),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _label(WorkflowMode mode) => switch (mode) {
        WorkflowMode.sleep => 'Spánek',
        WorkflowMode.relax => 'Relax',
        WorkflowMode.work => 'Práce',
      };
}

// ── Dots ──────────────────────────────────────────────────────────────────────

class _DotsRow extends StatelessWidget {
  const _DotsRow({required this.modes, required this.current});
  final List<WorkflowMode> modes;
  final WorkflowMode current;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: modes.map((m) {
        final active = m == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 22 : 7,
          height: 7,
          decoration: BoxDecoration(
            color: active
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).dividerColor,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }).toList(),
    );
  }
}

// ── Arrow button ──────────────────────────────────────────────────────────────

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({
    required this.direction,
    required this.visible,
    required this.onTap,
  });
  final int direction;
  final bool visible;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: visible ? 1.0 : 0.0,
      child: GestureDetector(
        onTap: visible ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Theme.of(context).cardTheme.color ??
                Theme.of(context).scaffoldBackgroundColor,
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Icon(
            direction < 0 ? Icons.chevron_left : Icons.chevron_right,
            size: 18,
            color: Theme.of(context).iconTheme.color?.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}

// ── Animated icons ────────────────────────────────────────────────────────────

class _ModeIcon extends StatelessWidget {
  const _ModeIcon({required this.mode, required this.animation});
  final WorkflowMode mode;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: SizedBox(
        key: ValueKey(mode),
        width: 55, // Standardized width
        height: 55, // Standardized height
        child: Center(
          // Wrap in Center to ensure CustomPaint isn't stretching
          child: switch (mode) {
            WorkflowMode.sleep =>
              _SleepIcon(animation: animation, iconSize: 72),
            WorkflowMode.relax => _RelaxIcon(animation: animation),
            WorkflowMode.work => _WorkIcon(animation: animation),
          },
        ),
      ),
    );
  }
}

// Sleep: moon + sun arc glowing past every 10s
class _SleepIcon extends StatelessWidget {
  const _SleepIcon({required this.animation, this.iconSize = 72.0});
  final Animation<double> animation;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final s = iconSize / 32;
    final color = Theme.of(context).iconTheme.color ?? Colors.black;
    return AnimatedBuilder(
      animation: animation,
      builder: (_, __) {
        final t = animation.value; // 0..1 over 10s
        // Sun passes from ~t=0.1 to t=0.9 behind the moon
        final sunOpacity = (t < 0.1 || t > 0.9)
            ? 0.0
            : (t < 0.5 ? (t - 0.1) / 0.4 : (0.9 - t) / 0.4).clamp(0.0, 1.0);
        final sunAngle = (t * 2 * 3.14159) - 1.2;
        final moonBrightness = 1.0 + sunOpacity * 0.6;

        return Stack(
          alignment: Alignment.center,
          children: [
            // Sun arc
            Transform.translate(
              offset: Offset(
                  18 * s * (sunAngle.abs() < 1.5 ? sunAngle : 0), -8 * s),
              child: Opacity(
                opacity: sunOpacity * 0.7,
                child: Container(
                  width: 8 * s,
                  height: 8 * s,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFFFD966),
                  ),
                ),
              ),
            ),
            // Moon
            CustomPaint(
              size: const Size(48, 48),
              painter: _MoonPainter(
                color: color,
                brightness: moonBrightness,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MoonPainter extends CustomPainter {
  const _MoonPainter({required this.color, required this.brightness});
  final Color color;
  final double brightness;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final s = size.width / 32;
    final paint = Paint()
      ..color = Color.lerp(
          color, const Color(0xFFFFD966), (brightness - 1).clamp(0, 1))!
      ..style = PaintingStyle.fill;

    final path = Path()
      ..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: 9 * s))
      ..addOval(Rect.fromCircle(
          center: Offset(cx + 5 * s, cy - 1 * s), radius: 7 * s));
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        path,
        Path()
          ..addOval(Rect.fromCircle(
              center: Offset(cx + 5 * s, cy - 1 * s), radius: 7 * s)),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(_MoonPainter old) =>
      old.brightness != brightness || old.color != color;
}

// Relax: figure breathes — body bobs, aura pulses
class _RelaxIcon extends StatelessWidget {
  const _RelaxIcon({required this.animation});
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).iconTheme.color ?? Colors.black;
    final wave = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: animation, curve: Curves.easeInOut),
    );
    return AnimatedBuilder(
      animation: wave,
      builder: (_, __) => CustomPaint(
        size: const Size(72, 72), // Standardized to 72
        painter: _RelaxPainter(color: color, t: wave.value),
      ),
    );
  }
}

class _RelaxPainter extends CustomPainter {
  const _RelaxPainter({required this.color, required this.t});
  final Color color;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final s = size.width / 32;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8 * s
      ..strokeCap = StrokeCap.round;

    final sunR = (5.5 + t * 1.0) * s;
    canvas.drawCircle(Offset(cx, cy - 4 * s), sunR, paint);

    for (int i = 0; i < 6; i++) {
      final angle = (i / 6) * 2 * pi;
      final inner = sunR + 2.5 * s;
      final outer = sunR + 4.0 * s + t * 2.0 * s;
      canvas.drawLine(
        Offset(cx + cos(angle) * inner, cy - 4 * s + sin(angle) * inner),
        Offset(cx + cos(angle) * outer, cy - 4 * s + sin(angle) * outer),
        paint..strokeWidth = 1.4 * s,
      );
    }

    final waveY1 = cy + 6.0 * s + sin(t * pi) * 1.5 * s;
    final waveY2 = cy + 10.5 * s + sin(t * pi + 0.8) * 1.5 * s;

    for (final wy in [waveY1, waveY2]) {
      final wavePath = Path()
        ..moveTo(cx - 9 * s, wy)
        ..cubicTo(
            cx - 5 * s, wy - 2.5 * s, cx - 1 * s, wy + 2.5 * s, cx + 3 * s, wy)
        ..cubicTo(
            cx + 5 * s, wy - 1.5 * s, cx + 7 * s, wy + 1.5 * s, cx + 9 * s, wy);
      canvas.drawPath(wavePath, paint..strokeWidth = 1.6 * s);
    }
  }

  @override
  bool shouldRepaint(_RelaxPainter old) => old.t != t || old.color != color;
}

// Work: briefcase swings from handle pivot
class _WorkIcon extends StatelessWidget {
  const _WorkIcon({required this.animation});
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).iconTheme.color ?? Colors.black;
    final swing = Tween<double>(begin: -0.16, end: 0.16).animate(
      CurvedAnimation(parent: animation, curve: Curves.easeInOut),
    );
    return AnimatedBuilder(
      animation: swing,
      builder: (_, __) => Transform.rotate(
        angle: swing.value,
        origin: const Offset(0, -30), // was -10, scale with icon size
        child: CustomPaint(
          size: const Size(72, 72),
          painter: _BagPainter(color: color),
        ),
      ),
    );
  }
}

class _BagPainter extends CustomPainter {
  const _BagPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final s = size.width / 32; // scale factor
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final handlePath = Path()
      ..moveTo(cx - 4 * s, cy - 2 * s)
      ..quadraticBezierTo(cx - 4 * s, cy - 7 * s, cx, cy - 7 * s)
      ..quadraticBezierTo(cx + 4 * s, cy - 7 * s, cx + 4 * s, cy - 2 * s);
    canvas.drawPath(handlePath, paint);

    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: Offset(cx, cy + 3 * s), width: 16 * s, height: 12 * s),
      Radius.circular(2.5 * s),
    );
    canvas.drawRRect(bodyRect, paint);

    canvas.drawLine(Offset(cx - 8 * s, cy + 3 * s),
        Offset(cx + 8 * s, cy + 3 * s), paint..strokeWidth = 1.4 * s);
    canvas.drawLine(Offset(cx, cy + 3 * s), Offset(cx, cy + 6 * s), paint);
  }

  @override
  bool shouldRepaint(_BagPainter old) => old.color != color;
}
