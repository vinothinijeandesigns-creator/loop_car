import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/chat_models.dart';
import '../services/chat_service.dart';
import 'chat_room_screen.dart';

class ChatListScreen extends StatelessWidget {
  final ChatService service = ChatService();

  ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Messages',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      body: StreamBuilder<List<ChatThread>>(
        stream: service.chatThreads(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF00C6D2)),
            );
          }

          final threads = snap.data!;

          if (threads.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 64,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "No conversations yet",
                    style: TextStyle(color: Colors.grey[500], fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: threads.length,
            separatorBuilder:
                (context, index) => Divider(
                  indent: 80,
                  endIndent: 16,
                  color: Colors.grey[200],
                  height: 1,
                ),
            itemBuilder: (_, i) {
              final t = threads[i];
              final timeStr = DateFormat('h:mm a').format(t.lastTime);

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C6D2).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      t.userName[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00C6D2),
                      ),
                    ),
                  ),
                ),
                title: Text(
                  t.userName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    t.lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: t.unread > 0 ? Colors.black87 : Colors.grey[600],
                      fontWeight:
                          t.unread > 0 ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      timeStr,
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            t.unread > 0
                                ? const Color(0xFF00C6D2)
                                : Colors.grey[500],
                        fontWeight:
                            t.unread > 0 ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    if (t.unread > 0)
                      Container(
                        margin: const EdgeInsets.only(top: 6),
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Color(0xFF00C6D2),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          t.unread.toString(),
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                onTap: () {
                  if (t.unread > 0) {
                    service.markSeen(t.threadId);
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatRoomScreen(threadId: t.threadId),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
