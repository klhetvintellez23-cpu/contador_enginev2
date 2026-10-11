import '../utils/app_theme.dart';
import '../widgets/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/local_fonts.dart';
import '../services/app_lock_service.dart';
import '../services/local_database_service.dart';

/// Envuelve la app (ver main.dart) y exige PIN/huella antes de mostrar el
/// contenido, cada vez que corresponda según AppLockService.isEnabled.
///
/// Ojo con esto: la app abre WhatsApp todo el tiempo (comprobantes
/// automáticos), lo que la manda a segundo plano y la trae de vuelta
/// constantemente. Por eso solo se vuelve a pedir PIN/huella si estuvo en
/// segundo plano más de [_lockGraceDuration] — si no, cada viaje de ida y
/// vuelta a WhatsApp obligaría a desbloquear de nuevo.
class AppLockGate extends StatefulWidget {
  final Widget child;
  const AppLockGate({super.key, required this.child});

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  static const _lockGraceDuration = Duration(seconds: 30);

  bool _checked = false;
  bool _unlocked = false;
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkLock();
  }

  Future<void> _checkLock() async {
    final enabled = await AppLockService().isEnabled;
    if (!mounted) return;
    setState(() {
      _checked = true;
      _unlocked = !enabled;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _pausedAt ??= DateTime.now();
      return;
    }
    if (state == AppLifecycleState.resumed) {
      final pausedAt = _pausedAt;
      _pausedAt = null;
      if (pausedAt == null) return;
      final elapsed = DateTime.now().difference(pausedAt);
      if (elapsed > _lockGraceDuration) {
        AppLockService().isEnabled.then((enabled) {
          if (enabled && mounted) setState(() => _unlocked = false);
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked) {
      return const Scaffold(
        backgroundColor: AppTheme.background,
        body: SizedBox.shrink(),
      );
    }
    if (!_unlocked) {
      return LockScreen(onUnlocked: () => setState(() => _unlocked = true));
    }
    return widget.child;
  }
}

class LockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;
  const LockScreen({super.key, required this.onUnlocked});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final TextEditingController _pinController = TextEditingController();
  String? _error;
  bool _checkingBiometrics = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometrics());
  }

  Future<void> _tryBiometrics() async {
    final useBiometrics = await AppLockService().useBiometrics;
    if (!useBiometrics || !mounted) return;
    setState(() => _checkingBiometrics = true);
    final success = await AppLockService().authenticateWithBiometrics();
    if (!mounted) return;
    setState(() => _checkingBiometrics = false);
    if (success) widget.onUnlocked();
  }

  Future<void> _verifyPin() async {
    final valid = await AppLockService().verifyPin(_pinController.text);
    if (!mounted) return;
    if (valid) {
      widget.onUnlocked();
    } else {
      setState(() => _error = 'PIN incorrecto');
      _pinController.clear();
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: PageFrame(
          maxWidth: 480,
          child: Container(
            color: AppTheme.background,
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/icons/contador_engine_icon_source.png',
                        width: 72,
                        height: 72,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Contador Engine',
                        style: AppFonts.inter(
                            color: AppTheme.ink,
                            fontSize: 22,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Ingresá tu PIN para continuar',
                        style:
                            AppFonts.inter(color: AppTheme.muted, fontSize: 13),
                      ),
                      const SizedBox(height: 32),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(
                          children: [
                            TextField(
                              controller: _pinController,
                              autofocus: !_checkingBiometrics,
                              obscureText: true,
                              textAlign: TextAlign.center,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(6),
                              ],
                              style: AppFonts.inter(
                                  fontSize: 24, letterSpacing: 8),
                              decoration: InputDecoration(
                                counterText: '',
                                hintText: '••••',
                                errorText: _error,
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16)),
                              ),
                              onChanged: (_) {
                                if (_error != null) {
                                  setState(() => _error = null);
                                }
                              },
                              onSubmitted: (_) => _verifyPin(),
                            ),
                            const SizedBox(height: 16),
                            TextButton(
                                onPressed: () async {
                                  final recovered = await showDialog<bool>(
                                      context: context,
                                      builder: (_) =>
                                          const _PinRecoveryDialog());
                                  if (recovered == true && mounted) {
                                    widget.onUnlocked();
                                  }
                                },
                                child: const Text(
                                    'Olvidé el PIN · recuperar con mi cuenta')),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _verifyPin,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.colorScheme.primary,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16)),
                                ),
                                child: const Text('Desbloquear'),
                              ),
                            ),
                            FutureBuilder<bool>(
                              future: AppLockService().useBiometrics,
                              builder: (context, snapshot) {
                                if (snapshot.data != true) {
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: TextButton.icon(
                                    onPressed: _checkingBiometrics
                                        ? null
                                        : _tryBiometrics,
                                    icon: const Icon(Icons.fingerprint_rounded),
                                    label: const Text('Usar huella / Face ID'),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )),
    );
  }
}

class _PinRecoveryDialog extends StatefulWidget {
  const _PinRecoveryDialog();
  @override
  State<_PinRecoveryDialog> createState() => _PinRecoveryDialogState();
}

class _PinRecoveryDialogState extends State<_PinRecoveryDialog> {
  final password = TextEditingController(), otp = TextEditingController();
  bool busy = false;
  String? error;
  @override
  void dispose() {
    password.dispose();
    otp.dispose();
    super.dispose();
  }

  Future<void> recover() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final db = LocalDatabaseService();
      final email = db.currentUser?.email;
      if (email == null) throw StateError('Inicia sesión primero.');
      await db.signIn(email, password.text, otp: otp.text.trim());
      await AppLockService().setEnabled(false);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
          title: const Text('Recuperar acceso sin borrar datos'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text(
                'Confirma tu cuenta para desactivar el PIN. Después podrás crear uno nuevo.'),
            TextField(
                controller: password,
                obscureText: true,
                decoration: const InputDecoration(
                    labelText: 'Contraseña de tu cuenta')),
            TextField(
                controller: otp,
                decoration: const InputDecoration(
                    labelText: 'Código 2FA, si está activado')),
            if (error != null) Text(error!),
          ]),
          actions: [
            TextButton(
                onPressed: busy ? null : () => Navigator.pop(context),
                child: const Text('Cancelar')),
            FilledButton(
                onPressed: busy ? null : recover,
                child: const Text('Recuperar acceso'))
          ]);
}
