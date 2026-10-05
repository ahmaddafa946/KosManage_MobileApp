import 'package:flutter/material.dart';

/// Shared modern mobile primitives. One place, reused everywhere.
/// ponytail: no custom chart lib; add fl_chart only when Laporan needs real graphs.
class AppStatusChip extends StatelessWidget {
  const AppStatusChip({super.key, required this.label, required this.tone});

  final String label;
  final AppTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = tone.colors(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}

enum AppTone { success, warning, danger, info, neutral }

extension on AppTone {
  (Color, Color) colors(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    switch (this) {
      case AppTone.success:
        return (
          const Color(0xFF10B981).withValues(alpha: 0.15),
          const Color(0xFF047857)
        );
      case AppTone.warning:
        return (Colors.amber.shade100, Colors.amber.shade900);
      case AppTone.danger:
        return (scheme.errorContainer.withValues(alpha: 0.7), scheme.onErrorContainer);
      case AppTone.info:
        return (Colors.blue.shade100, Colors.blue.shade800);
      case AppTone.neutral:
        return (scheme.surfaceContainerHighest, scheme.onSurfaceVariant);
    }
  }
}

AppTone roomTone(String status) => switch (status) {
      'available' => AppTone.success,
      'occupied' => AppTone.info,
      'maintenance' => AppTone.warning,
      _ => AppTone.neutral,
    };

AppTone tenantTone(String status) =>
    status == 'active' ? AppTone.success : AppTone.neutral;

AppTone paymentTone(String status) => switch (status) {
      'paid' => AppTone.success,
      'partial' => AppTone.info,
      'unpaid' => AppTone.warning,
      'overdue' => AppTone.danger,
      _ => AppTone.neutral,
    };

AppTone maintenanceTone(String status) => switch (status) {
      'resolved' => AppTone.success,
      'in_progress' => AppTone.info,
      'submitted' => AppTone.warning,
      'closed' => AppTone.neutral,
      _ => AppTone.neutral,
    };

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: scheme.primary),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
            if (action != null) ...[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class AppErrorState extends StatelessWidget {
  const AppErrorState({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined,
                size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            const Text('Data belum dapat dimuat.',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 6),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Coba lagi'),
            ),
          ],
        ),
      ),
    );
  }
}

class AppSectionCard extends StatelessWidget {
  const AppSectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.onViewAll,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                ),
                if (onViewAll != null)
                  InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: onViewAll,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 4),
                      child: Text('Semua',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: scheme.primary)),
                    ),
                  ),
              ],
            ),
            const Divider(height: 20),
            child,
          ],
        ),
      ),
    );
  }
}

class AppSearchField extends StatelessWidget {
  const AppSearchField(
      {super.key, required this.hint, required this.onChanged});

  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      textInputAction: TextInputAction.search,
      onChanged: onChanged,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search, size: 20),
        hintText: hint,
      ),
    );
  }
}
