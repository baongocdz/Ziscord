import 'package:flutter/material.dart';
import 'server_bubble.dart';
import '../../data/services/server_service.dart';
import '../../features/direct_messages/dm_chat_page.dart';

class ServerSidebar extends StatefulWidget {
  final String? selectedServerId;
  final Function(String serverId) onServerSelected;
  final VoidCallback? onDMBubbleTapped;

  const ServerSidebar({
    super.key,
    required this.selectedServerId,
    required this.onServerSelected,
    this.onDMBubbleTapped,
  });

  @override
  State<ServerSidebar> createState() => _ServerSidebarState();
}

class _ServerSidebarState extends State<ServerSidebar> {
  final serverService = ServerService();

  bool isDMSelected = false; // toggle DM list
  List<Map<String, String>> dmUsers = []; // list user từng chat [{'uid':'...','email':'...'}]
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadDMUsers();
  }

  void _loadDMUsers() {
    // Tạm thời hardcode user history để test
    dmUsers = [
      {'uid': 'uid2', 'email': 'user2@example.com'},
      {'uid': 'uid3', 'email': 'user3@example.com'},
    ];
  }

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
              // Sidebar scrollable full height
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(top: 24),
                  children: [
                    // DM bubble đầu tiên
                    ServerBubble(
                      icon: Icons.chat_bubble,
                      selected: false,
                      onTap: widget.onDMBubbleTapped,
                    ),

                    const Divider(
                      color: Colors.white24,
                      indent: 16,
                      endIndent: 16,
                    ),

                    // DM list hoặc server list
                    if (isDMSelected)
                      ..._buildDMList()
                    else
                      ..._buildServerList(servers),

                    const SizedBox(height: 8),

                    // Create server bubble
                    ServerBubble(
                      icon: Icons.add,
                      onTap: () => _showCreateServerDialog(context),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Build list DM + header
  List<Widget> _buildDMList() {
    final filteredUsers = dmUsers
        .where((u) => u['email']!.toLowerCase().contains(searchQuery.toLowerCase()))
        .toList();

    final header = Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.person_add, color: Colors.white),
            onPressed: () {
              // TODO: add friend dialog
            },
          ),
          Expanded(
            child: TextField(
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Tìm kiếm',
                hintStyle: TextStyle(color: Colors.white54),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
              },
            ),
          ),
          const Icon(Icons.search, color: Colors.white54),
        ],
      ),
    );

    final dmList = filteredUsers
        .map((u) => ServerBubble(
              text: u['email']![0].toUpperCase(),
              selected: false,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DMChatPage(
                      otherUid: u['uid']!,
                      otherEmail: u['email']!,
                    ),
                  ),
                );
              },
            ))
        .toList();

    return [header, const Divider(color: Colors.white24), ...dmList];
  }

  // Build list server bubbles
  List<Widget> _buildServerList(List servers) {
    return servers
        .map((server) => ServerBubble(
              text: server.name.substring(0, 1).toUpperCase(),
              selected: widget.selectedServerId == server.id,
              onTap: () => widget.onServerSelected(server.id),
            ))
        .toList();
  }
}