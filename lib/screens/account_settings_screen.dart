import '../widgets/app_ui.dart';
import '../utils/app_theme.dart';
import 'package:flutter/material.dart';
import '../utils/local_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/debt_provider.dart';
import '../services/local_database_service.dart';
import '../utils/sensitive_action_guard.dart';
import '../utils/shared_styles.dart';

/// Acciones sensibles (borrar todo, cerrar sesión) puestas detrás de una
/// navegación extra a propósito, para que no queden al alcance de un toque
/// de más mientras se recorre la Configuración normal.
class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  static const String _resetConfirmationText = 'EMPEZAR DE CERO';

  void _showResetDataDialog() {
    final confirmationController = TextEditingController();
    bool isProcessing = false;

    showBlurDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final matchesText =
                confirmationController.text.trim() == _resetConfirmationText;

            return AlertDialog(
              scrollable: true,
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              shape: dialogShape(),
              titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              contentPadding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
              title: Text(
                'Empezar de cero',
                style:
                    AppFonts.inter(fontWeight: FontWeight.w700, fontSize: 17),
              ),
              content: dialogContent([
                Text(
                  'Esto borrará todos los registros guardados. ¿Está seguro de continuar?',
                  style: AppFonts.inter(fontSize: 13, color: Colors.grey[500]),
                ),
                const SizedBox(height: 12),
                Text(
                  'Se eliminarán clientes, préstamos, pagos y configuraciones.',
                  style: AppFonts.inter(fontSize: 12, color: Colors.grey[400]),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Text(
                    'Para confirmar, escribe: $_resetConfirmationText',
                    style: AppFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFEF4444),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: confirmationController,
                  enabled: !isProcessing,
                  onChanged: (_) => setDialogState(() {}),
                  decoration: minimalFieldDecoration(
                    label: 'Frase de confirmación',
                    hint: 'Escribe la frase exacta',
                  ),
                ),
              ]),
              actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              actions: [
                TextButton(
                  onPressed: isProcessing
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[600],
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                  child: Text('Cancelar',
                      style: AppFonts.inter(fontWeight: FontWeight.w600)),
                ),
                ElevatedButton(
                  onPressed: (!matchesText || isProcessing)
                      ? null
                      : () async {
                          setDialogState(() => isProcessing = true);
                          // Se capturan antes del await para no volver a
                          // resolver un BuildContext después del salto
                          // asíncrono (evita usar un context que puede
                          // haber dejado de ser válido mientras se espera).
                          final dialogNavigator = Navigator.of(dialogContext);
                          final messenger = ScaffoldMessenger.of(this.context);
                          try {
                            final provider = Provider.of<DebtProvider>(
                              this.context,
                              listen: false,
                            );
                            await provider.resetAllData();

                            if (!mounted) return;
                            dialogNavigator.pop();
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Todos los registros fueron eliminados.',
                                ),
                                backgroundColor: Color(0xFF10B981),
                              ),
                            );
                          } catch (_) {
                            if (!mounted) return;
                            setDialogState(() => isProcessing = false);
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'No se pudo borrar la información. Intenta nuevamente.',
                                ),
                                backgroundColor: Color(0xFFEF4444),
                              ),
                            );
                          }
                        },
                  style: solidActionButtonStyle(context,
                      color: const Color(0xFFEF4444)),
                  child: isProcessing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Borrar todo'),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(() {
      confirmationController.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: PageFrame(
          child: Column(
        children: [
          const PageHeading(title: 'Administrar cuenta', back: true),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  'Zona de Riesgo',
                  style: AppFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFFECACA)),
                    boxShadow: const [],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.delete_forever_rounded,
                              color: Color(0xFFEF4444),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Empezar de cero',
                                  style: AppFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Borra todos los registros y reinicia la información del usuario.',
                                  style: AppFonts.inter(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => requireSensitiveActionUnlock(
                            context,
                            reason:
                                'Vas a borrar TODOS los datos del negocio de forma permanente.',
                            onUnlocked: _showResetDataDialog,
                          ),
                          icon: const Icon(
                            Icons.warning_amber_rounded,
                            color: Color(0xFFEF4444),
                          ),
                          label: Text(
                            'Empezar de cero',
                            style: AppFonts.inter(
                              color: const Color(0xFFEF4444),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: const BorderSide(color: Color(0xFFEF4444)),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final pending =
                          Provider.of<DebtProvider>(context, listen: false)
                              .pendingCount;
                      requireSensitiveActionUnlock(
                        context,
                        reason: pending > 0
                            ? 'Tienes $pending cambio(s) sin sincronizar. Si cierras sesión ahora, podrías perder acceso a ellos hasta volver a iniciar sesión.'
                            : 'Vas a cerrar tu sesión en este dispositivo.',
                        onUnlocked: () {
                          LocalDatabaseService().signOut();
                          Navigator.of(context)
                              .popUntil((route) => route.isFirst);
                        },
                      );
                    },
                    icon: const Icon(Icons.logout_rounded,
                        color: Color(0xFFEF4444)),
                    label: Text('Cerrar Sesión',
                        style: AppFonts.inter(
                            color: const Color(0xFFEF4444),
                            fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: Color(0xFFEF4444)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      )),
    );
  }
}
