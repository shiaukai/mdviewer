import 'package:flutter/material.dart';

/// Desktop toolbar button: one size, one icon size, rounded-square hover,
/// and a tinted background when a toggle is on.
class ToolbarButton extends StatelessWidget {
  const ToolbarButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.selected = false,
  });

  static const double extent = 32;
  static const double iconSize = 18;

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      isSelected: selected,
      icon: Icon(icon),
      style: ButtonStyle(
        fixedSize: const WidgetStatePropertyAll(Size.square(extent)),
        minimumSize: const WidgetStatePropertyAll(Size.square(extent)),
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        iconSize: const WidgetStatePropertyAll(iconSize),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.standard,
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return scheme.onSurface.withValues(alpha: 0.38);
          if (states.contains(WidgetState.selected)) return scheme.primary;
          return scheme.onSurfaceVariant;
        }),
        backgroundColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? scheme.primary.withValues(alpha: 0.12) : Colors.transparent),
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) return scheme.onSurface.withValues(alpha: 0.12);
          if (states.contains(WidgetState.hovered)) return scheme.onSurface.withValues(alpha: 0.07);
          if (states.contains(WidgetState.focused)) return scheme.onSurface.withValues(alpha: 0.10);
          return null;
        }),
      ),
    );
  }
}

/// Thin vertical rule between toolbar groups.
class ToolbarDivider extends StatelessWidget {
  const ToolbarDivider({super.key});

  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 18,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        color: Theme.of(context).colorScheme.outlineVariant,
      );
}
