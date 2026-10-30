import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/chat_models.dart';
import '../services/chat_service.dart';
import '../config/supabase_config.dart';

class ChatRoomScreen extends StatefulWidget {
  final String threadId;
  final String? userName;
  const ChatRoomScreen({super.key, required this.threadId, this.userName});

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final ChatService service = ChatService();
  final ScrollController scroll = ScrollController();
  
  bool _isLocked = false;
  bool _isLoadingStatus = true;

  @override
  void initState() {
    super.initState();
    _checkBookingStatus();
    // Mark messages as seen when entering the chat
    service.markSeen(widget.threadId);
  }

  @override
  void dispose() {
    // Mark messages as seen when leaving the chat
    service.markSeen(widget.threadId);
    scroll.dispose();
    super.dispose();
  }

  Future<void> _checkBookingStatus() async {
    try {
      final parts = widget.threadId.split('_');
      if (parts.length >= 2) {
        final rideId = parts[0];
        final passengerId = parts[1];
        
        final response = await SupabaseConfig.client
            .from('bookings')
            .select('status')
            .eq('ride_id', rideId)
            .eq('passenger_id', passengerId)
            .maybeSingle();
            
        if (response != null) {
          final status = response['status'];
          if (status == 'cancelled' || status == 'rejected') {
            setState(() {
              _isLocked = true;
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Error checking booking status for chat: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingStatus = false;
        });
      }
    }
  }

  void send(String text) async {
    await service.sendMessage(widget.threadId, text, userName: widget.userName);

    Future.delayed(const Duration(milliseconds: 100), () {
      if (scroll.hasClients) {
        scroll.animateTo(
          scroll.position.maxScrollExtent + 100,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ride Chat'),
        backgroundColor: const Color(0xFF00C6D2),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: const Color(0xFFF7F9FB),
              child: StreamBuilder<List<ChatMessage>>(
                stream: service.messages(widget.threadId),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final msgs = snap.data!;
                  // Ensure they are sorted by time
                  msgs.sort((a, b) => a.time.compareTo(b.time));

                  return ListView.builder(
                    controller: scroll,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 20,
                    ),
                    itemCount: msgs.length,
                    itemBuilder: (_, i) {
                      final m = msgs[i];
                      return MessageBubble(
                        message: m,
                        isMe: m.senderId == SupabaseConfig.userId,
                      );
                    },
                  );
                },
              ),
            ),
          ),
          StreamBuilder<String?>(
            stream: service.typingStatus(widget.threadId),
            builder: (context, snap) {
              if (snap.data != null) {
                return TypingIndicator(name: snap.data!);
              }
              return const SizedBox.shrink();
            },
          ),
          if (_isLoadingStatus)
            const Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator())
          else if (_isLocked)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.grey.shade50, border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.grey),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        "This conversation is no longer available because the booking was cancelled.",
                        style: TextStyle(color: Colors.black87, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            InputBar(onSend: send),
        ],
      ),
    );
  }
}

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;

  const MessageBubble({super.key, required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    if (message.isSystemMessage) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F6FA),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.format_quote, color: Color(0xFF4A4EFE), size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.text,
                    style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.4),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "System Message",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.blue.shade700),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    const primary = Color(0xFF1DA1A8);
    final timeStr = DateFormat('h:mm a').format(message.time);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: isMe ? primary : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 0),
            bottomRight: Radius.circular(isMe ? 0 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message.text,
              style: TextStyle(
                color: isMe ? Colors.white : Colors.black87,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              timeStr,
              style: TextStyle(
                color: isMe ? Colors.white70 : Colors.black38,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class InputBar extends StatefulWidget {
  final Function(String) onSend;
  const InputBar({super.key, required this.onSend});

  @override
  State<InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<InputBar> {
  final controller = TextEditingController();

  void send() {
    if (controller.text.trim().isEmpty) return;
    widget.onSend(controller.text.trim());
    controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 16),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: "Message",
                filled: true,
                fillColor: const Color(0xFFF1F3F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: const Color(0xFF00C6D2),
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white, size: 20),
              onPressed: send,
            ),
          ),
        ],
      ),
    );
  }
}

class TypingIndicator extends StatefulWidget {
  final String name;
  const TypingIndicator({super.key, required this.name});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget dot(int index) {
    return FadeTransition(
      opacity: DelayTween(
        begin: 0.3,
        end: 1,
        delay: index * .2,
      ).animate(_controller),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        width: 6,
        height: 6,
        decoration: const BoxDecoration(
          color: Colors.grey,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 14, bottom: 10),
      child: Row(
        children: [
          Text(
            "${widget.name} typing",
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(width: 6),
          dot(0),
          dot(1),
          dot(2),
        ],
      ),
    );
  }
}

/// delay animation helper
class DelayTween extends Tween<double> {
  final double delay;

  DelayTween({required super.begin, required super.end, required this.delay});

  @override
  double lerp(double t) {
    final delayedT = (t - delay).clamp(0.0, 1.0);
    return super.lerp(delayedT);
  }
}
