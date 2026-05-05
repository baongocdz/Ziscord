import 'package:flutter/material.dart';
import '../../data/models/channel.dart';
import '../../data/services/server_service.dart';

class ChannelSidebar extends StatelessWidget {
  final String? serverId;
  final String? selectedChannelId;
  final Function(String id, String name) onChannelSelected;

  ChannelSidebar({
    super.key,
    required this.serverId,
    required this.selectedChannelId,
    required this.onChannelSelected,
  });

  final serverService = ServerService();
  Future<String?>? roleFuture;
  
  void _showCreateChannelDialog(BuildContext context) {
    if (serverId == null) return;

    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Tạo kênh văn bản'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Tên kênh...',
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

                await serverService.createChannel(
                  serverId: serverId!,
                  name: controller.text.trim(),
                  type: 'text',
                );

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
    if (serverId == null) {
      return Container(
        width: 240,
        color: const Color(0xFF2F3136),
        child: const Center(
          child: Text(
            'Chưa chọn server',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      );
    }

    roleFuture ??= serverService.getUserRole(serverId!);

    return Container(
      width: 240,
      color: const Color(0xFF2F3136),
      child: StreamBuilder<List<ServerChannel>>(
        stream: serverService.getChannels(serverId!),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final channels = snapshot.data!;

          final textChannels =
              channels.where((channel) => channel.type == 'text').toList();

          final voiceChannels =
              channels.where((channel) => channel.type == 'voice').toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Channels',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),

              const Divider(color: Colors.white24),

              FutureBuilder<String?>(
                future: roleFuture,
                builder: (context, snapshot) {
                  final isOwner = snapshot.data == 'owner';

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'TEXT CHANNELS',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        if (isOwner)
                          InkWell(
                            onTap: () => _showCreateChannelDialog(context),
                            child: const Icon(
                              Icons.add,
                              size: 18,
                              color: Colors.white54,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),

              ...textChannels.map((channel) {
                return ChannelTile(
                  name: channel.name,
                  selected: selectedChannelId == channel.id,
                  onTap: () => onChannelSelected(channel.id, channel.name),
                );
              }),

              const SizedBox(height: 16),

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text(
                  'VOICE CHANNELS',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ),

              ...voiceChannels.map((channel) {
                return ChannelTile(
                  name: channel.name,
                  isVoice: true,
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

class ChannelTile extends StatelessWidget {
  final String name;
  final bool isVoice;
  final bool selected;
  final VoidCallback? onTap;

  const ChannelTile({
    super.key,
    required this.name,
    this.isVoice = false,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isVoice ? null : onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF40444B) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(
              isVoice ? Icons.volume_up : Icons.tag,
              size: 18,
              color: selected ? Colors.white : Colors.white70,
            ),
            const SizedBox(width: 8),
            Text(
              name,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white70,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}