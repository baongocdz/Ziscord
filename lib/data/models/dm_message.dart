class DMMessage {
  final String senderId;
  final String senderEmail;
  final String content;
  final DateTime time;

  DMMessage({
    required this.senderId,
    required this.senderEmail,
    required this.content,
    required this.time,
  });
}