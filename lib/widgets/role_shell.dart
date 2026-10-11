import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import 'app_ui.dart';
import 'morphing_navigation.dart';

class RoleShell extends StatelessWidget {
  final int index;
  final List<String> labels;
  final List<IconData> icons;
  final List<IconData>? selectedIcons;
  final ValueChanged<int> onSelected;
  final Widget child;
  const RoleShell(
      {super.key,
      required this.index,
      required this.labels,
      required this.icons,
      this.selectedIcons,
      required this.onSelected,
      required this.child});

  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: AppTheme.background,
      extendBody: false,
      body: SafeArea(
          bottom: false, child: PageFrame(maxWidth: 1080, child: child)),
      bottomNavigationBar: SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          child: Align(
              heightFactor: 1,
              child: MorphingNavigation(
                  index: index,
                  labels: labels,
                  icons: icons,
                  selectedIcons: selectedIcons,
                  onSelected: onSelected))));
}
