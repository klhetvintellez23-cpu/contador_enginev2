/// Conteo de cuántos registros de un archivo de respaldo son nuevos (se
/// importarán) vs duplicados (ya existen localmente por id y se omiten),
/// mostrado antes de confirmar una importación.
class BackupPreview {
  final int newCustomers;
  final int newLoans;
  final int newPayments;
  final int newCapitalEntries;
  final int duplicateCustomers;
  final int duplicateLoans;
  final int duplicatePayments;
  final int duplicateCapitalEntries;

  const BackupPreview({
    required this.newCustomers,
    required this.newLoans,
    required this.newPayments,
    required this.newCapitalEntries,
    required this.duplicateCustomers,
    required this.duplicateLoans,
    required this.duplicatePayments,
    required this.duplicateCapitalEntries,
  });

  int get totalNew => newCustomers + newLoans + newPayments + newCapitalEntries;
  int get totalDuplicates =>
      duplicateCustomers +
      duplicateLoans +
      duplicatePayments +
      duplicateCapitalEntries;
}
