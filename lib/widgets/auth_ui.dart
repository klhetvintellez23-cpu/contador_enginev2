import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/app_theme.dart';
import '../services/prototype_verification_code.dart';
import 'app_ui.dart';

String authErrorMessage(Object error) {
  if (error is ArgumentError) return error.message.toString();
  if (error is StateError) return error.message;
  return 'No se pudo completar el acceso. Inténtalo de nuevo.';
}

/// Shared, scrollable composition for access and verification, including IME
/// insets and short desktop windows.
class AuthCardContainer extends StatelessWidget {
  final Widget child;
  const AuthCardContainer({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppTheme.background,
        body: SafeArea(
          child: LayoutBuilder(builder: (context, constraints) {
            final horizontal = constraints.maxWidth < 380 ? 16.0 : 24.0;
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding:
                  EdgeInsets.symmetric(horizontal: horizontal, vertical: 28),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                    minHeight: math.max(0, constraints.maxHeight - 56)),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.asset(
                              'assets/icons/contador_engine_icon_source.png',
                              width: 72,
                              height: 72,
                              cacheWidth: 144,
                              semanticLabel: 'Logo de Contador Engine',
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text('Contador Engine',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        const Text('Tu negocio, tus clientes y tus préstamos.',
                            textAlign: TextAlign.center,
                            style:
                                TextStyle(color: AppTheme.muted, height: 1.5)),
                        const SizedBox(height: 28),
                        Card(
                          child: Padding(
                            padding: EdgeInsets.all(
                                constraints.maxWidth < 380 ? 20 : 28),
                            child: child,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Simulación académica · Datos guardados en este equipo',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 12, color: AppTheme.muted, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      );
}

class AuthPrimaryButton extends StatefulWidget {
  final String label;
  final bool busy;
  final VoidCallback? onPressed;
  const AuthPrimaryButton(
      {super.key,
      required this.label,
      required this.onPressed,
      this.busy = false});

  @override
  State<AuthPrimaryButton> createState() => _AuthPrimaryButtonState();
}

class _AuthPrimaryButtonState extends State<AuthPrimaryButton> {
  final _states = WidgetStatesController();
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _states.addListener(_updatePress);
  }

  void _updatePress() {
    // ButtonStyleButton can update its states while rebuilding (e.g. busy).
    // Defer the scale update so its parent is never dirtied during that build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pressed = _states.value.contains(WidgetState.pressed);
      if (mounted && _pressed != pressed) setState(() => _pressed = pressed);
    });
  }

  @override
  void dispose() {
    _states.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedScale(
        scale: _pressed ? .985 : 1,
        duration: AppMotion.duration(context, 120),
        curve: Curves.easeOutCubic,
        child: FilledButton(
          statesController: _states,
          onPressed: widget.busy ? null : widget.onPressed,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          child: AnimatedSwitcher(
            duration: AppMotion.duration(context, 160),
            child: widget.busy
                ? SizedBox(
                    key: const ValueKey('busy'),
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primary,
                        semanticsLabel: 'Procesando'))
                : Text(widget.label,
                    key: ValueKey(widget.label), textAlign: TextAlign.center),
          ),
        ),
      );
}

/// Four visual cells backed by one editing buffer: paste, autofill, selection
/// and backspace behave identically on native mobile keyboards and Windows.
class OtpCodeInput extends StatefulWidget {
  final TextEditingController controller;
  final bool enabled;
  final bool hasError;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmitted;
  const OtpCodeInput(
      {super.key,
      required this.controller,
      required this.onChanged,
      required this.onSubmitted,
      this.enabled = true,
      this.hasError = false});

  @override
  State<OtpCodeInput> createState() => _OtpCodeInputState();
}

class _OtpCodeInputState extends State<OtpCodeInput> {
  final _focus = FocusNode(debugLabel: 'Código de verificación');

  @override
  void initState() {
    super.initState();
    _focus.addListener(_refresh);
    widget.controller.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant OtpCodeInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_refresh);
      widget.controller.addListener(_refresh);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    _focus.dispose();
    super.dispose();
  }

  void _select(int index) {
    if (!widget.enabled) return;
    _focus.requestFocus();
    final length = widget.controller.text.length;
    widget.controller.selection = index < length
        ? TextSelection(baseOffset: index, extentOffset: index + 1)
        : TextSelection.collapsed(offset: length);
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.controller.value;
    final active =
        (value.selection.isValid ? value.selection.start : value.text.length)
            .clamp(0, 3);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 304),
        child: LayoutBuilder(builder: (context, constraints) {
          final width = (constraints.maxWidth - 36) / 4;
          final height =
              math.max(68.0, MediaQuery.textScalerOf(context).scale(32) + 26);
          return SizedBox(
            height: height,
            child: Stack(children: [
              Positioned.fill(
                child: Opacity(
                  opacity: 0,
                  alwaysIncludeSemantics: true,
                  child: Semantics(
                    label: 'Código de verificación, 4 letras o números',
                    child: EditableText(
                      key: const ValueKey('otp-input'),
                      controller: widget.controller,
                      focusNode: _focus,
                      autofocus: true,
                      readOnly: !widget.enabled,
                      style: const TextStyle(fontSize: 28, color: AppTheme.ink),
                      cursorColor: AppTheme.primary,
                      backgroundCursorColor: Colors.transparent,
                      showCursor: false,
                      keyboardType: TextInputType.text,
                      textCapitalization: TextCapitalization.characters,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      autocorrect: false,
                      enableSuggestions: false,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp('[a-zA-Z0-9]')),
                        const _UpperCaseCodeFormatter(),
                        LengthLimitingTextInputFormatter(4),
                      ],
                      onChanged: widget.onChanged,
                      onSubmitted: (_) => widget.onSubmitted(),
                    ),
                  ),
                ),
              ),
              ExcludeSemantics(
                child: Row(children: [
                  for (var i = 0; i < 4; i++) ...[
                    if (i > 0) const SizedBox(width: 12),
                    MouseRegion(
                      cursor: widget.enabled
                          ? SystemMouseCursors.text
                          : SystemMouseCursors.basic,
                      child: GestureDetector(
                        onTap: () => _select(i),
                        child: AnimatedContainer(
                          key: ValueKey('otp-box-$i'),
                          duration: AppMotion.duration(context, 180),
                          curve: Curves.easeOutCubic,
                          width: width,
                          height: height,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              width: _focus.hasFocus && active == i ? 1.6 : 1,
                              color: widget.hasError
                                  ? Theme.of(context).colorScheme.error
                                  : _focus.hasFocus && active == i
                                      ? AppTheme.primary.withValues(alpha: .7)
                                      : AppTheme.border,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _focus.hasFocus && active == i
                                    ? AppTheme.primary.withValues(alpha: .10)
                                    : Colors.black.withValues(alpha: .025),
                                blurRadius:
                                    _focus.hasFocus && active == i ? 14 : 6,
                                offset: const Offset(0, 3),
                              )
                            ],
                          ),
                          child: Text(
                              i < value.text.length ? value.text[i] : '',
                              style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.ink,
                                  fontFeatures: [
                                    FontFeature.tabularFigures()
                                  ])),
                        ),
                      ),
                    ),
                  ],
                ]),
              ),
            ]),
          );
        }),
      ),
    );
  }
}

class _UpperCaseCodeFormatter extends TextInputFormatter {
  const _UpperCaseCodeFormatter();
  @override
  TextEditingValue formatEditUpdate(
          TextEditingValue oldValue, TextEditingValue newValue) =>
      newValue.copyWith(
          text: newValue.text.toUpperCase(), composing: TextRange.empty);
}

/// A view of the challenge clock; it never owns or restarts a timer.
class OtpTimerWidget extends StatelessWidget {
  final PrototypeVerificationCode verification;
  final VoidCallback onResend;
  final bool enabled;
  const OtpTimerWidget(
      {super.key,
      required this.verification,
      required this.onResend,
      this.enabled = true});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: verification,
      builder: (context, child) {
        final remaining = verification.remainingSeconds;
        final minutes = (remaining ~/ 60).toString().padLeft(2, '0');
        final seconds = (remaining % 60).toString().padLeft(2, '0');
        return Column(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
                color: AppTheme.neutral,
                borderRadius: BorderRadius.circular(20)),
            child: Row(children: [
              SizedBox(
                  width: 28,
                  height: 28,
                  child: Stack(alignment: Alignment.center, children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 1, end: remaining / 60),
                      duration: AppMotion.duration(context, 850),
                      curve: Curves.linear,
                      builder: (context, value, child) =>
                          CircularProgressIndicator(
                        value: value,
                        strokeWidth: 2,
                        strokeCap: StrokeCap.round,
                        color: AppTheme.primary,
                        backgroundColor: AppTheme.border,
                      ),
                    ),
                    Icon(
                        remaining > 0
                            ? Icons.schedule_rounded
                            : Icons.check_rounded,
                        size: 15,
                        color: AppTheme.primary),
                  ])),
              const SizedBox(width: 12),
              const Expanded(
                  child: Text('Nuevo código en',
                      style: TextStyle(fontSize: 13, color: AppTheme.muted))),
              const SizedBox(width: 8),
              Semantics(
                label: 'El código se renueva en $minutes:$seconds',
                child: ExcludeSemantics(
                    child: AnimatedSwitcher(
                  duration: AppMotion.duration(context, 180),
                  transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                          position: Tween(
                                  begin: const Offset(0, .12), end: Offset.zero)
                              .animate(animation),
                          child: child)),
                  child: Text('$minutes:$seconds',
                      key: ValueKey(remaining),
                      style: const TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w700,
                          fontFeatures: [FontFeature.tabularFigures()])),
                )),
              ),
            ]),
          ),
          const SizedBox(height: 4),
          TextButton.icon(
            key: const ValueKey('resend-code'),
            onPressed: enabled && verification.canResend ? onResend : null,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Reenviar código'),
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 48),
              animationDuration: AppMotion.duration(context, 220),
            ),
          ),
        ]);
      });
}

class PrototypeCodeHint extends StatelessWidget {
  final PrototypeVerificationCode verification;
  const PrototypeCodeHint({super.key, required this.verification});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: verification,
        builder: (context, child) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
              color: AppTheme.neutral, borderRadius: BorderRadius.circular(16)),
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 4,
            children: [
              const Text('Código de prueba actual:',
                  style: TextStyle(fontSize: 12, color: AppTheme.muted)),
              Semantics(
                liveRegion: true,
                label: 'Código de prueba actual: ${verification.code}',
                child: ExcludeSemantics(
                    child: AnimatedSwitcher(
                  duration: AppMotion.duration(context, 220),
                  child: Text(verification.code,
                      key: ValueKey(verification.revision),
                      style: const TextStyle(
                          color: AppTheme.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.6,
                          fontFeatures: [FontFeature.tabularFigures()])),
                )),
              ),
            ],
          ),
        ),
      );
}

class AuthError extends StatelessWidget {
  final String? message;
  const AuthError({super.key, this.message});

  @override
  Widget build(BuildContext context) => AnimatedSize(
        duration: AppMotion.duration(context, 180),
        alignment: Alignment.topCenter,
        child: message == null
            ? const SizedBox(width: double.infinity)
            : Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Semantics(
                    liveRegion: true,
                    child: Text(message!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            height: 1.4)))),
      );
}
