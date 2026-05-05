import 'package:flutter/material.dart';

class ServerBubble extends StatelessWidget {
  final IconData? icon;
  final String? text;
  final bool selected;
  final VoidCallback? onTap;

  const ServerBubble({
    super.key,
    this.icon,
    this.text,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF5865F2) : const Color(0xFF36393F),
          borderRadius: BorderRadius.circular(selected ? 16 : 26),
        ),
        child: Center(
          child: icon != null
              ? Icon(icon, color: Colors.white)
              : Text(
                  text ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
        ),
      ),
    );
  }
}