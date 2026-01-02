import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatProvider with ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  // Unread messages tracking
  bool _hasUnreadMessages = false;
  int _totalUnreadCount = 0;
  Map<String, int> _conversationUnreadCounts = {};
  
  // Local storage for last opened times
  Map<String, DateTime> _lastOpenedTimes = {};
  
  // Map of conversationId -> list of messages
  Map<String, List<Map<String, dynamic>>> _messagesMap = {};

  // Getters
  bool get hasUnreadMessages => _hasUnreadMessages;
  int get totalUnreadCount => _totalUnreadCount;
  
  List<Map<String, dynamic>>? getMessages(String conversationId) {
    return _messagesMap[conversationId];
  }

  // Get unread count for specific conversation
  int getUnreadCountForConversation(String conversationId) {
    return _conversationUnreadCounts[conversationId] ?? 0;
  }

  // Load last opened times from shared preferences
  Future<void> _loadLastOpenedTimes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      for (final key in keys) {
        if (key.startsWith('lastOpened_')) {
          final conversationId = key.replaceFirst('lastOpened_', '');
          final timestamp = prefs.getString(key);
          if (timestamp != null) {
            _lastOpenedTimes[conversationId] = DateTime.parse(timestamp);
          }
        }
      }
    } catch (e) {
      print('Error loading last opened times: $e');
    }
  }

  // Save last opened time to shared preferences
  Future<void> _saveLastOpenedTime(String conversationId) async {
    try {
      final now = DateTime.now();
      _lastOpenedTimes[conversationId] = now;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'lastOpened_$conversationId',
        now.toIso8601String(),
      );
    } catch (e) {
      print('Error saving last opened time: $e');
    }
  }

  // Check for unread messages in a specific conversation
  Future<void> checkConversationForUnread(String conversationId) async {
    await _loadLastOpenedTimes();
    
    final lastOpened = _lastOpenedTimes[conversationId] ?? DateTime(2000);
    
    try {
      final lastMessageSnapshot = await _db
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .orderBy('time', descending: true)
          .limit(1)
          .get();

      if (lastMessageSnapshot.docs.isNotEmpty) {
        final lastMessage = lastMessageSnapshot.docs.first;
        final messageTime = (lastMessage.data()['time'] as Timestamp).toDate();
        final senderId = lastMessage.data()['senderId'] as String;
        final currentUserId = await _getCurrentUserId();

        // Check if message is from another user and is newer than last opened
        if (senderId != currentUserId && messageTime.isAfter(lastOpened)) {
          _conversationUnreadCounts[conversationId] =
              (_conversationUnreadCounts[conversationId] ?? 0) + 1;
          _updateUnreadStatus();
        }
      }
    } catch (e) {
      print('Error checking for unread messages: $e');
    }
  }

  // Initialize unread messages tracking
  Future<void> initializeUnreadTracking(String userId) async {
    try {
      await _loadLastOpenedTimes();
      
      // Listen to all user conversations
      _db
          .collection('conversations')
          .where('participants', arrayContains: userId)
          .snapshots()
          .listen((snapshot) async {
        int totalUnread = 0;
        
        for (final doc in snapshot.docChanges) {
          final conversationId = doc.doc.id;
          final data = doc.doc.data() as Map<String, dynamic>;
          
          // Get last message time
          final lastMessageTime = (data['lastMessageTime'] as Timestamp?)?.toDate();
          final lastOpened = _lastOpenedTimes[conversationId] ?? DateTime(2000);
          
          if (lastMessageTime != null && lastMessageTime.isAfter(lastOpened)) {
            // Get last message to check sender
            final lastMessageSnapshot = await _db
                .collection('conversations')
                .doc(conversationId)
                .collection('messages')
                .orderBy('time', descending: true)
                .limit(1)
                .get();
            
            if (lastMessageSnapshot.docs.isNotEmpty) {
              final lastMessage = lastMessageSnapshot.docs.first.data();
              final senderId = lastMessage['senderId'] as String;
              
              if (senderId != userId) {
                _conversationUnreadCounts[conversationId] =
                    (_conversationUnreadCounts[conversationId] ?? 0) + 1;
                totalUnread++;
              }
            }
          }
        }
        
        _totalUnreadCount = totalUnread;
        _hasUnreadMessages = totalUnread > 0;
        notifyListeners();
      });
    } catch (e) {
      print('Error initializing unread tracking: $e');
    }
  }

  // Mark conversation as read
  Future<void> markConversationAsRead(String conversationId) async {
    await _saveLastOpenedTime(conversationId);
    _conversationUnreadCounts.remove(conversationId);
    _updateUnreadStatus();
    
    // Also update Firestore unread count
    try {
      final userId = await _getCurrentUserId();
      await _db.collection('conversations').doc(conversationId).update({
        'unreadCount.$userId': 0,
      });
    } catch (e) {
      print('Error updating Firestore unread count: $e');
    }
  }

  // Update overall unread status
  void _updateUnreadStatus() {
    _totalUnreadCount = _conversationUnreadCounts.values.fold(0, (sum, count) => sum + count);
    _hasUnreadMessages = _totalUnreadCount > 0;
    notifyListeners();
  }

  // Get current user ID (you'll need to implement this based on your auth)
  Future<String?> _getCurrentUserId() async {
    // This should return the current user's ID from your auth provider
    // For now, return null - you'll need to integrate with your AuthProvider
    return null;
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
      
      // Initialize unread count for all participants
      final unreadCountMap = <String, dynamic>{};
      unreadCountMap[senderId] = 0;
      
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
        'unreadCount': unreadCountMap,
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

      // Update conversation's last message and increment unread counts for other participants
      final conversationRef = _db.collection('conversations').doc(conversationId);
      final conversationDoc = await conversationRef.get();
      
      if (conversationDoc.exists) {
        final data = conversationDoc.data() as Map<String, dynamic>;
        final participants = List<String>.from(data['participants'] ?? []);
        final unreadCount = Map<String, dynamic>.from(data['unreadCount'] ?? {});
        
        // Increment unread count for all other participants
        for (final participant in participants) {
          if (participant != senderId) {
            final currentCount = (unreadCount[participant] as int?) ?? 0;
            unreadCount[participant] = currentCount + 1;
          }
        }

        await conversationRef.update({
          'lastMessage': text,
          'lastMessageTime': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'unreadCount': unreadCount,
        });
      }

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

  // Clear all unread messages
  Future<void> clearAllUnread() async {
    try {
      final userId = await _getCurrentUserId();
      if (userId == null) return;
      
      // Get all conversations for the user
      final conversations = await _db
          .collection('conversations')
          .where('participants', arrayContains: userId)
          .get();
      
      // Update all unread counts to 0
      final batch = _db.batch();
      for (final doc in conversations.docs) {
        batch.update(doc.reference, {
          'unreadCount.$userId': 0,
        });
      }
      await batch.commit();
      
      // Clear local unread tracking
      _conversationUnreadCounts.clear();
      _totalUnreadCount = 0;
      _hasUnreadMessages = false;
      
      // Save current time for all conversations
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().toIso8601String();
      
      for (final doc in conversations.docs) {
        await prefs.setString('lastOpened_${doc.id}', now);
      }
      
      notifyListeners();
    } catch (e) {
      print('Error clearing all unread messages: $e');
    }
  }
}