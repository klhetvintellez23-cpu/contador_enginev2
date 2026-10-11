import 'package:flutter/material.dart';

/// One continuous entrance per app launch. The real navigator stays mounted
/// underneath, including its form state and any restored session.
class WelcomeEntrance extends StatefulWidget {
  final Widget child;

  const WelcomeEntrance({super.key, required this.child});

  @override
  State<WelcomeEntrance> createState() => _WelcomeEntranceState();
}

class _WelcomeEntranceState extends State<WelcomeEntrance>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 3400);
  static const _logo = ResizeImage(
    AssetImage('assets/icons/contador_engine_icon_source.png'),
    width: 480,
  );

  late final AnimationController _timeline = AnimationController(
    vsync: this,
    duration: _duration,
  )..addStatusListener(_onStatus);

  Animation<double> _phase(int begin, int end, Curve curve) =>
      _timeline.drive(CurveTween(
        curve: Interval(begin / 3400, end / 3400, curve: curve),
      ));

  late final _logoFade = _phase(0, 950, Curves.easeOutCubic);
  late final _logoScale = _logoFade.drive(Tween(begin: .90, end: 1.0));
  late final _logoExit = _phase(1650, 2350, Curves.easeInOutCubic);
  late final _logoExitFade = _logoExit.drive(Tween(begin: 1.0, end: 0.0));
  late final _logoExitScale = _logoExit.drive(Tween(begin: 1.0, end: .96));
  late final _curtain = _phase(1550, 3200, Curves.easeInOutCubic).drive(
    Tween(begin: Offset.zero, end: const Offset(0, -1)),
  );
  // A fully transparent RenderOpacity skips painting. Keep the real login at
  // 1% behind the opaque curtain so its glyphs and layers warm up before reveal.
  late final _loginFade = _phase(1750, 2900, Curves.easeOutCubic)
      .drive(Tween(begin: .01, end: 1.0));
  late final _loginRise = _phase(1750, 3200, Curves.easeOutCubic);

  bool _preparing = false;
  bool _finished = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      // Apply this immediately, also when the system setting changes mid-intro.
      _finished = true;
      _timeline.value = 1;
    } else if (!_preparing && !_finished) {
      _preparing = true;
      _prepareLogo();
    }
  }

  Future<void> _prepareLogo() async {
    // Decode once before starting the clock; the first logo frame is ready
    // before it fades in. The navigator gets its initial layout underneath.
    await precacheImage(_logo, context);
    if (mounted && !_finished) _timeline.forward();
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && !_finished) {
      setState(() => _finished = true);
    }
  }

  @override
  void dispose() {
    _timeline.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.hardEdge,
        children: [
          // The fading login always blends into its own background, including
          // the first thin strip exposed by the rising purple curtain.
          ColoredBox(color: Theme.of(context).scaffoldBackgroundColor),
          // Keep this exact subtree at completion, so text fields, focus and
          // navigator state never remount as the splash leaves the screen.
          ExcludeSemantics(
            excluding: !_finished,
            child: ExcludeFocus(
              excluding: !_finished,
              child: IgnorePointer(
                ignoring: !_finished,
                child: FadeTransition(
                  opacity: _loginFade,
                  child: AnimatedBuilder(
                    animation: _loginRise,
                    child: RepaintBoundary(child: widget.child),
                    builder: (context, child) => Transform.translate(
                      offset: Offset(0, 20 * (1 - _loginRise.value)),
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (!_finished)
            Positioned.fill(
              child: BlockSemantics(
                child: Semantics(
                  label: 'Contador Engine',
                  image: true,
                  child: ExcludeSemantics(
                    child: Stack(fit: StackFit.expand, children: [
                      SlideTransition(
                        position: _curtain,
                        child: const RepaintBoundary(
                          child: CustomPaint(painter: _PurpleWaves()),
                        ),
                      ),
                      Center(
                        child: LayoutBuilder(builder: (context, constraints) {
                          final logoSize =
                              constraints.maxWidth < 600 ? 132.0 : 160.0;
                          return FadeTransition(
                            opacity: _logoExitFade,
                            child: AnimatedBuilder(
                              animation: _logoExit,
                              builder: (context, child) => Transform.translate(
                                offset: Offset(0, -24 * _logoExit.value),
                                child: child,
                              ),
                              child: ScaleTransition(
                                scale: _logoExitScale,
                                child: FadeTransition(
                                  opacity: _logoFade,
                                  child: ScaleTransition(
                                    scale: _logoScale,
                                    child: RepaintBoundary(
                                      child: Image(
                                        image: _logo,
                                        width: logoSize,
                                        height: logoSize,
                                        filterQuality: FilterQuality.medium,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
        ],
      );
}

/// Broad, still folds with translucent shading. Painted once and translated
/// as a layer: no per-frame path changes, blur filters or background tickers.
class _PurpleWaves extends CustomPainter {
  const _PurpleWaves();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6630A6), Color(0xFF502484), Color(0xFF351658)],
          stops: [0, .52, 1],
        ).createShader(rect),
    );

    final w = size.width;
    final h = size.height;
    final upperFold = Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(w, h * .18)
      ..cubicTo(w * .72, h * .08, w * .72, h * .41, w * .36, h * .35)
      ..cubicTo(w * .12, h * .31, w * .18, h * .60, 0, h * .64)
      ..close();
    canvas.drawPath(
      upperFold,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x0061319F), Color(0x187C45B9), Color(0x147F49BC)],
          stops: [0, .6, 1],
        ).createShader(rect),
    );

    final lowerFold = Path()
      ..moveTo(0, h * .86)
      ..cubicTo(w * .25, h * .66, w * .43, h * .96, w * .70, h * .70)
      ..cubicTo(w * .85, h * .55, w * .88, h * .54, w, h * .52)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
      lowerFold,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomRight,
          colors: [Color(0x00331A57), Color(0x24301950)],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_PurpleWaves oldDelegate) => false;
}
