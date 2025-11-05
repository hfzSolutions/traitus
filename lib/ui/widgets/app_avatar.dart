import 'package:flutter/material.dart';

class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    required this.size,
    required this.name,
    this.imageUrl,
    this.isCircle = true,
  });

  final double size;
  final String name;
  final String? imageUrl;
  final bool isCircle;

  String get _initial {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final rune = trimmed.characters.first;
    return rune.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderRadius = BorderRadius.circular(isCircle ? size : size * 0.25);

    // Deterministic, high-contrast gradients for better initial readability (26 entries for A–Z)
    final palette = <List<Color>>[
      // A–Z
      [const Color(0xFF4F46E5), const Color(0xFF06B6D4)], // A: Indigo → Cyan
      [const Color(0xFF7C3AED), const Color(0xFFEC4899)], // B: Violet → Pink
      [const Color(0xFF0EA5E9), const Color(0xFF22C55E)], // C: Sky → Green
      [const Color(0xFFF59E0B), const Color(0xFFEF4444)], // D: Amber → Red
      [const Color(0xFF3B82F6), const Color(0xFF9333EA)], // E: Blue → Purple
      [const Color(0xFF10B981), const Color(0xFF3B82F6)], // F: Emerald → Blue
      [const Color(0xFF14B8A6), const Color(0xFF6366F1)], // G: Teal → Indigo
      [const Color(0xFFF43F5E), const Color(0xFFF59E0B)], // H: Rose → Amber
      [const Color(0xFF22C55E), const Color(0xFF16A34A)], // I: Green → Green Dark
      [const Color(0xFF06B6D4), const Color(0xFF0891B2)], // J: Cyan → Cyan Dark
      [const Color(0xFF8B5CF6), const Color(0xFF4C1D95)], // K: Violet → Deep Violet
      [const Color(0xFFEF4444), const Color(0xFFB91C1C)], // L: Red → Deep Red
      [const Color(0xFFF97316), const Color(0xFFEA580C)], // M: Orange → Deep Orange
      [const Color(0xFF84CC16), const Color(0xFF16A34A)], // N: Lime → Green
      [const Color(0xFF60A5FA), const Color(0xFF2563EB)], // O: Light Blue → Blue
      [const Color(0xFFF472B6), const Color(0xFFDB2777)], // P: Pink → Deep Pink
      [const Color(0xFF34D399), const Color(0xFF059669)], // Q: Mint → Emerald Dark
      [const Color(0xFF38BDF8), const Color(0xFF0284C7)], // R: Sky → Blue Dark
      [const Color(0xFFA78BFA), const Color(0xFF7C3AED)], // S: Lavender → Violet
      [const Color(0xFFEAB308), const Color(0xFFCA8A04)], // T: Yellow → Golden
      [const Color(0xFFFB7185), const Color(0xFFF43F5E)], // U: Soft Red → Rose
      [const Color(0xFF22D3EE), const Color(0xFF06B6D4)], // V: Light Cyan → Cyan
      [const Color(0xFF93C5FD), const Color(0xFF3B82F6)], // W: Soft Blue → Blue
      [const Color(0xFFFDA4AF), const Color(0xFFEC4899)], // X: Soft Pink → Pink
      [const Color(0xFF86EFAC), const Color(0xFF22C55E)], // Y: Soft Green → Green
      [const Color(0xFFC4B5FD), const Color(0xFF8B5CF6)], // Z: Soft Violet → Violet
    ];
    final upper = _initial.isNotEmpty ? _initial[0] : 'A';
    final code = upper.codeUnitAt(0);
    final index = (code >= 65 && code <= 90)
        ? (code - 65)
        : 0;
    final gradientColors = palette[index];
    final gradient = LinearGradient(
      colors: gradientColors,
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    Widget content;
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      content = ClipRRect(
        borderRadius: borderRadius,
        child: Image.network(
          imageUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          cacheWidth: (size * 2).toInt(),
          cacheHeight: (size * 2).toInt(),
          errorBuilder: (context, error, stackTrace) {
            return _buildInitial(theme, gradient, borderRadius);
          },
        ),
      );
    } else {
      content = _buildInitial(theme, gradient, borderRadius);
    }

    return SizedBox(
      width: size,
      height: size,
      child: content,
    );
  }

  Widget _buildInitial(ThemeData theme, Gradient gradient, BorderRadius borderRadius) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: borderRadius,
      ),
      child: Center(
        child: Text(
          _initial,
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.46,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            shadows: const [
              Shadow(offset: Offset(0, 1), blurRadius: 2, color: Colors.black26),
            ],
          ),
        ),
      ),
    );
  }
}


