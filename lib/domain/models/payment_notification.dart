class PaymentNotification {
  const PaymentNotification({
    required this.id,
    required this.profileId,
    required this.title,
    required this.message,
    required this.type,
    required this.isRead,
    required this.createdAt,
    this.data,
  });

  final String id;
  final String profileId;
  final String title;
  final String message;
  final String type;
  final bool isRead;
  final String createdAt;
  final Map<String, dynamic>? data;

  factory PaymentNotification.fromJson(Map<String, dynamic> json) {
    return PaymentNotification(
      id: json['id'] as String,
      profileId: json['profile_id'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      type: json['type'] as String,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: json['created_at'] as String,
      data: json['data'] as Map<String, dynamic>?,
    );
  }
}
