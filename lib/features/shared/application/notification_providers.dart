import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/repositories/notification_repository.dart';
import '../../../domain/models/payment_notification.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return SupabaseNotificationRepository(Supabase.instance.client);
});

final notificationsProvider = FutureProvider.autoDispose<List<PaymentNotification>>((ref) async {
  return ref.read(notificationRepositoryProvider).getMyNotifications();
});

final unreadNotificationCountProvider = StreamProvider<int>((ref) {
  final client = Supabase.instance.client;
  final uid = client.auth.currentUser?.id;
  if (uid == null) return Stream.value(0);

  ref.read(notificationRepositoryProvider).getUnreadCount().then((value) {
    // Intentionally empty for initialization
  });

  return client
      .from('notifications')
      .stream(primaryKey: ['id'])
      .eq('profile_id', uid)
      .map((events) {
        return events.where((e) => e['is_read'] == false).length;
      });
});
