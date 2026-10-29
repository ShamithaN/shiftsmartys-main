class NotificationItem {
  final int id;
  final String type;
  final String subject;
  final String message;
  final String status;
  final DateTime createdAt;
  final int recipientId;

  NotificationItem({
    required this.id,
    required this.type,
    required this.subject,
    required this.message,
    required this.status,
    required this.createdAt,
    required this.recipientId,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['Id'] is int ? json['Id'] : int.parse(json['Id'].toString()),
      type: json['Type'] ?? '',
      subject: json['Subject'] ?? '',
      message: json['Message'] ?? '',
      status: json['Status'] ?? '',
      createdAt: DateTime.parse(json['CreatedAt']),
      recipientId: json['RecipientId'] is int ? json['RecipientId'] : int.parse(json['RecipientId'].toString()),
    );
  }
}