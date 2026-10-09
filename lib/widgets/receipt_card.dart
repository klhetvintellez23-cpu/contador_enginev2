import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ReceiptCard extends StatelessWidget {
  final String customerName;
  final String cedula;
  final double amount;
  final String date;
  final String reference;
  final double remainingBalance;
  final String loanTitle;
  final NumberFormat currencyFormat;
  final String? issuerName;
  final String? issuerLogoPath;

  const ReceiptCard({
    super.key,
    required this.customerName,
    required this.cedula,
    required this.amount,
    required this.date,
    required this.reference,
    required this.remainingBalance,
    required this.loanTitle,
    required this.currencyFormat,
    this.issuerName,
    this.issuerLogoPath,
  });

  // Usar TextStyle del sistema para evitar que GoogleFonts bloquee captureFromWidget
  static const _bold =
      TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B));
  static const _grey = TextStyle(color: Colors.grey, fontSize: 12);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 400,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(color: Colors.white),
      child: Material(
        color: Colors.white,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (issuerName != null && issuerName!.isNotEmpty)
                            ? issuerName!.toUpperCase()
                            : 'CONTADOR ENGINE',
                        style: _bold.copyWith(
                          fontSize: 18,
                          color: const Color(0xFF7C3AED),
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        'COMPROBANTE DE PAGO',
                        style: _bold.copyWith(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                (issuerLogoPath != null && issuerLogoPath!.isNotEmpty)
                    ? ClipOval(
                        child: Container(
                          width: 50,
                          height: 50,
                          color: const Color(0xFF7C3AED).withAlpha(26),
                          child: Image.file(
                            File(issuerLogoPath!),
                            fit: BoxFit.cover,
                          ),
                        ),
                      )
                    : Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C3AED).withAlpha(26),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.verified_rounded,
                            color: Color(0xFF7C3AED), size: 30),
                      ),
              ],
            ),
            const SizedBox(height: 32),
            Container(
                height: 1, color: Colors.grey[100], width: double.infinity),
            const SizedBox(height: 32),

            // Amount
            Container(
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FF),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  Text('Monto del Abono', style: _grey.copyWith(fontSize: 12)),
                  const SizedBox(height: 12),
                  Text(
                    currencyFormat.format(amount),
                    style: _bold.copyWith(
                      fontSize: 42,
                      color: const Color(0xFF059669),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // Client info
            _buildInfoSection('DATOS DEL CLIENTE', [
              _buildRow('Nombre', customerName),
              _buildRow('Cédula / ID', cedula),
              if (issuerName != null && issuerName!.isNotEmpty)
                _buildRow('Emitido por', issuerName!),
            ]),
            const SizedBox(height: 24),
            _buildInfoSection('DETALLES DEL PRÉSTAMO', [
              _buildRow('Concepto', loanTitle),
              _buildRow(
                  'Referencia',
                  reference
                      .substring(0, math.min(reference.length, 8))
                      .toUpperCase()),
              _buildRow('Fecha', date),
            ]),

            const SizedBox(height: 32),
            Container(
                height: 1,
                color: Colors.grey[100],
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 10)),
            const SizedBox(height: 24),

            // Balance
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: remainingBalance <= 0
                    ? const Color(0xFF10B981).withAlpha(13)
                    : const Color(0xFF1E293B).withAlpha(5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: (remainingBalance <= 0
                            ? const Color(0xFF10B981)
                            : Colors.grey[300]!)
                        .withAlpha(51)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        remainingBalance <= 0 ? 'ESTADO' : 'SALDO PENDIENTE',
                        style: _bold.copyWith(fontSize: 10, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        remainingBalance <= 0
                            ? 'LIQUIDADO'
                            : currencyFormat.format(remainingBalance),
                        style: _bold.copyWith(
                          fontSize: 20,
                          color: remainingBalance <= 0
                              ? const Color(0xFF10B981)
                              : const Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                  if (remainingBalance <= 0)
                    const Icon(Icons.check_circle_rounded,
                        color: Color(0xFF10B981), size: 32),
                ],
              ),
            ),

            const SizedBox(height: 48),

            // Footer
            Text('¡Gracias por su confianza!',
                style: _bold.copyWith(
                    color: const Color(0xFF7C3AED), fontSize: 14)),
            const SizedBox(height: 12),
            Text(
              issuerName != null && issuerName!.isNotEmpty
                  ? 'Documento generado por $issuerName'
                  : 'Comprobante automático de Contador Engine',
              style: _grey.copyWith(fontSize: 9, color: Colors.grey[400]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: _bold.copyWith(
                fontSize: 10, color: Colors.grey[400], letterSpacing: 1)),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: _grey.copyWith(fontSize: 13)),
          Text(value, style: _bold.copyWith(fontSize: 13)),
        ],
      ),
    );
  }
}
