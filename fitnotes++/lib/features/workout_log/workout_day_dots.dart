import 'package:flutter/material.dart';

class WorkoutDayDots extends StatelessWidget {
  const WorkoutDayDots({super.key, required this.colors});
  final List<int> colors;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 6,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final color in colors.take(4))
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(color: Color(color), shape: BoxShape.circle),
            ),
          ),
      ],
    ),
  );
}
