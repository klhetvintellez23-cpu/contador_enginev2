import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import 'app_ui.dart';

/// One travelling capsule, reflowing icons and delayed labels.
/// See docs/animacion-menu-referencia.md for the observed choreography.
class MorphingNavigation extends StatefulWidget {
  final int index;
  final List<String> labels;
  final List<IconData> icons;
  final List<IconData>? selectedIcons;
  final ValueChanged<int> onSelected;

  const MorphingNavigation(
      {super.key,
      required this.index,
      required this.labels,
      required this.icons,
      this.selectedIcons,
      required this.onSelected})
      : assert(labels.length >= 2),
        assert(labels.length == icons.length),
        assert(selectedIcons == null || selectedIcons.length == labels.length),
        assert(index >= 0 && index < labels.length);

  static const duration = Duration(milliseconds: 560);
  static const indicatorKey = ValueKey('navigation-indicator');
  static Key destinationKey(int index) =>
      ValueKey('navigation-destination-$index');
  @override
  State<MorphingNavigation> createState() => _MorphingNavigationState();
}

class _MorphingNavigationState extends State<MorphingNavigation>
    with SingleTickerProviderStateMixin {
  static const _active = Color(0xFF8D45E8);
  static const _muted = Color(0xFF77717F);
  static const _accent = Color(0xFFB976FF);
  static const _height = 64.0;
  static const _padding = 6.0;
  static const _pillHeight = _height - 2 * _padding;
  late final AnimationController _controller = AnimationController(
      vsync: this, duration: MorphingNavigation.duration, value: 1);
  _NavigationFrame? _from;
  _NavigationFrame? _visible;
  int _distance = 1;
  int? _hovered;
  int? _pressed;
  int? _keyboardFocus;

  @override
  void didUpdateWidget(MorphingNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.labels.length != widget.labels.length) {
      _from = _visible = null;
      _controller.value = 1;
    } else if (oldWidget.index != widget.index) {
      // Snapshot the painted geometry, including an interrupted journey.
      // Fractions preserve continuity when the window changes size.
      _from = _visible;
      _distance = (widget.index - oldWidget.index).abs();
      if (MediaQuery.disableAnimationsOf(context)) {
        _controller.value = 1;
      } else {
        _controller.forward(from: 0);
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) _controller.value = 1;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  _NavigationFrame _interpolate(_NavigationFrame target, double width) {
    final from = _from;
    if (from == null || _controller.isCompleted) return target;
    final t = _controller.value;
    final travel =
        const Interval(.04, .75, curve: Curves.easeOutCubic).transform(t);
    final reflow =
        const Interval(.06, .88, curve: Curves.easeOutCubic).transform(t);
    final naturalWidth = lerpDouble(
        from.pillWidth, target.pillWidth, Curves.easeOutCubic.transform(t))!;
    // The reference contracts early and is already reopening when text enters.
    final contractionPhase =
        Curves.easeOutQuad.transform((t / .85).clamp(0.0, 1.0));
    final contraction = math.pow(math.sin(math.pi * contractionPhase), 2) *
        math.max(0, naturalWidth - _pillHeight / width) *
        (_distance > 1 ? 1.0 : .62);
    final pillWidth = naturalWidth - contraction;
    final center = lerpDouble(from.pillCenter, target.pillCenter, travel)!;
    return _NavigationFrame(
      pillLeft: center - pillWidth / 2,
      pillWidth: pillWidth,
      left: [
        for (var i = 0; i < widget.labels.length; i++)
          lerpDouble(from.left[i], target.left[i], reflow)!
      ],
      widths: [
        for (var i = 0; i < widget.labels.length; i++)
          lerpDouble(from.widths[i], target.widths[i], reflow)!
      ],
      icons: [
        for (var i = 0; i < widget.labels.length; i++)
          lerpDouble(from.icons[i], target.icons[i], reflow)!
      ],
      labels: [
        for (var i = 0; i < widget.labels.length; i++)
          lerpDouble(
              from.labels[i],
              target.labels[i],
              i == widget.index
                  ? const Interval(.46, .80, curve: Curves.easeOutCubic)
                      .transform(t)
                  : const Interval(0, .20, curve: Curves.easeOut).transform(t))!
      ],
    );
  }

  void _select(int i) {
    if (i != widget.index) widget.onSelected(i);
  }

  void _step(int direction) =>
      _select((widget.index + direction).clamp(0, widget.labels.length - 1));

  Widget _destination(int i, _NavigationFrame frame, double width,
      TextStyle style, Rect localPill) {
    final iconOffset = (frame.icons[i] - frame.left[i]) * width;
    return Semantics(
      label: widget.labels[i],
      button: true,
      selected: widget.index == i,
      sortKey: OrdinalSortKey(i.toDouble()),
      onTap: () => _select(i),
      child: Tooltip(
        message: widget.labels[i],
        excludeFromSemantics: true,
        waitDuration: const Duration(milliseconds: 700),
        child: FocusableActionDetector(
          mouseCursor: SystemMouseCursors.click,
          onShowHoverHighlight: (value) => setState(() => _hovered = value
              ? i
              : _hovered == i
                  ? null
                  : _hovered),
          onShowFocusHighlight: (value) => setState(() => _keyboardFocus = value
              ? i
              : _keyboardFocus == i
                  ? null
                  : _keyboardFocus),
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
              _select(i);
              return null;
            })
          },
          child: GestureDetector(
            key: MorphingNavigation.destinationKey(i),
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onTap: () => _select(i),
            onTapDown: (_) => setState(() => _pressed = i),
            onTapUp: (_) => setState(() => _pressed = null),
            onTapCancel: () => setState(() => _pressed = null),
            child: Stack(children: [
              Positioned.fill(
                  child: ClipPath(
                      clipper: _PillClipper(localPill),
                      child: Stack(children: [
                        PositionedDirectional(
                            start: iconOffset + 20,
                            end: 12,
                            top: 0,
                            bottom: 0,
                            child: ClipRect(
                                child: Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: Opacity(
                                  opacity: frame.labels[i],
                                  child: ExcludeSemantics(
                                      child: Text(widget.labels[i],
                                          maxLines: 1,
                                          overflow: TextOverflow.clip,
                                          softWrap: false,
                                          style: style))),
                            )))
                      ]))),
              // Keyboard focus uses an underline, never a second pill or halo.
              if (_keyboardFocus == i)
                PositionedDirectional(
                    start: iconOffset - 7,
                    bottom: 4,
                    child: Container(width: 14, height: 2, color: _active)),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final style = TextStyle(
        fontFamily: 'AppRoboto',
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: MediaQuery.highContrastOf(context)
            ? const Color(0xFF191620)
            : _active);
    final labelWidths = widget.labels.map((label) {
      final painter = TextPainter(
          text: TextSpan(text: label, style: style),
          textScaler: MediaQuery.textScalerOf(context),
          textDirection: Directionality.of(context))
        ..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }).toList();
    final desiredWidth = widget.labels.length * 60.0 +
        labelWidths.reduce(math.max) +
        8 +
        2 * _padding;
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.arrowLeft): _NavigationStep(-1),
        SingleActivator(LogicalKeyboardKey.arrowRight): _NavigationStep(1),
        SingleActivator(LogicalKeyboardKey.home): _NavigationEdge(false),
        SingleActivator(LogicalKeyboardKey.end): _NavigationEdge(true),
      },
      child: Actions(
          actions: {
            _NavigationStep:
                CallbackAction<_NavigationStep>(onInvoke: (intent) {
              _step(intent.direction * (rtl ? -1 : 1));
              return null;
            }),
            _NavigationEdge:
                CallbackAction<_NavigationEdge>(onInvoke: (intent) {
              _select(intent.last ? widget.labels.length - 1 : 0);
              return null;
            }),
          },
          child: FocusTraversalGroup(
              child: SizedBox(
            width: desiredWidth,
            height: _height,
            child: LayoutBuilder(builder: (context, constraints) {
              final width = constraints.maxWidth;
              final innerWidth = width - 2 * _padding;
              final labelWidth = math.min(labelWidths[widget.index],
                  math.max(0.0, innerWidth - widget.labels.length * 48 - 8));
              final extra = labelWidth + 8;
              final base = (innerWidth - extra) / widget.labels.length;
              var x = _padding;
              final left = <double>[];
              final widths = <double>[];
              final icons = <double>[];
              for (var i = 0; i < widget.labels.length; i++) {
                final cellWidth = base + (i == widget.index ? extra : 0);
                left.add(x / width);
                widths.add(cellWidth / width);
                icons.add((x + base / 2) / width);
                x += cellWidth;
              }
              final target = _NavigationFrame(
                  pillLeft: left[widget.index],
                  pillWidth: widths[widget.index],
                  left: left,
                  widths: widths,
                  icons: icons,
                  labels: [
                    for (var i = 0; i < widget.labels.length; i++)
                      i == widget.index ? 1 : 0
                  ]);
              return AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    final frame = _visible = _interpolate(target, width);
                    double physicalLeft(double start, double size) =>
                        (rtl ? 1 - start - size : start) * width;
                    final pill = Rect.fromLTWH(
                        physicalLeft(frame.pillLeft, frame.pillWidth),
                        _padding,
                        frame.pillWidth * width,
                        _pillHeight);
                    Widget iconLayer({required bool filled}) =>
                        Stack(children: [
                          for (var i = 0; i < widget.labels.length; i++)
                            Positioned(
                                left: (rtl
                                            ? 1 - frame.icons[i]
                                            : frame.icons[i]) *
                                        width -
                                    12,
                                top: (_height - 24) / 2,
                                width: 24,
                                height: 24,
                                child: AnimatedScale(
                                    scale: _pressed == i ? .90 : 1,
                                    duration: AppMotion.duration(context, 120),
                                    curve: Curves.easeOutCubic,
                                    child: TweenAnimationBuilder<Color?>(
                                      duration:
                                          AppMotion.duration(context, 180),
                                      tween: ColorTween(
                                          end: filled
                                              ? _active
                                              : _hovered == i
                                                  ? _accent
                                                  : _muted),
                                      builder: (context, color, child) => Icon(
                                          filled
                                              ? (widget.selectedIcons ??
                                                  widget.icons)[i]
                                              : widget.icons[i],
                                          size: 24,
                                          color: color),
                                    ))),
                        ]);
                    return DecoratedBox(
                      decoration: BoxDecoration(
                          color: const Color(0xFFFAFAFC),
                          borderRadius: BorderRadius.circular(_height / 2),
                          border: Border.all(color: const Color(0xFFEDEAF1)),
                          boxShadow: const [
                            BoxShadow(
                                color: Color(0x0A191620),
                                blurRadius: 16,
                                offset: Offset(0, 5))
                          ]),
                      child: Stack(children: [
                        Positioned.fromRect(
                            rect: pill,
                            child: IgnorePointer(
                                child: DecoratedBox(
                                    key: MorphingNavigation.indicatorKey,
                                    decoration: BoxDecoration(
                                        color: const Color(0xFFF1E4FF),
                                        borderRadius: BorderRadius.circular(
                                            _pillHeight / 2))))),
                        Positioned.fill(
                            child: IgnorePointer(
                                child: ExcludeSemantics(
                                    child: ClipPath(
                                        clipper:
                                            _PillClipper(pill, inverse: true),
                                        child: iconLayer(filled: false))))),
                        // A shared mask reveals filled icons as the single pill crosses.
                        Positioned.fill(
                            child: IgnorePointer(
                                child: ExcludeSemantics(
                                    child: ClipPath(
                                        clipper: _PillClipper(pill),
                                        child: iconLayer(filled: true))))),
                        for (var i = 0; i < widget.labels.length; i++)
                          Positioned(
                              left:
                                  physicalLeft(frame.left[i], frame.widths[i]),
                              top: _padding,
                              width: frame.widths[i] * width,
                              height: _pillHeight,
                              child: _destination(
                                  i,
                                  frame,
                                  width,
                                  style,
                                  pill.shift(Offset(
                                      -physicalLeft(
                                          frame.left[i], frame.widths[i]),
                                      -_padding)))),
                      ]),
                    );
                  });
            }),
          ))),
    );
  }
}

class _NavigationFrame {
  final double pillLeft;
  final double pillWidth;
  final List<double> left;
  final List<double> widths;
  final List<double> icons;
  final List<double> labels;
  double get pillCenter => pillLeft + pillWidth / 2;
  const _NavigationFrame(
      {required this.pillLeft,
      required this.pillWidth,
      required this.left,
      required this.widths,
      required this.icons,
      required this.labels});
}

class _PillClipper extends CustomClipper<Path> {
  final Rect rect;
  final bool inverse;
  const _PillClipper(this.rect, {this.inverse = false});
  @override
  Path getClip(Size size) {
    final path = Path()..fillType = PathFillType.evenOdd;
    if (inverse) path.addRect(Offset.zero & size);
    return path
      ..addRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(rect.height / 2)));
  }

  @override
  bool shouldReclip(_PillClipper oldClipper) =>
      oldClipper.rect != rect || oldClipper.inverse != inverse;
}

class _NavigationStep extends Intent {
  final int direction;
  const _NavigationStep(this.direction);
}

class _NavigationEdge extends Intent {
  final bool last;
  const _NavigationEdge(this.last);
}
