import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dm_chat_page.dart';

class DMListPage extends StatelessWidget {
  DMListPage({super.key});

  final users = [
    {'uid': 'uid2', 'email': 'user2@example.com'},
    {'uid': 'uid3', 'email': 'user3@example.com'},
  ];

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const SizedBox();

    return Scaffold(
      appBar: AppBar(title: const Text('Direct Messages')),
      body: ListView.builder(
        itemCount: users.length,
        itemBuilder: (context, index) {
          final user = users[index];

          return ListTile(
            title: Text(user['email']!),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DMChatPage(
                    otherUid: user['uid']!,
                    otherEmail: user['email']!,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}