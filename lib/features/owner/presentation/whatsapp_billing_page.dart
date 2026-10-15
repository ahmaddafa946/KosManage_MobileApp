import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../domain/models/owner_management.dart';
import '../../../domain/services/owner_display.dart';
import '../application/owner_module_providers.dart';

class WhatsappBillingPage extends ConsumerStatefulWidget {
  const WhatsappBillingPage({super.key});

  @override
  ConsumerState<WhatsappBillingPage> createState() => _WhatsappBillingPageState();
}

class _WhatsappBillingPageState extends ConsumerState<WhatsappBillingPage> {
  bool _loading = false;
  String? _error;
  String? _success;

  Future<void> _approve(OwnerPayment payment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Setujui penagihan WhatsApp?'),
        content: Text(
          'Pesan penagihan untuk ${payment.tenantName ?? 'penyewa'} '
          'sebesar ${formatRupiah(payment.remaining)} akan dikirim melalui '
          'template WhatsApp yang telah disetujui Meta. Pastikan penyewa '
          'sudah memberikan persetujuan WhatsApp.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Setujui & kirim'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'whatsapp-billing',
        body: {'action': 'approve-invoice', 'invoice_id': payment.id},
      );
      if (!mounted) return;
      final responseData = response.data;
      if (responseData is Map && responseData['status'] == 'uncertain') {
        setState(() {
          _error = responseData['message'] is String
              ? responseData['message'] as String
              : 'Status pengiriman belum dapat dipastikan. Periksa riwayat Meta sebelum mencoba lagi.';
        });
        return;
      }
      setState(() {
        _success = 'API WhatsApp menerima permintaan pesan untuk tagihan '
            '${payment.invoiceNumber ?? payment.billingPeriod}. '
            'Penerimaan API tidak selalu berarti pesan sudah terkirim ke penyewa.';
      });
    } on FunctionException catch (error) {
      if (!mounted) return;
      final details = error.details;
      setState(() {
        _error = details is Map && details['message'] is String
            ? details['message'] as String
            : 'Pengiriman gagal. Periksa persetujuan penyewa, template Meta, '
                'dan konfigurasi Supabase.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Tidak dapat memproses penagihan. Periksa koneksi dan '
            'konfigurasi WhatsApp.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final propertyAsync = ref.watch(ownerPropertyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Penagihan WhatsApp'),
      ),
      body: propertyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Data properti tidak dapat dimuat. Silakan coba lagi.'),
          ),
        ),
        data: (property) => FutureBuilder<List<OwnerPayment>>(
          future: ref.read(ownerPaymentsRepositoryProvider).getPayments(
                property.id,
                status: 'all',
              ),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Tagihan gagal dimuat. Pastikan koneksi dan database '
                    'KosManage tersedia.\n${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            final payments = (snapshot.data ?? const <OwnerPayment>[])
                .where((p) =>
                    p.remaining > 0 &&
                    !const ['paid', 'cancelled', 'expired'].contains(p.status))
                .toList(growable: false);

            return RefreshIndicator(
              onRefresh: () async => setState(() {}),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.mark_chat_unread_outlined,
                                  color: scheme.primary, size: 28),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Persetujuan sebelum penagihan',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Pesan pertama hanya dikirim setelah owner '
                            'menyetujui. Penyewa juga harus menyetujui '
                            'pengingat WhatsApp. Pengingat berikutnya '
                            'dijadwalkan oleh backend.',
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Fitur memerlukan migration Supabase, token '
                            'Meta, dan template utility yang disetujui.',
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_error != null)
                    _MessageBanner(
                      message: _error!,
                      color: scheme.errorContainer,
                      foreground: scheme.onErrorContainer,
                      icon: Icons.error_outline,
                    ),
                  if (_success != null)
                    _MessageBanner(
                      message: _success!,
                      color: scheme.primaryContainer,
                      foreground: scheme.onPrimaryContainer,
                      icon: Icons.check_circle_outline,
                    ),
                  const SizedBox(height: 8),
                  Text(
                    'Tagihan belum lunas (${payments.length})',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  if (payments.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('Tidak ada tagihan yang perlu ditagih.'),
                      ),
                    ),
                  for (final payment in payments)
                    Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    payment.tenantName ?? 'Penyewa',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                Chip(
                                  label: Text(payment.status),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ],
                            ),
                            Text(
                              'Kamar ${payment.roomNumber ?? '-'} · '
                              '${payment.invoiceNumber ?? payment.billingPeriod}',
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Sisa tagihan: ${formatRupiah(payment.remaining)}',
                              style: TextStyle(
                                color: scheme.primary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'Jatuh tempo: ${formatDateId(payment.dueDate)}',
                              style: TextStyle(
                                color: scheme.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: _loading
                                    ? null
                                    : () => _approve(payment),
                                icon: const Icon(Icons.send_outlined),
                                label: const Text('Setujui penagihan pertama'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MessageBanner extends StatelessWidget {
  const _MessageBanner({
    required this.message,
    required this.color,
    required this.foreground,
    required this.icon,
  });

  final String message;
  final Color color;
  final Color foreground;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: foreground),
            const SizedBox(width: 8),
            Expanded(
              child: Text(message, style: TextStyle(color: foreground)),
            ),
          ],
        ),
      );
}
