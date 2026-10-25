import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme.dart';

final _nf = NumberFormat.decimalPattern('en_IN');
String fmt(num n) => _nf.format(n.round());
String one(num n) {
  final v = (n * 10).round() / 10;
  return v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
}

/// Rounded surface used for every card in the app.
class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final bool outlined;
  final double radius;
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color = FF.surface,
    this.outlined = false,
    this.radius = 22,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(radius),
          border: outlined ? Border.all(color: FF.line) : null,
        ),
        child: child,
      );
}

class Muted extends StatelessWidget {
  final String text;
  final double size;
  const Muted(this.text, {super.key, this.size = 13});
  @override
  Widget build(BuildContext context) => Text(text, style: TextStyle(color: FF.muted, fontSize: size));
}

class ProgressBar extends StatelessWidget {
  final double value; // 0..1
  final Color color;
  final double height;
  const ProgressBar({super.key, required this.value, required this.color, this.height = 7});
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: LinearProgressIndicator(
          value: value.clamp(0.0, 1.0),
          minHeight: height,
          backgroundColor: FF.line,
          valueColor: AlwaysStoppedAnimation(color),
        ),
      );
}

class MacroCard extends StatelessWidget {
  final String label;
  final double value;
  final int goal;
  final Color color;
  const MacroCard({super.key, required this.label, required this.value, required this.goal, required this.color});

  @override
  Widget build(BuildContext context) => Panel(
        radius: 18,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Muted(label, size: 12),
            const SizedBox(height: 6),
            Text.rich(TextSpan(children: [
              TextSpan(text: fmt(value), style: const TextStyle(fontWeight: FontWeight.w600)),
              TextSpan(text: '/${goal}g', style: const TextStyle(color: FF.muted)),
            ])),
            const SizedBox(height: 8),
            ProgressBar(value: goal == 0 ? 0 : value / goal, color: color),
          ],
        ),
      );
}

/// Big calorie ring on the home screen.
class CalorieRing extends StatelessWidget {
  final double eaten, burned;
  final int goal;
  final double size;
  const CalorieRing({super.key, required this.eaten, required this.burned, required this.goal, this.size = 150});

  @override
  Widget build(BuildContext context) {
    final budget = goal + burned;
    final left = budget - eaten;
    final over = left < 0;
    final pct = budget <= 0 ? 0.0 : (eaten / budget).clamp(0.0, 1.0);
    return Semantics(
      label: over ? '${fmt(-left)} calories over' : '${fmt(left)} calories left',
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RingPainter(pct, over ? FF.burn : FF.accent),
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(fmt(left.abs()), style: FF.display(32)),
              Muted(over ? 'kcal over' : 'kcal left', size: 12),
            ]),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double pct;
  final Color color;
  _RingPainter(this.pct, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 14.0;
    final rect = Offset.zero & size;
    final r = rect.deflate(stroke / 2);
    final bg = Paint()
      ..color = FF.line
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    final fg = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(r, 0, 2 * pi, false, bg);
    if (pct > 0) canvas.drawArc(r, -pi / 2, 2 * pi * pct, false, fg);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.pct != pct || old.color != color;
}

void toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
}
