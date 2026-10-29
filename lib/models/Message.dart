class Message {
  final int messageId;
  final int senderId;
  final int receiverId;
  final String text;
  final DateTime createdAt;

  Message({
    required this.messageId,
    required this.senderId,
    required this.receiverId,
    required this.text,
    required this.createdAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      // Handle both PascalCase (Server) and camelCase (Local)
      messageId: json['MessageId'] ?? json['messageId'] ?? 0,
      senderId: json['SenderId'] ?? json['senderId'] ?? 0,
      receiverId: json['ReceiverId'] ?? json['receiverId'] ?? 0,
      text: json['Message'] ??
          json['Text'] ??
          json['text'] ??
          '', // Check all possible keys
      createdAt: DateTime.tryParse(
              json['SentAt'] ?? json['CreatedAt'] ?? json['createdAt'] ?? '') ??
          DateTime.now(),
    );
  }
}
