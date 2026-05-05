import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/models/dm_message.dart';
import '../../data/services/dm_service.dart';

class DMChatPage extends StatefulWidget {
  final String otherUid;
  final String otherEmail;

  const DMChatPage({
    super.key,
    required this.otherUid,
    required this.otherEmail,
  });

  @override
  State<DMChatPage> createState() => _DMChatPageState();
}

class _DMChatPageState extends State<DMChatPage> {
  final DMService dmService = DMService();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  void sendMessage() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || _controller.text.trim().isEmpty) return;

    await dmService.sendMessage(
      currentUser.uid,
      widget.otherUid,
      DMMessage(
        senderId: currentUser.uid,
        senderEmail: currentUser.email ?? 'User',
        content: _controller.text.trim(),
        time: DateTime.now(),
      ),
    );

    _controller.clear();

    // scroll xuống cuối
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!_scrollController.hasClients) return;

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const SizedBox();

    return Scaffold(
      appBar: AppBar(title: Text(widget.otherEmail)),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<DMMessage>>(
              stream: dmService.getMessages(currentUser.uid, widget.otherUid),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                final messages = snapshot.data!;

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg.senderId == currentUser.uid;

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isMe ? const Color(0xFF5865F2) : const Color(0xFF40444B),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment:
                              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            if (!isMe)
                              Text(msg.senderEmail,
                                  style: const TextStyle(fontSize: 12, color: Colors.white70)),
                            Text(msg.content, style: const TextStyle(color: Colors.white)),
                            const SizedBox(height: 4),
                            Text("${msg.time.hour}:${msg.time.minute.toString().padLeft(2, '0')}",
                                style: const TextStyle(fontSize: 10, color: Colors.white54)),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            color: const Color(0xFF313338),
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => sendMessage(),
                    decoration: const InputDecoration(
                      hintText: 'Nhập tin nhắn...',
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(icon: const Icon(Icons.send, color: Colors.white), onPressed: sendMessage),
              ],
            ),
          ),
        ],
      ),
    );
  }
}