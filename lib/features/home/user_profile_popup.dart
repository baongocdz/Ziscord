import 'package:flutter/material.dart';
import '../../data/models/app_user.dart';

class UserProfilePopup extends StatelessWidget {
  final AppUser user;
  final bool fullScreen;

  const UserProfilePopup({
    super.key,
    required this.user,
    this.fullScreen = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 40,
            child: Text(user.email[0].toUpperCase()),
          ),
          const SizedBox(height: 12),
          Text(user.realName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(user.nickname, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 4),
          Text('Joined: ${user.joinedAt.toLocal().toString().split(' ')[0]}',
              style: const TextStyle(color: Colors.white54)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(onPressed: () {}, child: const Text('Add Friend')),
              ElevatedButton(onPressed: () {}, child: const Text('Message')),
            ],
          )
        ],
      ),
    );

    if (fullScreen) {
      return Scaffold(
        backgroundColor: const Color(0xFF2F3136),
        appBar: AppBar(title: Text(user.nickname.isNotEmpty ? user.nickname : user.realName)),
        body: Center(child: content),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF2F3136),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: content,
    );
  }
}