import 'package:flutter/material.dart';

class PracticeButton extends StatelessWidget {
  const PracticeButton({
    super.key,
    required this.buttonKey,
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  final Key buttonKey;
  final VoidCallback? onPressed;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Align(
    child: SizedBox(
      width: 240,
      height: 56,
      child: FilledButton.icon(
        key: buttonKey,
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 56),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          shape: const StadiumBorder(),
        ),
        icon: Icon(icon, size: 20),
        label: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    ),
  );
}
