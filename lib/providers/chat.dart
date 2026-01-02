import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatProvider with ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // =========================
  // AUTH
  // =========================
  String get _currentUserId {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }
    return user.uid;
  }

  // =========================
  // MESSAGES STREAM
  // =========================
  Stream<List<Map<String, dynamic>>> messagesStream(String conversationId) {
    return _db
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('time', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              return {
                'id': doc.id,
                'text': data['text'] ?? '',
                'senderId': data['senderId'] ?? '',
                'senderName': data['senderName'] ?? '',
                'time': (data['time'] as Timestamp?)?.toDate() ?? DateTime.now(),
              };
            }).toList());
  }

  // =========================
  // SEND MESSAGE
  // =========================
  Future<void> sendMessage({
    required String conversationId,
    required String text,
    required String senderName,
  }) async {
    final senderId = _currentUserId;
    final conversationRef =
        _db.collection('conversations').doc(conversationId);

    // Ensure conversation exists
    final conversationDoc = await conversationRef.get();
    if (!conversationDoc.exists) {
      await conversationRef.set({
        'participants': [senderId],
        'participantNames': [senderName],
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'unreadCount': {senderId: 0},
      });
    }

    // Add message
    final messageRef = conversationRef.collection('messages').doc();
    await messageRef.set({
      'text': text,
      'senderId': senderId,
      'senderName': senderName,
      'time': FieldValue.serverTimestamp(),
    });

    // Update unread counts
    final data = (await conversationRef.get()).data() ?? {};
    final participants = List<String>.from(data['participants'] ?? []);
    final unreadCount = Map<String, dynamic>.from(data['unreadCount'] ?? {});


    for (final uid in participants) {
      if (uid != senderId) {
        unreadCount[uid] = (unreadCount[uid] ?? 0) + 1;
      }
    }

    await conversationRef.update({
      'lastMessage': text,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'unreadCount': unreadCount,
    });
  }

  // =========================
  // MARK CONVERSATION AS READ
  // =========================
  Future<void> markConversationAsRead(String conversationId) async {
    await _db.collection('conversations').doc(conversationId).update({
      'unreadCount.$_currentUserId': 0,
    });
  }

  // =========================
  // USER CONVERSATIONS STREAM
  // =========================
  Stream<List<Map<String, dynamic>>> userConversations() {
    final userId = _currentUserId;

    return _db
        .collection('conversations')
        .where('participants', arrayContains: userId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              return {
                'id': doc.id,
                'lastMessage': data['lastMessage'] ?? '',
                'lastMessageTime':
                    (data['lastMessageTime'] as Timestamp?)?.toDate(),
                'unreadCount':
                    (data['unreadCount'] as Map<String, dynamic>?)?[userId] ?? 0,
                'participantNames':
                    List<String>.from(data['participantNames'] ?? []),
              };
            }).toList());
  }
}
