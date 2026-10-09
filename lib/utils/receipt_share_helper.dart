import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/customer.dart';
import '../models/payment.dart';
import '../models/transaction.dart';
import '../services/local_cache_service.dart';
import '../widgets/receipt_card.dart';

/// Arma y envía el comprobante de un cobro como imagen a través del
/// selector nativo de compartir (el usuario elige WhatsApp, correo, etc.).
/// wa.me solo admite texto precargado, no adjuntar archivos, así que no
/// se usa para el comprobante en sí.
class ReceiptShareHelper {
  static final NumberFormat _currency =
      NumberFormat.currency(symbol: r'$', decimalDigits: 2);

  static Future<void> shareReceiptForPayment({
    required BuildContext context,
    required Payment payment,
    required LoanTransaction? loan,
    required Customer? customer,
    required double remaining,
    String? businessName,
    String? businessLogoPath,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final customerName = customer?.name ?? payment.customerName ?? 'Cliente';
    final message = _buildMessage(
      customerName: customerName,
      amount: payment.amount,
      loanTitle: loan?.title ?? 'Préstamo',
      remaining: remaining,
      businessName: businessName,
    );

    await _shareReceiptImage(
      messenger: messenger,
      payment: payment,
      loan: loan,
      customer: customer,
      remaining: remaining,
      message: message,
      businessName: businessName,
      businessLogoPath: businessLogoPath,
    );
  }

  /// Genera y guarda el comprobante en el historial del cliente sin abrir
  /// el selector de compartir. Se llama en cada cobro registrado (aunque
  /// el usuario no lo comparta) para que el historial de comprobantes del
  /// cliente quede siempre completo.
  static Future<void> generateAndSaveReceipt({
    required Payment payment,
    required LoanTransaction? loan,
    required Customer? customer,
    required double remaining,
    String? businessName,
    String? businessLogoPath,
  }) async {
    if (customer?.id == null) return;
    try {
      await _captureAndSaveFile(
        payment: payment,
        loan: loan,
        customer: customer,
        remaining: remaining,
        businessName: businessName,
        businessLogoPath: businessLogoPath,
      );
    } catch (e) {
      debugPrint('No se pudo generar el comprobante en segundo plano: $e');
    }
  }

  static String _buildMessage({
    required String customerName,
    required double amount,
    required String loanTitle,
    required double remaining,
    String? businessName,
  }) {
    final buffer = StringBuffer()
      ..writeln(
          'Hola $customerName, confirmamos tu abono de ${_currency.format(amount)} a "$loanTitle".');
    if (remaining <= 0) {
      buffer.writeln(
          'Tu préstamo quedó saldado por completo. ¡Gracias por tu pago!');
    } else {
      buffer.writeln('Saldo pendiente: ${_currency.format(remaining)}.');
    }
    final signature = (businessName != null && businessName.isNotEmpty)
        ? businessName
        : 'Contador Engine';
    buffer.write('— $signature');
    return buffer.toString();
  }

  /// Recordatorio manual de cobro atrasado: abre WhatsApp con el mensaje ya
  /// escrito para que el usuario solo confirme "Enviar". A diferencia del
  /// comprobante, esto lo dispara la persona a mano desde el listado de
  /// atrasados — la app no manda nada en automático ni en segundo plano.
  static Future<void> sendOverdueReminder({
    required BuildContext context,
    required Customer customer,
    required LoanTransaction loan,
    required int daysSince,
    required double remaining,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final digits = (customer.phone ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 11) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Este cliente no tiene un teléfono válido registrado.'),
          backgroundColor: Color(0xFFF59E0B),
        ),
      );
      return;
    }

    final firstName = customer.name.split(' ').first;
    final message = 'Hola $firstName, te escribimos de parte tuya para '
        'recordarte tu saldo pendiente de ${_currency.format(remaining)} en '
        '"${loan.title}". Van $daysSince día(s) sin registrar un cobro. '
        '¡Gracias!';

    final opened = await _tryOpenWhatsApp(digits, message);
    if (!opened) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir WhatsApp.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
    }
  }

  static Future<bool> _tryOpenWhatsApp(String digits, String message) async {
    try {
      final uri = Uri.parse(
          'https://wa.me/$digits?text=${Uri.encodeComponent(message)}');
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint(
          'No se pudo abrir WhatsApp directo, se usa el selector genérico: $e');
      return false;
    }
  }

  static Future<void> _shareReceiptImage({
    required ScaffoldMessengerState messenger,
    required Payment payment,
    required LoanTransaction? loan,
    required Customer? customer,
    required double remaining,
    required String message,
    String? businessName,
    String? businessLogoPath,
  }) async {
    try {
      var file = await _existingReceiptFile(payment.id);

      if (file == null) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Generando comprobante...'),
            duration: Duration(seconds: 2),
          ),
        );
        file = await _captureAndSaveFile(
          payment: payment,
          loan: loan,
          customer: customer,
          remaining: remaining,
          businessName: businessName,
          businessLogoPath: businessLogoPath,
        );
      }

      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], text: message),
      );
    } catch (e) {
      debugPrint('Error sharing receipt: $e');
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Error al generar el comprobante en imagen.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
    }
  }

  /// Si ese cobro ya tiene un comprobante guardado (y el archivo sigue en
  /// disco), lo reutiliza en vez de volver a renderizar la imagen.
  static Future<File?> _existingReceiptFile(dynamic paymentId) async {
    if (paymentId == null) return null;
    final record = LocalCacheService().receiptForPayment(paymentId.toString());
    final path = record?['filePath'] as String?;
    if (path == null) return null;
    final file = File(path);
    return await file.exists() ? file : null;
  }

  /// Renderiza el comprobante como imagen, lo guarda en disco y, si hay
  /// cliente identificado, indexa el registro en su historial local.
  static Future<File> _captureAndSaveFile({
    required Payment payment,
    required LoanTransaction? loan,
    required Customer? customer,
    required double remaining,
    String? businessName,
    String? businessLogoPath,
  }) async {
    final f = DateFormat('dd/MM/yyyy hh:mm a');
    final paymentId = (payment.id ?? 'N/A').toString();
    final safeId = paymentId.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    final cleanId = safeId.isEmpty
        ? DateTime.now().millisecondsSinceEpoch.toString()
        : safeId;
    final shortRef =
        cleanId.substring(0, cleanId.length < 8 ? cleanId.length : 8);

    final controller = ScreenshotController();
    final imageBytes = await controller.captureFromWidget(
      ReceiptCard(
        customerName: customer?.name ?? payment.customerName ?? 'Cliente',
        cedula: customer?.cedula ?? 'No reg.',
        amount: payment.amount,
        date: f.format(payment.date),
        reference: paymentId,
        remainingBalance: remaining,
        loanTitle: loan?.title ?? 'Préstamo',
        currencyFormat: _currency,
        issuerName: businessName,
        issuerLogoPath: businessLogoPath,
      ),
      delay: const Duration(milliseconds: 100),
      // Fixed, generous canvas so the receipt never depends on the
      // current window size (was clipping on small desktop windows).
      targetSize: const Size(400, 950),
    );

    final file = await _saveReceiptFile(
      customerId: customer?.id,
      fileName: 'comprobante_$shortRef.png',
      bytes: imageBytes,
    );

    if (customer?.id != null) {
      await LocalCacheService().saveReceiptRecord({
        'id': 'r_${customer!.id}_${DateTime.now().millisecondsSinceEpoch}',
        'paymentId': paymentId,
        'customerId': customer.id.toString(),
        'customerName': customer.name,
        'loanTitle': loan?.title ?? 'Préstamo',
        'amount': payment.amount,
        'date': payment.date.toIso8601String(),
        'filePath': file.path,
      });
    }

    return file;
  }

  /// Con cliente identificado, el comprobante se guarda en un directorio
  /// permanente por cliente (para poder listarlo/reenviarlo después). Sin
  /// cliente, se usa un archivo temporal de un solo uso, como antes.
  static Future<File> _saveReceiptFile({
    required dynamic customerId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    if (customerId == null) {
      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/$fileName').create();
      return file.writeAsBytes(bytes);
    }

    final docsDir = await getApplicationDocumentsDirectory();
    final receiptsDir = Directory('${docsDir.path}/receipts/$customerId');
    await receiptsDir.create(recursive: true);
    final file = await File('${receiptsDir.path}/$fileName').create();
    return file.writeAsBytes(bytes);
  }
}
