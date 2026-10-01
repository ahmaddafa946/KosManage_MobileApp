import 'package:intl/intl.dart';

String roomStatusLabel(String status) {
  switch (status) {
    case 'available':
      return 'Kosong';
    case 'occupied':
      return 'Terisi';
    case 'maintenance':
      return 'Maintenance';
    default:
      return status.replaceAll('_', ' ');
  }
}

String tenantStatusLabel(String status) {
  switch (status) {
    case 'active':
      return 'Aktif';
    case 'inactive':
      return 'Tidak aktif';
    default:
      return status.replaceAll('_', ' ');
  }
}

String paymentStatusLabel(String status) {
  switch (status) {
    case 'unpaid':
      return 'Belum dibayar';
    case 'partial':
      return 'Sebagian';
    case 'paid':
      return 'Lunas';
    case 'overdue':
      return 'Terlambat';
    default:
      return status.replaceAll('_', ' ');
  }
}

String paymentMethodLabel(String? method) {
  switch (method) {
    case 'cash':
      return 'Cash';
    case 'transfer':
      return 'Transfer';
    case 'ewallet':
      return 'E-Wallet';
    case 'qris':
      return 'QRIS';
    default:
      return '-';
  }
}

String maintenanceStatusLabel(String status) {
  switch (status) {
    case 'submitted':
      return 'Diajukan';
    case 'in_progress':
      return 'Diproses';
    case 'resolved':
      return 'Selesai';
    case 'closed':
      return 'Ditutup';
    default:
      return status.replaceAll('_', ' ');
  }
}

String maintenanceCategoryLabel(String category) {
  const labels = <String, String>{
    'AC': 'AC',
    'electrical': 'Listrik',
    'plumbing': 'Plumbing',
    'furniture': 'Furnitur',
    'internet': 'Internet',
    'other': 'Lainnya',
  };
  return labels[category] ?? category;
}

String maintenancePriorityLabel(String priority) {
  const labels = <String, String>{
    'low': 'Rendah',
    'medium': 'Sedang',
    'high': 'Tinggi',
  };
  return labels[priority] ?? priority;
}

String formatRupiah(num amount) => NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(amount);

String formatDateId(String? value) {
  if (value == null || value.isEmpty) return '-';
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  return DateFormat('dd MMM yyyy', 'id_ID').format(parsed);
}

enum RentalUrgency { normal, attention, soon, verySoon, expired, pastDue }

class RentalCountdown {
  const RentalCountdown({required this.label, required this.urgency});

  final String label;
  final RentalUrgency urgency;
}

RentalCountdown rentalCountdown(String? endDate, {DateTime? today}) {
  if (endDate == null || endDate.isEmpty) {
    return const RentalCountdown(
      label: 'Tanpa tanggal berakhir',
      urgency: RentalUrgency.normal,
    );
  }
  final date = DateTime.tryParse(endDate);
  if (date == null) {
    return const RentalCountdown(
      label: 'Tanggal tidak valid',
      urgency: RentalUrgency.normal,
    );
  }
  final base = today ?? DateTime.now();
  final start = DateTime(base.year, base.month, base.day);
  final end = DateTime(date.year, date.month, date.day);
  final days = end.difference(start).inDays;
  if (days < 0) {
    return RentalCountdown(
      label: 'Lewat ' + days.abs().toString() + ' hari',
      urgency: RentalUrgency.pastDue,
    );
  }
  if (days == 0) {
    return const RentalCountdown(
      label: 'Berakhir hari ini',
      urgency: RentalUrgency.expired,
    );
  }
  if (days <= 6) {
    return RentalCountdown(
      label: 'Sisa ' + days.toString() + ' hari',
      urgency: RentalUrgency.verySoon,
    );
  }
  if (days <= 14) {
    return RentalCountdown(
      label: 'Sisa ' + days.toString() + ' hari',
      urgency: RentalUrgency.soon,
    );
  }
  if (days <= 30) {
    return RentalCountdown(
      label: 'Sisa ' + days.toString() + ' hari',
      urgency: RentalUrgency.attention,
    );
  }
  return RentalCountdown(
    label: 'Sisa ' + days.toString() + ' hari',
    urgency: RentalUrgency.normal,
  );
}
