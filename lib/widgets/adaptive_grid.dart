import 'package:flutter/material.dart';

/// The viewport determines the mode; the parent determines each tile's width.
class AdaptiveGrid extends StatelessWidget {
  const AdaptiveGrid({
    super.key,
    required this.children,
    this.desktopColumns = 3,
  });
  final List<Widget> children;
  final int desktopColumns;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final viewport = MediaQuery.sizeOf(context).width;
      final columns = viewport < 600
          ? 1
          : viewport < 1100
          ? 2
          : desktopColumns;
      final width = (constraints.maxWidth - 16 * (columns - 1)) / columns;
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}
