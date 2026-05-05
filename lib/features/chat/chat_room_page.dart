import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'message_item.dart';
import 'chat_input.dart';
import '../../data/models/message.dart';
import '../../data/services/firestore_service.dart';

class ChatRoomPage extends StatefulWidget {
  final String serverId;
  final String channelId;
  final String channelName;

  const ChatRoomPage({
    super.key,
    required this.serverId,
    required this.channelId,
    required this.channelName,
  });

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FirestoreService firestore = FirestoreService();

  void sendMessage() async {
    if (_controller.text.trim().isEmpty) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    await firestore.sendMessage(
      widget.serverId,
      widget.channelId,
      Message(
        userId: currentUser.uid,
        user: currentUser.email ?? 'User',
        content: _controller.text.trim(),
        time: DateTime.now(),
      ),
    );

    _controller.clear();

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
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.centerLeft,
          color: const Color(0xFF36393F),
          child: Text(
            '# ${widget.channelName}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),

        Expanded(
          child: StreamBuilder<List<Message>>(
            stream: firestore.getMessages(
              widget.serverId,
              widget.channelId,
            ),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final messages = snapshot.data!;

              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_scrollController.hasClients) {
                  _scrollController.jumpTo(
                    _scrollController.position.maxScrollExtent,
                  );
                }
              });

              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(12),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final current = messages[index];
                  final previous = index > 0 ? messages[index - 1] : null;

                  final showHeader =
                      previous == null || previous.user != current.user;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: MessageItem(
                      message: current,
                      showHeader: showHeader,
                      serverId: widget.serverId,
                    ),
                  );
                },
              );
            },
          ),
        ),

        ChatInput(
          controller: _controller,
          onSend: sendMessage,
        ),
      ],
    );
  }
}