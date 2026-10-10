import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

abstract final class AppMotion {
  static Duration duration(BuildContext context, [int milliseconds = 220]) =>
      MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : Duration(milliseconds: milliseconds);
}

class AdaptiveGrid extends StatelessWidget {
  final List<Widget> children;
  const AdaptiveGrid({super.key, required this.children});
  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final columns = constraints.maxWidth >= 600 ? 2 : 1;
        final width = (constraints.maxWidth - 12 * (columns - 1)) / columns;
        return Wrap(spacing: 12, runSpacing: 12, children: [
          for (final child in children) SizedBox(width: width, child: child),
        ]);
      });
}

/// A bounded reading area keeps forms and lists comfortable on desktop.
class PageFrame extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  const PageFrame({super.key, required this.child, this.maxWidth = 1040});

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: SizedBox(width: double.infinity, child: child),
        ),
      );
}

class PageHeading extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool back;
  const PageHeading(
      {super.key,
      required this.title,
      this.subtitle,
      this.trailing,
      this.back = false});

  @override
  Widget build(BuildContext context) => SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
          child: Row(children: [
            if (back) ...[
              const BackButton(),
              const SizedBox(width: 8),
            ],
            Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700, letterSpacing: -.6)),
                if (subtitle != null) ...[
                  const SizedBox(height: 5),
                  Text(subtitle!,
                      style: const TextStyle(color: AppTheme.muted)),
                ],
              ],
            )),
            if (trailing != null) ...[const SizedBox(width: 12), trailing!],
          ]),
        ),
      );
}

class Reveal extends StatelessWidget {
  final Widget child;
  final int delayMilliseconds;
  const Reveal({super.key, required this.child, this.delayMilliseconds = 0})
      : assert(delayMilliseconds >= 0);
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: AppMotion.duration(context, 320 + delayMilliseconds),
        curve: Interval(delayMilliseconds / (320 + delayMilliseconds), 1,
            curve: Curves.easeOutCubic),
        child: child,
        builder: (_, value, child) => Opacity(
            opacity: value,
            child: Transform.translate(
                offset: Offset(0, 10 * (1 - value)), child: child)),
      );
}

class TabContent extends StatefulWidget {
  final int index;
  final List<Widget> children;
  const TabContent({super.key, required this.index, required this.children});
  @override
  State<TabContent> createState() => _TabContentState();
}

class _TabContentState extends State<TabContent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 220), value: 1);
  final Set<int> _visited = {};
  @override
  void didUpdateWidget(TabContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index &&
        !MediaQuery.disableAnimationsOf(context)) {
      _motion.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _visited.add(widget.index);
    return FadeTransition(
      opacity: _motion.drive(Tween(begin: .6, end: 1.0)),
      child: IndexedStack(index: widget.index, children: [
        for (var i = 0; i < widget.children.length; i++)
          TickerMode(
              enabled: widget.index == i,
              child: _visited.contains(i)
                  ? widget.children[i]
                  : const SizedBox.shrink()),
      ]),
    );
  }
}

class TouchSurface extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const TouchSurface({super.key, required this.child, required this.onTap});
  @override
  State<TouchSurface> createState() => _TouchSurfaceState();
}

class _TouchSurfaceState extends State<TouchSurface> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) => AnimatedScale(
        scale: _pressed ? .985 : 1,
        duration: AppMotion.duration(context, 160),
        curve: Curves.easeOutCubic,
        child: Material(
          color: Colors.white,
          elevation: 1.2,
          shadowColor: AppTheme.ink.withValues(alpha: .08),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            onHighlightChanged: (value) => setState(() => _pressed = value),
            child: widget.child,
          ),
        ),
      );
}

class SettingsGroup extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;
  const SettingsGroup(
      {super.key,
      required this.title,
      required this.subtitle,
      required this.children});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Card(
            child: ExpansionTile(
          key: PageStorageKey(title),
          maintainState: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          title:
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(subtitle,
              style: const TextStyle(fontSize: 13, color: AppTheme.muted)),
          shape: const Border(),
          collapsedShape: const Border(),
          children: children,
        )),
      );
}

class CalmPageTransitions extends PageTransitionsBuilder {
  const CalmPageTransitions();
  @override
  Widget buildTransitions<T>(
      PageRoute<T> route,
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final motion = animation.drive(CurveTween(curve: Curves.easeOutCubic));
    return FadeTransition(
        opacity: motion,
        child: SlideTransition(
          position: motion
              .drive(Tween(begin: const Offset(.025, 0), end: Offset.zero)),
          child: child,
        ));
  }
}

/// A single, brief entrance; the app remains interactive during the reveal.
class WelcomeEntrance extends StatelessWidget {
  final Widget child;
  const WelcomeEntrance({super.key, required this.child});
  @override
  Widget build(BuildContext context) => Stack(fit: StackFit.expand, children: [
        Reveal(delayMilliseconds: 400, child: child),
        IgnorePointer(
            child: ExcludeSemantics(
                child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: AppMotion.duration(context, 800),
          builder: (_, value, __) {
            if (value == 1) return const SizedBox.shrink();
            final entry = const Interval(0, .35, curve: Curves.easeOutCubic)
                .transform(value);
            final exit = const Interval(.55, 1, curve: Curves.easeInOutCubic)
                .transform(value);
            final logo = ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.asset(
                    'assets/icons/contador_engine_icon_source.png',
                    width: 96,
                    height: 96,
                    cacheWidth: 192));
            return Opacity(
                opacity: 1 - exit,
                child: ColoredBox(
                    color: AppTheme.background,
                    child: Center(
                        child: Opacity(
                            opacity: entry,
                            child: Transform.translate(
                                offset: Offset(0, 8 * (1 - entry) - 6 * exit),
                                child: Transform.scale(
                                    scale: .92 + .08 * entry, child: logo))))));
          },
        ))),
      ]);
}
