import 'package:flutter/material.dart';
import 'server_sidebar.dart';
import '../servers/channel_sidebar.dart';
import '../chat/chat_room_page.dart';
import '../../data/services/auth_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? selectedServerId;
  String? selectedChannelId;
  String? selectedChannelName;

  final auth = AuthService();

  void selectServer(String serverId) {
    setState(() {
      selectedServerId = serverId;

      // Khi đổi server, chưa chọn channel nào cả.
      selectedChannelId = null;
      selectedChannelName = null;
    });
  }

  void selectChannel(String id, String name) {
    setState(() {
      selectedChannelId = id;
      selectedChannelName = name;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasSelectedServer = selectedServerId != null;
    final hasSelectedChannel = selectedChannelId != null;

    return Scaffold(
      body: Row(
        children: [
          ServerSidebar(
            selectedServerId: selectedServerId,
            onServerSelected: selectServer,
          ),

          ChannelSidebar(
            serverId: selectedServerId,
            selectedChannelId: selectedChannelId,
            onChannelSelected: selectChannel,
          ),

          Expanded(
            child: Stack(
              children: [
                if (!hasSelectedServer)
                  const Center(
                    child: Text(
                      'Chọn một server để bắt đầu',
                      style: TextStyle(fontSize: 18),
                    ),
                  )
                else if (!hasSelectedChannel)
                  const Center(
                    child: Text(
                      'Chọn một kênh để bắt đầu chat',
                      style: TextStyle(fontSize: 18),
                    ),
                  )
                else
                  ChatRoomPage(
                    serverId: selectedServerId!,
                    channelId: selectedChannelId!,
                    channelName: selectedChannelName ?? 'channel',
                  ),

                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    icon: const Icon(Icons.logout),
                    onPressed: () => auth.logout(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}