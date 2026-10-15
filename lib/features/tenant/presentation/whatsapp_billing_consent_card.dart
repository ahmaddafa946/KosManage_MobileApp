import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WhatsappBillingConsentCard extends StatefulWidget {
  const WhatsappBillingConsentCard({super.key});

  @override
  State<WhatsappBillingConsentCard> createState() =>
      _WhatsappBillingConsentCardState();
}

class _WhatsappBillingConsentCardState
    extends State<WhatsappBillingConsentCard> {
  bool? _optedIn;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadConsent();
  }

  Future<void> _loadConsent() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Silakan masuk kembali untuk mengatur persetujuan.';
        });
      }
      return;
    }
    try {
      final row = await Supabase.instance.client
          .from('tenants')
          .select('whatsapp_billing_opt_in')
          .eq('profile_id', user.id)
          .maybeSingle();
      if (!mounted) return;
      setState(() {
        _optedIn = row?['whatsapp_billing_opt_in'] == true;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Pengaturan WhatsApp belum tersedia. Coba lagi setelah '
            'pembaruan backend diterapkan.';
      });
    }
  }

  Future<void> _setConsent(bool value) async {
    if (value) {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Persetujuan pengingat WhatsApp'),
          content: const Text(
            'Saya setuju menerima pengingat tagihan sewa melalui WhatsApp '
            'dari KosManage/pemilik kos. Persetujuan dapat dicabut kapan saja '
            'melalui pengaturan ini.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Belum'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Saya setuju'),
            ),
          ],
        ),
      );
      if (accepted != true || !mounted) return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.functions.invoke(
        'whatsapp-billing-consent',
        body: {'opt_in': value},
      );
      if (!mounted) return;
      setState(() {
        _optedIn = value;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value
              ? 'Persetujuan pengingat WhatsApp disimpan.'
              : 'Persetujuan pengingat WhatsApp dicabut.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Persetujuan belum tersimpan. Periksa koneksi atau coba lagi '
            'setelah backend diperbarui.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.mark_chat_unread_outlined, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Pengingat tagihan WhatsApp',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Izinkan pemilik kos mengirim pengingat tagihan sewa melalui '
              'WhatsApp. Ini tidak mengubah status pembayaran dan persetujuan '
              'dapat dicabut kapan saja.',
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurfaceVariant,
              ),
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_optedIn != null)
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(_optedIn! ? 'Persetujuan aktif' : 'Belum menyetujui'),
                subtitle: Text(_optedIn!
                    ? 'Pengingat dapat dikirim sesuai jadwal.'
                    : 'Tidak ada pengingat otomatis sampai Anda setuju.'),
                value: _optedIn!,
                onChanged: _saving ? null : _setConsent,
              ),
            if (_saving) const LinearProgressIndicator(),
            if (_error != null) ...[
              const SizedBox(height: 6),
              Text(
                _error!,
                style: TextStyle(color: scheme.error, fontSize: 12),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _loading ? null : _loadConsent,
                  child: const Text('Coba lagi'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
