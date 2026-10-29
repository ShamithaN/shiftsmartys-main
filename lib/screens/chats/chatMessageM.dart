class ChatMessage {
  final int messageId;
  final String message;
  final int senderId;
  final int receiverId;
  final DateTime sentAt;
  final DateTime createdAt;

  ChatMessage({
    required this.messageId,
    required this.message,
    required this.senderId,
    required this.receiverId,
    required this.sentAt,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      messageId: json['MessageId'],
      message: json['Message'],
      senderId: json['SenderId'],
      receiverId: json['ReceiverId'],
      sentAt: DateTime.parse(json['SentAt']),
      createdAt: DateTime.parse(json['CreatedAt']),
    );
  }
}
