import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

class WindSwayCard extends StatefulWidget {
  final Widget child;
  final int index;
  final Stream<void> windStream;

  const WindSwayCard({
    super.key,
    required this.child,
    required this.index,
    required this.windStream,
  });

  @override
  State<WindSwayCard> createState() => _WindSwayCardState();
}

class _WindSwayCardState extends State<WindSwayCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _angle;
  StreamSubscription<void>? _sub;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );

    _angle = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 0.10)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.10, end: -0.055)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween(begin: -0.055, end: 0.038)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 18,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.038, end: -0.018)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: Tween(begin: -0.018, end: 0.007)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 12,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.007, end: 0.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 20,
      ),
    ]).animate(_controller);

    _sub = widget.windStream.listen((_) {
      // Stagger each card by 120ms * index so they ripple left to right
      Future.delayed(Duration(milliseconds: widget.index * 120), () {
        if (mounted) _controller.forward(from: 0);
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _angle,
      builder: (context, child) => Transform(
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.001)
          ..rotateZ(_angle.value),
        alignment: Alignment.topCenter,
        child: child,
      ),
      child: widget.child,
    );
  }
}

// Wind controller — put this somewhere accessible, e.g. pass down or use provider
class WindController {
  final StreamController<void> _controller = StreamController<void>.broadcast();
  Timer? _timer;
  AnimationController? leavesController;

  Stream<void> get stream => _controller.stream;

  void start() {
    _triggerWind(); // immediate on start
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _triggerWind());
  }

  void _triggerWind() {
    _controller.add(null);
    leavesController?.forward(from: 0);
  }

  void dispose() {
    _timer?.cancel();
    _controller.close();
  }
}

class LeavesPainter extends CustomPainter {
  final double progress;
  LeavesPainter({required this.progress});

  static final _leaves = [
    const _Leaf(startX: -0.05, startY: 0.25, angle: -0.3, size: 8),
    const _Leaf(startX: -0.08, startY: 0.45, angle: 0.2, size: 6),
    const _Leaf(startX: -0.03, startY: 0.65, angle: -0.5, size: 10),
    const _Leaf(startX: -0.06, startY: 0.15, angle: 0.4, size: 7),
    const _Leaf(startX: -0.04, startY: 0.80, angle: -0.1, size: 9),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (final leaf in _leaves) {
      final t = (progress - leaf.startX.abs() * 0.3).clamp(0.0, 1.0);
      if (t <= 0) continue;

      final opacity = t < 0.2
          ? t / 0.2
          : t > 0.75
              ? (1.0 - t) / 0.25
              : 1.0;

      final x = size.width * (leaf.startX + t * 1.15);
      final y = size.height * leaf.startY +
          sin(t * pi * 2.5) * 18 +
          t * size.height * 0.08;

      final paint = Paint()
        ..color = const Color(0xFF4CAF50).withValues(alpha: opacity * 0.75)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(leaf.angle + t * 3.5);

      final path = Path()
        ..moveTo(0, -leaf.size)
        ..cubicTo(
          leaf.size * 0.8,
          -leaf.size * 0.3,
          leaf.size * 0.8,
          leaf.size * 0.3,
          0,
          leaf.size,
        )
        ..cubicTo(
          -leaf.size * 0.8,
          leaf.size * 0.3,
          -leaf.size * 0.8,
          -leaf.size * 0.3,
          0,
          -leaf.size,
        );

      canvas.drawPath(path, paint);

      // Leaf vein
      final veinPaint = Paint()
        ..color = const Color(0xFF2E7D32).withValues(alpha: opacity * 0.5)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(0, -leaf.size), Offset(0, leaf.size), veinPaint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(LeavesPainter old) => old.progress != progress;
}

class _Leaf {
  final double startX, startY, angle, size;
  const _Leaf({
    required this.startX,
    required this.startY,
    required this.angle,
    required this.size,
  });
}
