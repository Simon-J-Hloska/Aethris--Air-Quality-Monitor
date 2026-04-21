import 'package:flutter/material.dart';
import 'dart:async';

class TypewriterText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration durationPerChar;

  const TypewriterText({
    super.key,
    required this.text,
    this.style,
    this.durationPerChar = const Duration(milliseconds: 150),
  });

  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText> {
  String _displayedText = '';
  late Timer _typeTimer;
  Timer? _blinkTimer;
  Timer? _cursorHideTimer;
  int _currentIndex = 0;
  bool _showCursor = true;

  @override
  void initState() {
    super.initState();

    _typeTimer = Timer.periodic(widget.durationPerChar, (timer) {
      if (_currentIndex < widget.text.length) {
        setState(() {
          _currentIndex++;
          _displayedText = widget.text.substring(0, _currentIndex);
        });
      } else {
        timer.cancel();
        _startCursorBlink();
      }
    });
  }

  void _startCursorBlink() {
    _blinkTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted) return;
      setState(() => _showCursor = !_showCursor);
    });

    // Hide cursor permanently after 10 seconds
    _cursorHideTimer = Timer(const Duration(seconds: 10), () {
      _blinkTimer?.cancel();
      if (mounted) setState(() => _showCursor = false);
    });
  }

  @override
  void dispose() {
    _typeTimer.cancel();
    _blinkTimer?.cancel();
    _cursorHideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _displayedText + (_showCursor ? '|' : ''),
      style: widget.style ?? Theme.of(context).textTheme.headlineMedium,
    );
  }
}
