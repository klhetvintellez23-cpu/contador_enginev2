import '../utils/app_theme.dart';
import 'package:flutter/material.dart';
import '../utils/local_fonts.dart';

import '../services/update_service.dart';
import '../utils/shared_styles.dart';

const Color _kPurple = Color(0xFF7C3AED);

/// Muestra el modal de "hay una versión nueva" y gestiona la descarga.
Future<void> showUpdateDialog(BuildContext context, AppRelease release) {
  return showBlurDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => _UpdateDialog(release: release),
  );
}

class _UpdateDialog extends StatefulWidget {
  final AppRelease release;
  const _UpdateDialog({required this.release});

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  bool _downloading = false;
  double _progress = 0;
  String? _error;

  Future<void> _start() async {
    setState(() {
      _downloading = true;
      _progress = 0;
      _error = null;
    });

    try {
      await UpdateService().downloadAndInstall(
        widget.release,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      // El instalador de Android ya está al frente; cerramos el modal para que
      // la app no quede bloqueada si el usuario cancela la instalación.
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sizeMb = widget.release.apkSizeBytes / (1024 * 1024);

    return Dialog(
      shape: dialogShape(),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _kPurple.withAlpha(26),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.system_update_rounded,
                      color: _kPurple, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Actualización disponible',
                        style: AppFonts.inter(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Versión ${widget.release.version}'
                        '${sizeMb > 0 ? ' · ${sizeMb.toStringAsFixed(1)} MB' : ''}',
                        style: AppFonts.inter(
                          fontSize: 13,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          dialogContent([
            if (widget.release.notes.isNotEmpty) ...[
              Text('NOVEDADES', style: sectionCaptionStyle()),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: SingleChildScrollView(
                  child: Text(
                    widget.release.notes,
                    style: AppFonts.inter(
                      fontSize: 14,
                      height: 1.5,
                      color: AppTheme.muted,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
            if (_downloading) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _progress == 0 ? null : _progress,
                  minHeight: 8,
                  backgroundColor: kFieldFill,
                  valueColor: const AlwaysStoppedAnimation(_kPurple),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _progress >= 1
                    ? 'Abriendo el instalador…'
                    : 'Descargando… ${(_progress * 100).toStringAsFixed(0)}%',
                style: AppFonts.inter(fontSize: 13, color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
            ],
            if (_error != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _error!,
                  style: AppFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFFB91C1C),
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
            child: Row(
              children: [
                if (!_downloading)
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        foregroundColor: Colors.grey[600],
                      ),
                      child: Text(
                        'Después',
                        style: AppFonts.inter(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                if (!_downloading) const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _downloading ? null : _start,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kPurple,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      _downloading
                          ? 'Descargando…'
                          : (_error != null ? 'Reintentar' : 'Actualizar'),
                      style: AppFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
