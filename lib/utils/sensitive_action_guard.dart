import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'local_fonts.dart';
import '../services/app_lock_service.dart';
import 'shared_styles.dart';

/// Exige el mismo PIN/biometría que ya protege la apertura de la app (ver
/// lock_screen.dart) antes de ejecutar una acción sensible (borrar datos,
/// exportar/importar respaldo, cerrar sesión). Si el usuario nunca activó
/// el bloqueo de la app, no hay nada que pedir y [onUnlocked] se llama
/// directo — no se obliga a nadie a configurar PIN solo para esto.
Future<void> requireSensitiveActionUnlock(
  BuildContext context, {
  required String reason,
  required VoidCallback onUnlocked,
}) async {
  final enabled = await AppLockService().isEnabled;
  if (!context.mounted) return;
  if (!enabled) {
    onUnlocked();
    return;
  }

  final confirmed = await showBlurDialog<bool>(
    context: context,
    builder: (dialogContext) => _UnlockDialog(reason: reason),
  );

  if (confirmed == true) onUnlocked();
}

class _UnlockDialog extends StatefulWidget {
  final String reason;
  const _UnlockDialog({required this.reason});

  @override
  State<_UnlockDialog> createState() => _UnlockDialogState();
}

class _UnlockDialogState extends State<_UnlockDialog> {
  final _pinController = TextEditingController();
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
    if (success) Navigator.of(context).pop(true);
  }

  Future<void> _verifyPin() async {
    final valid = await AppLockService().verifyPin(_pinController.text);
    if (!mounted) return;
    if (valid) {
      Navigator.of(context).pop(true);
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
    return AlertDialog(
      scrollable: true,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: dialogShape(),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
      title: Row(
        children: [
          Icon(Icons.lock_outline_rounded,
              color: theme.colorScheme.primary, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Confirmá tu identidad',
                style:
                    AppFonts.inter(fontWeight: FontWeight.w700, fontSize: 17)),
          ),
        ],
      ),
      content: dialogContent([
        Text(widget.reason,
            style: AppFonts.inter(fontSize: 13, color: Colors.grey[500])),
        const SizedBox(height: 20),
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
          style: AppFonts.inter(fontSize: 22, letterSpacing: 8),
          decoration: InputDecoration(
            counterText: '',
            hintText: '••••',
            errorText: _error,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            border: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.grey.shade300)),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF7C3AED), width: 1.5),
            ),
            errorBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFEF4444)),
            ),
          ),
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          onSubmitted: (_) => _verifyPin(),
        ),
        FutureBuilder<bool>(
          future: AppLockService().useBiometrics,
          builder: (context, snapshot) {
            if (snapshot.data != true) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 4),
              child: TextButton.icon(
                onPressed: _checkingBiometrics ? null : _tryBiometrics,
                icon: const Icon(Icons.fingerprint_rounded),
                label: const Text('Usar huella / Face ID'),
              ),
            );
          },
        ),
      ]),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          style: TextButton.styleFrom(
            foregroundColor: Colors.grey[600],
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          child: Text('Cancelar',
              style: AppFonts.inter(fontWeight: FontWeight.w600)),
        ),
        ElevatedButton(
          onPressed: _verifyPin,
          style: solidActionButtonStyle(context),
          child: const Text('Desbloquear'),
        ),
      ],
    );
  }
}
