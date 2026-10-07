import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/payment_notification.dart';

abstract interface class NotificationRepository {
  Future<List<PaymentNotification>> getMyNotifications();
  Future<int> getUnreadCount();
  Future<void> markAsRead(String notificationId);
  Future<void> markAllAsRead();
}

class SupabaseNotificationRepository implements NotificationRepository {
  SupabaseNotificationRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<PaymentNotification>> getMyNotifications() async {
    final rows = await _client
        .from('notifications')
        .select('*')
        .order('created_at', ascending: false)
        .limit(50);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(PaymentNotification.fromJson)
        .toList(growable: false);
  }

  @override
  Future<int> getUnreadCount() async {
    final count = await _client
        .from('notifications')
        .count(CountOption.exact)
        .eq('is_read', false);
    return count;
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('id', notificationId);
  }

  @override
  Future<void> markAllAsRead() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('profile_id', uid)
        .eq('is_read', false);
  }
}
