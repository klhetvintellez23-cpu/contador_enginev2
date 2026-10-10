import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> saveUiPreview(
    WidgetTester tester, GlobalKey key, String name) async {
  final shadows = debugDisableShadows;
  try {
    debugDisableShadows = false;
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    void repaint(RenderObject object) {
      object.markNeedsPaint();
      object.visitChildren(repaint);
    }

    repaint(boundary);
    await tester.pump();
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1.5);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('.review/ui-$name.png')
          .writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    });
  } finally {
    debugDisableShadows = shadows;
  }
}
