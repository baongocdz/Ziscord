import 'package:flutter/material.dart';
import 'server_bubble.dart';
import '../../data/services/server_service.dart';

class ServerSidebar extends StatefulWidget {
  final String? selectedServerId;
  final Function(String serverId) onServerSelected;

  const ServerSidebar({
    super.key,
    required this.selectedServerId,
    required this.onServerSelected,
  });

  @override
  State<ServerSidebar> createState() => _ServerSidebarState();
}

class _ServerSidebarState extends State<ServerSidebar> {
  final serverService = ServerService();

  void _showCreateServerDialog(BuildContext context) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Tạo Server'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Tên server...',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Huỷ'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (controller.text.trim().isEmpty) return;

                await serverService.createServer(controller.text.trim());

                if (!context.mounted) return;
                Navigator.pop(context);
              },
              child: const Text('Tạo'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      color: const Color(0xFF202225),
      child: StreamBuilder(
        stream: serverService.getMyServers(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final servers = snapshot.data!;

          return Column(
            children: [
              const SizedBox(height: 24),
              const ServerBubble(
                icon: Icons.chat_bubble,
                selected: true,
              ),
              const Divider(
                color: Colors.white24,
                indent: 16,
                endIndent: 16,
              ),
              ...servers.map((server) {
                return ServerBubble(
                  text: server.name.substring(0, 1).toUpperCase(),
                  selected: widget.selectedServerId == server.id,
                  onTap: () => widget.onServerSelected(server.id),
                );
              }).toList(),
              const SizedBox(height: 8),
              ServerBubble(
                icon: Icons.add,
                onTap: () => _showCreateServerDialog(context),
              ),
            ],
          );
        },
      ),
    );
  }
}