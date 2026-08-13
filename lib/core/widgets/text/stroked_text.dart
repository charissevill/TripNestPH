import 'package:flutter/material.dart';

/// Text with a solid outline behind its fill — for a short label placed
/// directly over a busy photo/illustration background, where even a plain
/// white fill can lose definition against a light or cluttered patch.
/// Layers two [Text] widgets: a stroke-only "outline" copy behind a
/// normally-filled copy in front, the standard Flutter technique for
/// outlined text (a single [TextStyle.foreground] stroke paint would
/// otherwise leave the text hollow).
class StrokedText extends StatelessWidget {
  const StrokedText(
    this.text, {
    super.key,
    required this.style,
    this.strokeColor = Colors.black,
    this.strokeWidth = 3,
    this.textAlign,
  });

  final String text;
  final TextStyle style;
  final Color strokeColor;
  final double strokeWidth;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Text(
          text,
          textAlign: textAlign,
          style: style.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeWidth
              ..color = strokeColor,
          ),
        ),
        Text(text, textAlign: textAlign, style: style),
      ],
    );
  }
}
