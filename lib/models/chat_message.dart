enum MessageSender { system, user }

class ChatMessage {
  const ChatMessage({required this.text, required this.sender});

  final String text;
  final MessageSender sender;

  Map<String, dynamic> toJson() => {
        'text': text,
        'sender': sender.name,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      text: json['text'] as String,
      sender: MessageSender.values.firstWhere(
        (e) => e.name == json['sender'],
        orElse: () => MessageSender.system,
      ),
    );
  }
}
