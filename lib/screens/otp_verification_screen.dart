import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/local_database_service.dart';
import '../services/prototype_verification_code.dart';
import '../utils/app_theme.dart';
import '../widgets/auth_ui.dart';

class OtpVerificationScreen extends StatefulWidget {
  final PrototypeSignInChallenge challenge;
  const OtpVerificationScreen({super.key, required this.challenge});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen>
    with WidgetsBindingObserver {
  // Academic prototype only. Set --dart-define=SHOW_PROTOTYPE_CODE=false
  // for production builds, which also need server-side code delivery/validation.
  static const _showPrototypeCode =
      bool.fromEnvironment('SHOW_PROTOTYPE_CODE', defaultValue: true);
  final _code = TextEditingController();
  late final PrototypeVerificationCode _verification;
  late int _revision;
  bool _busy = false;
  String? _error;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _verification = widget.challenge.verification;
    _revision = _verification.revision;
    _verification.addListener(_onCodeChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  void _onCodeChanged() {
    if (!mounted || _revision == _verification.revision) return;
    _revision = _verification.revision;
    _code.clear();
    setState(() {
      _error = null;
      _notice = 'Se generó un nuevo código.';
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _verification.refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _verification.removeListener(_onCodeChanged);
    LocalDatabaseService().cancelPrototypeSignIn(widget.challenge);
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_busy) return;
    if (_code.text.length != 4) {
      setState(() => _error = 'Completa los 4 caracteres del código.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await LocalDatabaseService()
          .completePrototypeSignIn(widget.challenge, _code.text);
      TextInput.finishAutofillContext();
      if (mounted) {
        FocusScope.of(context).unfocus();
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = authErrorMessage(error);
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_busy,
        child: AuthCardContainer(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Verificación de código',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700, letterSpacing: -.5)),
              const SizedBox(height: 10),
              const Text('Ingresa el código de 4 caracteres para continuar.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.muted, height: 1.5)),
              const SizedBox(height: 28),
              AutofillGroup(
                  child: OtpCodeInput(
                controller: _code,
                enabled: !_busy,
                hasError: _error != null,
                onChanged: (_) {
                  if (_error != null || _notice != null) {
                    setState(() {
                      _error = null;
                      _notice = null;
                    });
                  }
                },
                onSubmitted: _verify,
              )),
              AuthError(message: _error),
              const SizedBox(height: 20),
              if (_showPrototypeCode)
                PrototypeCodeHint(verification: _verification),
              AnimatedSize(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 180),
                child: _notice == null
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Semantics(
                            liveRegion: true,
                            child: Text(_notice!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 12, color: AppTheme.muted)))),
              ),
              const SizedBox(height: 22),
              AuthPrimaryButton(
                  label: 'Verificar código', busy: _busy, onPressed: _verify),
              const SizedBox(height: 20),
              OtpTimerWidget(
                  verification: _verification,
                  enabled: !_busy,
                  onResend: _verification.renew),
              TextButton(
                onPressed:
                    _busy ? null : () => Navigator.of(context).pop(false),
                child: const Text('Volver al inicio de sesión',
                    textAlign: TextAlign.center),
              ),
            ],
          ),
        ),
      );
}
