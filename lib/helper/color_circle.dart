import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ColorCircle extends StatelessWidget {
  final Color color;

  const ColorCircle(this.color, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: Colors.black12),
      ),
    );
  }
}
