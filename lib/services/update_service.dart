import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// Repositorio PÚBLICO donde se publican los APKs. El código fuente vive en un
/// repo privado aparte; aquí solo van los releases, para que la app pueda
/// consultar la API de GitHub sin token.
const String kReleasesRepo = 'klhetvintellez23-cpu/contador-engine-releases';

/// Datos del release más reciente publicado en GitHub.
class AppRelease {
  final String version; // "1.0.1" (sin la "v")
  final String notes; // cuerpo del release, para mostrar los cambios
  final String apkUrl;
  final int apkSizeBytes;

  const AppRelease({
    required this.version,
    required this.notes,
    required this.apkUrl,
    required this.apkSizeBytes,
  });
}

/// Resultado de una comprobación manual de actualización, para poder
/// distinguir "ya estás al día" de "no se pudo comprobar" en la UI.
enum UpdateCheckStatus {
  /// Hay una versión nueva disponible (ver [UpdateCheckResult.release]).
  updateAvailable,

  /// La app ya está en la última versión.
  upToDate,

  /// La plataforma no admite auto-actualización por APK (iOS, web, escritorio).
  notSupported,

  /// No se pudo comprobar (sin internet, GitHub caído, respuesta inesperada).
  failed,
}

class UpdateCheckResult {
  final UpdateCheckStatus status;
  final AppRelease? release;
  const UpdateCheckResult(this.status, [this.release]);
}

/// Consulta GitHub Releases, descarga el APK y lanza el instalador de Android.
class UpdateService {
  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();

  /// Versión instalada actualmente (p. ej. "1.0.4"). Cadena vacía si falla.
  Future<String> currentVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return info.version;
    } catch (_) {
      return '';
    }
  }

  /// Devuelve el release más nuevo si es posterior a la versión instalada.
  /// Devuelve `null` si ya está al día, si no es Android, o si algo falla
  /// (el chequeo nunca debe romper el arranque de la app).
  Future<AppRelease?> checkForUpdate() async {
    final result = await checkForUpdateDetailed();
    return result.status == UpdateCheckStatus.updateAvailable
        ? result.release
        : null;
  }

  /// Igual que [checkForUpdate] pero devuelve el estado detallado, para la
  /// comprobación manual desde Ajustes (distingue "al día" de "falló").
  Future<UpdateCheckResult> checkForUpdateDetailed() async {
    if (kIsWeb || !Platform.isAndroid) {
      return const UpdateCheckResult(UpdateCheckStatus.notSupported);
    }

    try {
      final info = await PackageInfo.fromPlatform();
      final response = await http.get(
        Uri.parse(
          'https://api.github.com/repos/$kReleasesRepo/releases/latest',
        ),
        headers: {'Accept': 'application/vnd.github+json'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        return const UpdateCheckResult(UpdateCheckStatus.failed);
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['draft'] == true || data['prerelease'] == true) {
        return const UpdateCheckResult(UpdateCheckStatus.upToDate);
      }

      final tag = (data['tag_name'] as String? ?? '').trim();
      final latest = tag.startsWith('v') ? tag.substring(1) : tag;
      if (latest.isEmpty) {
        return const UpdateCheckResult(UpdateCheckStatus.failed);
      }

      final assets = (data['assets'] as List?) ?? const [];
      final apk = assets.cast<Map<String, dynamic>>().firstWhere(
            (a) => (a['name'] as String? ?? '').toLowerCase().endsWith('.apk'),
            orElse: () => const <String, dynamic>{},
          );
      final apkUrl = apk['browser_download_url'] as String?;
      if (apkUrl == null) {
        return const UpdateCheckResult(UpdateCheckStatus.failed);
      }

      if (!_isNewer(latest, info.version)) {
        return const UpdateCheckResult(UpdateCheckStatus.upToDate);
      }

      return UpdateCheckResult(
        UpdateCheckStatus.updateAvailable,
        AppRelease(
          version: latest,
          notes: (data['body'] as String? ?? '').trim(),
          apkUrl: apkUrl,
          apkSizeBytes: (apk['size'] as num?)?.toInt() ?? 0,
        ),
      );
    } catch (_) {
      // Sin internet, GitHub caído, JSON raro: se ignora y se sigue normal.
      return const UpdateCheckResult(UpdateCheckStatus.failed);
    }
  }

  /// Descarga el APK reportando el avance de 0.0 a 1.0 y abre el instalador.
  /// Lanza [Exception] con un mensaje mostrable si algo sale mal.
  Future<void> downloadAndInstall(
    AppRelease release, {
    required void Function(double progress) onProgress,
  }) async {
    // Android 8+ exige que el usuario autorice a esta app específica a
    // instalar APKs; sin esto el instalador se abre y falla en silencio.
    final status = await Permission.requestInstallPackages.request();
    if (!status.isGranted) {
      throw Exception(
        'Necesitas permitir "Instalar apps desconocidas" para Contador Engine '
        'en los ajustes del teléfono.',
      );
    }

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/contador-engine-${release.version}.apk');
    if (await file.exists()) await file.delete();

    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(release.apkUrl));
      final response = await client.send(request);
      if (response.statusCode != 200) {
        throw Exception('No se pudo descargar la actualización.');
      }

      final total = response.contentLength ?? release.apkSizeBytes;
      final sink = file.openWrite();
      var received = 0;
      try {
        await for (final chunk in response.stream) {
          sink.add(chunk);
          received += chunk.length;
          if (total > 0) onProgress(received / total);
        }
      } finally {
        await sink.close();
      }
    } finally {
      client.close();
    }

    onProgress(1.0);

    final result = await OpenFilex.open(
      file.path,
      type: 'application/vnd.android.package-archive',
    );
    if (result.type != ResultType.done) {
      throw Exception('No se pudo abrir el instalador: ${result.message}');
    }
  }

  /// Compara versiones semánticas ("1.2.10" es mayor que "1.2.9").
  bool _isNewer(String latest, String current) {
    final a = _parts(latest);
    final b = _parts(current);
    for (var i = 0; i < 3; i++) {
      if (a[i] != b[i]) return a[i] > b[i];
    }
    return false;
  }

  List<int> _parts(String version) {
    // Descarta el build number (+3) y cualquier sufijo tipo "-beta".
    final clean = version.split('+').first.split('-').first;
    final nums = clean.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    while (nums.length < 3) {
      nums.add(0);
    }
    return nums.take(3).toList();
  }
}
