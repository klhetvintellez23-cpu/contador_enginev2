import 'package:flutter/material.dart';
import '../services/local_database_service.dart';
import '../widgets/auth_ui.dart';
import 'otp_verification_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  bool _registering = false, _busy = false, _obscure = true;
  String? _error;

  @override
  void dispose() {
    for (final controller in [_email, _password, _name]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Paint the pressed/loading state before checking local credentials.
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      final db = LocalDatabaseService();
      if (_registering) {
        await db.register(
            _name.text.trim(), _email.text.trim(), _password.text);
        if (!mounted) return;
        // Returning from verification resumes login for the newly created user.
        setState(() => _registering = false);
      }
      final challenge =
          await db.beginPrototypeSignIn(_email.text.trim(), _password.text);
      if (!mounted) {
        db.cancelPrototypeSignIn(challenge);
        return;
      }
      await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => OtpVerificationScreen(challenge: challenge),
      ));
    } catch (error) {
      if (mounted) {
        setState(() => _error = authErrorMessage(error));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toggleRegistration() {
    setState(() {
      _registering = !_registering;
      _error = null;
    });
    _form.currentState?.reset();
  }

  @override
  Widget build(BuildContext context) => AuthCardContainer(
        child: AutofillGroup(
          onDisposeAction: AutofillContextAction.cancel,
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_registering) ...[
                  Text('Crea tu cuenta',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 24),
                  TextFormField(
                    key: const ValueKey('auth-name'),
                    controller: _name,
                    enabled: !_busy,
                    textCapitalization: TextCapitalization.words,
                    autofillHints: const [AutofillHints.name],
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                        labelText: 'Nombre completo',
                        prefixIcon: Icon(Icons.person_outline)),
                    validator: (value) => (value?.trim().length ?? 0) < 2
                        ? 'Escribe tu nombre completo.'
                        : null,
                  ),
                  const SizedBox(height: 18),
                ],
                TextFormField(
                  key: const ValueKey('auth-email'),
                  controller: _email,
                  enabled: !_busy,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  autofillHints: const [AutofillHints.username],
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                      labelText: 'Correo electrónico',
                      hintText: 'nombre@ejemplo.com',
                      prefixIcon: Icon(Icons.mail_outline)),
                  validator: (value) => value == null ||
                          !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                              .hasMatch(value.trim())
                      ? 'Escribe un correo válido.'
                      : null,
                ),
                const SizedBox(height: 18),
                TextFormField(
                  key: const ValueKey('auth-password'),
                  controller: _password,
                  enabled: !_busy,
                  obscureText: _obscure,
                  autocorrect: false,
                  enableSuggestions: false,
                  autofillHints: [
                    _registering
                        ? AutofillHints.newPassword
                        : AutofillHints.password
                  ],
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      tooltip: _obscure
                          ? 'Mostrar contraseña'
                          : 'Ocultar contraseña',
                      onPressed: _busy
                          ? null
                          : () => setState(() => _obscure = !_obscure),
                      icon: Icon(_obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                    ),
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Escribe tu contraseña.'
                      : _registering && value.length < 12
                          ? 'Usa al menos 12 caracteres.'
                          : null,
                ),
                AuthError(message: _error),
                const SizedBox(height: 24),
                AuthPrimaryButton(
                  label: _registering ? 'Crear cuenta' : 'Iniciar sesión',
                  busy: _busy,
                  onPressed: _submit,
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: _busy ? null : _toggleRegistration,
                  child: Text(
                      _registering
                          ? 'Ya tengo una cuenta · Iniciar sesión'
                          : '¿Primera vez? Crear cuenta',
                      textAlign: TextAlign.center),
                ),
              ],
            ),
          ),
        ),
      );
}
