import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/local_database_service.dart';
import '../utils/app_theme.dart';

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
  final _otp = TextEditingController();
  bool _registering = false, _busy = false, _obscure = true, _useOtp = false;
  String? _error;
  @override
  void dispose() {
    for (final c in [_email, _password, _name, _otp]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final db = LocalDatabaseService();
      if (_registering) {
        await db.register(
            _name.text.trim(), _email.text.trim(), _password.text);
      }
      await db.signIn(_email.text.trim(), _password.text,
          otp: _useOtp ? _otp.text.trim() : '');
      TextInput.finishAutofillContext();
    } catch (e) {
      if (mounted) {
        setState(
            () => _error = e.toString().replaceFirst(RegExp(r'^[\w ]+: '), ''));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
        body: SafeArea(
            child: SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Center(
          child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: AutofillGroup(
            child: Form(
                key: _form,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.account_balance_wallet_rounded,
                          size: 42, color: AppTheme.primary),
                      const SizedBox(height: 12),
                      Text('Contador Engine',
                          textAlign: TextAlign.center,
                          style: text.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      const Text('Tus créditos, paso a paso.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.muted)),
                      const SizedBox(height: 32),
                      Card(
                          child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                        _registering
                                            ? 'Crea tu cuenta'
                                            : 'Te damos la bienvenida',
                                        style: text.headlineSmall?.copyWith(
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 8),
                                    Text(
                                        _registering
                                            ? 'Regístrate para solicitar un crédito y seguir su avance.'
                                            : 'Ingresa para continuar con tus solicitudes.',
                                        style: const TextStyle(
                                            color: AppTheme.muted,
                                            height: 1.5)),
                                    const SizedBox(height: 24),
                                    if (_registering) ...[
                                      TextFormField(
                                          controller: _name,
                                          enabled: !_busy,
                                          textCapitalization:
                                              TextCapitalization.words,
                                          autofillHints: const [
                                            AutofillHints.name
                                          ],
                                          textInputAction: TextInputAction.next,
                                          decoration: const InputDecoration(
                                              labelText: 'Nombre completo',
                                              prefixIcon:
                                                  Icon(Icons.person_outline)),
                                          validator: (v) => (v?.trim().length ??
                                                      0) <
                                                  2
                                              ? 'Escribe tu nombre completo.'
                                              : null),
                                      const SizedBox(height: 18),
                                    ],
                                    TextFormField(
                                        controller: _email,
                                        enabled: !_busy,
                                        keyboardType:
                                            TextInputType.emailAddress,
                                        autocorrect: false,
                                        autofillHints: const [
                                          AutofillHints.username
                                        ],
                                        textInputAction: TextInputAction.next,
                                        decoration: const InputDecoration(
                                            labelText: 'Correo electrónico',
                                            hintText: 'nombre@ejemplo.com',
                                            prefixIcon:
                                                Icon(Icons.mail_outline)),
                                        validator: (v) => v == null ||
                                                !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                                    .hasMatch(v.trim())
                                            ? 'Escribe un correo válido.'
                                            : null),
                                    const SizedBox(height: 18),
                                    TextFormField(
                                        controller: _password,
                                        enabled: !_busy,
                                        obscureText: _obscure,
                                        autofillHints: [
                                          _registering
                                              ? AutofillHints.newPassword
                                              : AutofillHints.password
                                        ],
                                        textInputAction: TextInputAction.done,
                                        onFieldSubmitted: (_) => _submit(),
                                        decoration: InputDecoration(
                                            labelText: 'Contraseña',
                                            prefixIcon:
                                                const Icon(Icons.lock_outline),
                                            suffixIcon: IconButton(
                                                tooltip: _obscure
                                                    ? 'Mostrar contraseña'
                                                    : 'Ocultar contraseña',
                                                onPressed: () => setState(
                                                    () => _obscure = !_obscure),
                                                icon: Icon(_obscure
                                                    ? Icons.visibility_outlined
                                                    : Icons
                                                        .visibility_off_outlined))),
                                        validator: (v) => v == null || v.isEmpty
                                            ? 'Escribe tu contraseña.'
                                            : null),
                                    if (!_registering) ...[
                                      const SizedBox(height: 8),
                                      CheckboxListTile(
                                          contentPadding: EdgeInsets.zero,
                                          controlAffinity:
                                              ListTileControlAffinity.leading,
                                          title: const Text(
                                              'Uso un código de autenticación',
                                              style: TextStyle(fontSize: 14)),
                                          value: _useOtp,
                                          onChanged: _busy
                                              ? null
                                              : (v) =>
                                                  setState(() => _useOtp = v!)),
                                      if (_useOtp)
                                        TextFormField(
                                            controller: _otp,
                                            enabled: !_busy,
                                            keyboardType: TextInputType.number,
                                            maxLength: 6,
                                            inputFormatters: [
                                              FilteringTextInputFormatter
                                                  .digitsOnly
                                            ],
                                            decoration: const InputDecoration(
                                                labelText:
                                                    'Código de 6 dígitos',
                                                helperText:
                                                    'Abre tu aplicación autenticadora.'),
                                            validator: (v) =>
                                                _useOtp && (v?.length ?? 0) != 6
                                                    ? 'Completa los 6 dígitos.'
                                                    : null,
                                            onFieldSubmitted: (_) => _submit()),
                                    ],
                                    if (_error != null) ...[
                                      const SizedBox(height: 12),
                                      Semantics(
                                          liveRegion: true,
                                          child: Text(_error!,
                                              style: TextStyle(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .error)))
                                    ],
                                    const SizedBox(height: 20),
                                    FilledButton(
                                        onPressed: _busy ? null : _submit,
                                        child: _busy
                                            ? const SizedBox(
                                                width: 20,
                                                height: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                        strokeWidth: 2))
                                            : Text(_registering
                                                ? 'Crear cuenta'
                                                : 'Iniciar sesión')),
                                    const SizedBox(height: 12),
                                    TextButton(
                                        onPressed: _busy
                                            ? null
                                            : () {
                                                setState(() {
                                                  _registering = !_registering;
                                                  _error = null;
                                                  _useOtp = false;
                                                });
                                                _form.currentState?.reset();
                                              },
                                        child: Text(_registering
                                            ? 'Ya tengo una cuenta · Iniciar sesión'
                                            : '¿Primera vez? Crear cuenta')),
                                  ]))),
                      const SizedBox(height: 24),
                      const Text(
                          'Simulación académica · Datos guardados en este equipo',
                          textAlign: TextAlign.center,
                          style:
                              TextStyle(fontSize: 12, color: AppTheme.muted)),
                    ]))),
      )),
    )));
  }
}
