import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat_models.dart';
import '../config/supabase_config.dart';

class ChatService {
  // Singleton pattern for shared state
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  final _client = SupabaseConfig.client;

  // Cache for user profiles to avoid repeated queries
  final Map<String, Map<String, dynamic>> _userProfilesCache = {};

  Future<Map<String, dynamic>?> _getUserProfile(String userId) async {
    if (_userProfilesCache.containsKey(userId)) {
      return _userProfilesCache[userId];
    }
    try {
      final res = await _client
          .from('profiles')
          .select('first_name, last_name, avatar_url')
          .eq('id', userId)
          .maybeSingle();
      if (res != null) {
        _userProfilesCache[userId] = res;
      }
      return res;
    } catch (e) {
      return null;
    }
  }

  /// Stream all available chat threads
  Stream<List<ChatThread>> chatThreads() async* {
    final userId = SupabaseConfig.userId;
    if (userId == null) {
      yield [];
      return;
    }

    final stream = _client
        .from('chat_threads')
        .stream(primaryKey: ['id'])
        .order('last_time', ascending: false);

    await for (final data in stream) {
      // Filter for the current user
      final myThreads = data.where((t) => t['participant1_id'] == userId || t['participant2_id'] == userId).toList();
      
      List<ChatThread> parsedThreads = [];
      for (final t in myThreads) {
        final otherId = t['participant1_id'] == userId ? t['participant2_id'] : t['participant1_id'];
        final otherProfile = await _getUserProfile(otherId);
        parsedThreads.add(ChatThread.fromJson(t, userId, otherProfile));
      }
      
      parsedThreads.sort((a, b) => b.lastTime.compareTo(a.lastTime));
      yield parsedThreads;
    }
  }

  /// Get real-time messages for a specific thread
  Stream<List<ChatMessage>> messages(String threadId) {
    return _client
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .eq('thread_id', threadId)
        .order('created_at', ascending: true)
        .map((data) => data.map((j) => ChatMessage.fromJson(j)).toList());
  }

  /// Send a new message
  Future<void> sendMessage(String threadId, String text, {String? userName}) async {
    final userId = SupabaseConfig.userId;
    if (userId == null) return;

    try {
      // Check if thread exists, if not, create it
      final threadCheck = await _client.from('chat_threads').select('id').eq('id', threadId).maybeSingle();
      if (threadCheck == null) {
        // Assuming threadId is formatted as "rideId_passengerId"
        final parts = threadId.split('_');
        if (parts.length >= 2) {
          final rideId = parts[0];
          final passengerId = parts[1];
          
          // Find driver id from ride
          final rideRes = await _client.from('rides').select('driver_id').eq('id', rideId).maybeSingle();
          if (rideRes != null) {
            final driverId = rideRes['driver_id'];
            await _client.from('chat_threads').insert({
              'id': threadId,
              'ride_id': rideId,
              'participant1_id': driverId,
              'participant2_id': passengerId,
              'last_message': 'Chat started',
              'last_time': DateTime.now().toIso8601String(),
            });
          } else {
            print("ChatService Error: Could not find ride $rideId to create thread.");
            return;
          }
        } else {
            print("ChatService Error: Invalid threadId format $threadId");
            return;
        }
      }

      await _client.from('chat_messages').insert({
        'thread_id': threadId,
        'sender_id': userId,
        'text': text,
        'is_system_message': false,
      });
    } catch (e) {
      print("ChatService Error in sendMessage: $e");
    }
  }

  /// Send a new system message
  Future<void> sendSystemMessage(String threadId, String text, {String? userName}) async {
    try {
      var threadCheck = await _client.from('chat_threads').select('id').eq('id', threadId).maybeSingle();
      if (threadCheck == null) {
        final parts = threadId.split('_');
        if (parts.length >= 2) {
          final rideId = parts[0];
          final passengerId = parts[1];
          final rideRes = await _client.from('rides').select('driver_id').eq('id', rideId).maybeSingle();
          if (rideRes != null) {
            final driverId = rideRes['driver_id'];
            await _client.from('chat_threads').insert({
              'id': threadId,
              'ride_id': rideId,
              'participant1_id': driverId,
              'participant2_id': passengerId,
              'last_message': text,
              'last_time': DateTime.now().toIso8601String(),
            });
            threadCheck = {'id': threadId}; // Mark as created
          }
        }
      }

      if (threadCheck != null) {
        await _client.from('chat_messages').insert({
          'thread_id': threadId,
          'sender_id': SupabaseConfig.userId,
          'text': text,
          'is_system_message': true,
        });
        
        // Also update the thread's last message to show the system message
        await _client.from('chat_threads').update({
          'last_message': text,
          'last_time': DateTime.now().toIso8601String(),
        }).eq('id', threadId);
      }
    } catch (e) {
      print("ChatService Error in sendSystemMessage: $e");
    }
  }

  static final Map<String, StreamController<String?>> _typingControllers = {};

  /// Get typing status for a thread
  Stream<String?> typingStatus(String threadId) {
    if (!_typingControllers.containsKey(threadId)) {
      _typingControllers[threadId] = StreamController<String?>.broadcast();
    }
    return _typingControllers[threadId]!.stream;
  }

  /// Update typing status (mock implementation using local controllers)
  void setTyping(String threadId, String? userName) {
    if (_typingControllers.containsKey(threadId)) {
      _typingControllers[threadId]!.add(userName);
    }
  }

  /// Mark all messages in a thread as seen
  Future<void> markSeen(String threadId) async {
    final userId = SupabaseConfig.userId;
    if (userId == null) return;

    final thread = await _client.from('chat_threads').select('participant1_id, participant2_id').eq('id', threadId).maybeSingle();
    if (thread != null) {
      if (thread['participant1_id'] == userId) {
        await _client.from('chat_threads').update({'unread_p1': 0}).eq('id', threadId);
      } else if (thread['participant2_id'] == userId) {
        await _client.from('chat_threads').update({'unread_p2': 0}).eq('id', threadId);
      }
    }
  }
}
