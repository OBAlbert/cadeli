class ChatMessage {
  final String id;
  final String senderId;
  final String text;
  final DateTime createdAt;
  final String type;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.createdAt,
    required this.type,
  });

  factory ChatMessage.fromMap(String id, Map<String, dynamic> m) {
    return ChatMessage(
      id: id,
      senderId: m['senderId'] ?? '',
      text: m['text'] ?? '',
      createdAt: (m['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
      type: m['type'] ?? 'text',
    );
  }

  Map<String, dynamic> toMap() => {
    'senderId': senderId,
    'text': text,
    'createdAt': createdAt,
    'type': type,
  };
}
