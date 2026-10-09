import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class DocumentFiles {
  static Future<String?> save(String name, List<int> bytes) async {
    if (kIsWeb) {
      await FilePicker.saveFile(
          fileName: name, bytes: Uint8List.fromList(bytes));
      return 'download:$name';
    }
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  static Future<Uint8List?> pickJson() async {
    final result = await FilePicker.pickFiles(
        type: FileType.custom, allowedExtensions: ['json'], withData: true);
    if (result == null) return null;
    final file = result.files.single;
    if (file.size > 20 * 1024 * 1024) {
      throw ArgumentError('El respaldo supera 20 MB.');
    }
    if (file.bytes != null) return file.bytes;
    if (!kIsWeb && file.path != null) return File(file.path!).readAsBytes();
    throw StateError('No se pudo leer el archivo.');
  }
}
