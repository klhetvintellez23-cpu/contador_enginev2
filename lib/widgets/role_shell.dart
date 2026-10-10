import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import 'app_ui.dart';
import 'glass_surface.dart';

class RoleShell extends StatelessWidget {
  final int index;
  final List<String> labels;
  final List<IconData> icons;
  final ValueChanged<int> onSelected;
  final Widget child;
  const RoleShell(
      {super.key,
      required this.index,
      required this.labels,
      required this.icons,
      required this.onSelected,
      required this.child});

  @override
  Widget build(BuildContext context) => Scaffold(
      extendBody: true,
      body: SafeArea(
          bottom: false, child: PageFrame(maxWidth: 1080, child: child)),
      bottomNavigationBar: SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          child: Align(
              heightFactor: 1,
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: GlassSurface(
                      radius: 42,
                      child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: LayoutBuilder(builder: (context, constraints) {
                            final cell = constraints.maxWidth / labels.length;
                            final visualIndex =
                                Directionality.of(context) == TextDirection.rtl
                                    ? labels.length - 1 - index
                                    : index;
                            return Stack(children: [
                              AnimatedPositioned(
                                  duration: AppMotion.duration(context, 280),
                                  curve: Curves.easeOutCubic,
                                  top: 0,
                                  height: 68,
                                  width: cell - 4,
                                  left: visualIndex * cell + 2,
                                  child: IgnorePointer(
                                      child: DecoratedBox(
                                          decoration: BoxDecoration(
                                              color: AppTheme.accent
                                                  .withValues(alpha: .2),
                                              borderRadius:
                                                  BorderRadius.circular(34),
                                              boxShadow: [
                                        BoxShadow(
                                            color: AppTheme.accent
                                                .withValues(alpha: .1),
                                            blurRadius: 12,
                                            offset: const Offset(0, 3))
                                      ])))),
                              NavigationBar(
                                  backgroundColor: Colors.transparent,
                                  surfaceTintColor: Colors.transparent,
                                  indicatorColor: Colors.transparent,
                                  elevation: 0,
                                  height: 68,
                                  selectedIndex: index,
                                  animationDuration:
                                      AppMotion.duration(context, 280),
                                  onDestinationSelected: onSelected,
                                  destinations: [
                                    for (var i = 0; i < labels.length; i++)
                                      NavigationDestination(
                                          icon: Icon(icons[i]),
                                          label: labels[i])
                                  ])
                            ]);
                          })))))));
}
