import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatProvider with ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Map of conversationId -> list of messages
  Map<String, List<Map<String, dynamic>>> _messagesMap = {};

  // Getter for messages
  List<Map<String, dynamic>>? getMessages(String conversationId) {
    return _messagesMap[conversationId];
  }

  // Check if conversation exists, create if not
  Future<void> _ensureConversationExists(
    String conversationId, 
    String senderId, 
    String senderName
  ) async {
    final conversationRef = _db.collection('conversations').doc(conversationId);
    final conversationDoc = await conversationRef.get();

    if (!conversationDoc.exists) {
      print('Creating new conversation: $conversationId');
      
      // Create the conversation document
      await conversationRef.set({
        'id': conversationId,
        'title': 'Tech Mafias Chat',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'participants': [senderId],
        'participantNames': [senderName],
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'unreadCount': {},
      });

      print('Conversation created successfully!');
    }
  }

  // Load messages from Firestore
  Future<void> loadMessages(String conversationId) async {
    try {
      final snapshot = await _db
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .orderBy('time', descending: false)
          .get();

      _messagesMap[conversationId] = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'text': data['text'] ?? '',
          'senderId': data['senderId'] ?? '',
          'senderName': data['senderName'] ?? '',
          'time': (data['time'] as Timestamp).toDate(),
        };
      }).toList();

      notifyListeners();
    } catch (e) {
      print('Error loading messages: $e');
      rethrow;
    }
  }

  // Send a message
  Future<void> sendMessage({
    required String conversationId,
    required String text,
    required String senderId,
    required String senderName,
  }) async {
    try {
      // Ensure conversation exists before sending message
      await _ensureConversationExists(conversationId, senderId, senderName);

      // Generate a unique ID for the message
      final messageId = _db.collection('conversations').doc().id;
      final messageRef = _db
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .doc(messageId);

      final messageData = {
        'id': messageId,
        'text': text,
        'senderId': senderId,
        'senderName': senderName,
        'time': FieldValue.serverTimestamp(),
        'conversationId': conversationId,
      };

      // Add message to Firestore
      await messageRef.set(messageData);

      // Update conversation's last message
      await _db.collection('conversations').doc(conversationId).update({
        'lastMessage': text,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Optimistically update local messages list
      final newMessage = {
        'id': messageId,
        'text': text,
        'senderId': senderId,
        'senderName': senderName,
        'time': DateTime.now(),
      };

      if (_messagesMap[conversationId] == null) {
        _messagesMap[conversationId] = [];
      }

      _messagesMap[conversationId]!.add(newMessage);
      notifyListeners();

      print('Message sent successfully! Conversation: $conversationId');
    } catch (e) {
      print('Error sending message: $e');
      rethrow;
    }
  }

  // Real-time listener for a conversation
  Stream<List<Map<String, dynamic>>> messagesStream(String conversationId) {
    try {
      return _db
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .orderBy('time', descending: false)
          .snapshots()
          .handleError((error) {
            print('Error in messages stream: $error');
          })
          .map((snapshot) => snapshot.docs.map((doc) {
                final data = doc.data();
                return {
                  'id': data['id'] ?? doc.id,
                  'text': data['text'] ?? '',
                  'senderId': data['senderId'] ?? '',
                  'senderName': data['senderName'] ?? '',
                  'time': (data['time'] as Timestamp?)?.toDate() ?? DateTime.now(),
                  'conversationId': data['conversationId'] ?? conversationId,
                };
              }).toList());
    } catch (e) {
      print('Error creating messages stream: $e');
      return Stream.value([]);
    }
  }

  // Get conversation stream
  Stream<DocumentSnapshot> conversationStream(String conversationId) {
    return _db
        .collection('conversations')
        .doc(conversationId)
        .snapshots()
        .handleError((error) {
          print('Error in conversation stream: $error');
        });
  }

  // Check if conversation exists
  Future<bool> conversationExists(String conversationId) async {
    try {
      final doc = await _db
          .collection('conversations')
          .doc(conversationId)
          .get();
      return doc.exists;
    } catch (e) {
      print('Error checking if conversation exists: $e');
      return false;
    }
  }

  // Get all conversations for a user
  Stream<List<Map<String, dynamic>>> getUserConversations(String userId) {
    return _db
        .collection('conversations')
        .where('participants', arrayContains: userId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              return {
                'id': doc.id,
                'title': data['title'] ?? 'Chat',
                'lastMessage': data['lastMessage'] ?? '',
                'lastMessageTime': (data['lastMessageTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
                'participantNames': List<String>.from(data['participantNames'] ?? []),
                'unreadCount': (data['unreadCount'] as Map<String, dynamic>?)?[userId] ?? 0,
              };
            }).toList());
  }

  // Mark messages as read
  Future<void> markAsRead(String conversationId, String userId) async {
    try {
      await _db.collection('conversations').doc(conversationId).update({
        'unreadCount.$userId': 0,
      });
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

  // Get unread count for a conversation
  Future<int> getUnreadCount(String conversationId, String userId) async {
    try {
      final doc = await _db
          .collection('conversations')
          .doc(conversationId)
          .get();
      
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final unreadCount = (data['unreadCount'] as Map<String, dynamic>?)?[userId];
        return (unreadCount as int?) ?? 0;
      }
      return 0;
    } catch (e) {
      print('Error getting unread count: $e');
      return 0;
    }
  }
}