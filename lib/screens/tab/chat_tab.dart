import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/chat.dart';
import '../../providers/auth.dart';
import '../../models/users.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatTab extends StatefulWidget {
  final String conversationId;

  const ChatTab({super.key, required this.conversationId});

  @override
  State<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<ChatTab> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;
  late Stream<List<Map<String, dynamic>>> _messagesStream;

  @override
  void initState() {
    super.initState();
    _initializeChat();
    _messagesStream = context.read<ChatProvider>().messagesStream(widget.conversationId);
    
    
    // Scroll to bottom after first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().markConversationAsRead(widget.conversationId);
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    });
  }

  Future<void> _initializeChat() async {
    final authProvider = context.read<AuthProvider>();
    final currentUser = authProvider.user;

    if (currentUser == null) return;
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final currentUser = authProvider.user;

    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text("Please log in to access chat.")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Tech Mafias',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          )
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.group),
            onPressed: () {
              _showGroupMembersModal(context);
            },
            tooltip: 'View Group Members',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.animateTo(
                      0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  }
                });

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, color: Colors.red, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          'Error: ${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _initializeChat,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No messages yet',
                          style: TextStyle(color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Start the conversation!',
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      ],
                    ),
                  );
                }

                final messages = snapshot.data!;

                // Use ListView with reverse: true to display from bottom to top
                return ListView.builder(
                  controller: _scrollController,
                  reverse: true, // This makes messages appear from bottom
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    // Since list is reversed, we need to access items in reverse order
                    final reversedIndex = messages.length - 1 - index;
                    final message = messages[reversedIndex];
                    
                    final isMe = message['senderId'] == currentUser.id;
                    final timestamp = message['time'] as DateTime;
                    final senderName = message['senderName'] ?? 'Unknown';
                    final text = message['text'] ?? '';

                    // Determine if this is first/last in sequence for grouping
                    bool isFirstInSequence = reversedIndex == 0 || 
                        messages[reversedIndex - 1]['senderId'] != message['senderId'];
                    
                    bool isLastInSequence = reversedIndex == messages.length - 1 || 
                        messages[reversedIndex + 1]['senderId'] != message['senderId'];

                    return ChatMessageBubble(
                      key: ValueKey(message['id']),
                      text: text,
                      senderName: senderName,
                      isMe: isMe,
                      timestamp: timestamp,
                      isFirstInSequence: isFirstInSequence,
                      isLastInSequence: isLastInSequence,
                    );
                  },
                );
              },
            ),
          ),
          _buildMessageInput(currentUser),
        ],
      ),
    );
  }

  Widget _buildMessageInput(User currentUser) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              enabled: !_isSending,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onSubmitted: (_) => _sendMessage(currentUser),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isSending ? Colors.grey : Colors.deepPurple,
            ),
            child: IconButton(
              icon: _isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send, color: Colors.white),
              onPressed: _isSending ? null : () => _sendMessage(currentUser),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage(User currentUser) async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);
    
    try {
      final chatProvider = context.read<ChatProvider>();
      await chatProvider.sendMessage(
        conversationId: widget.conversationId,
        text: text,
        senderName: currentUser.username,
      );
      
      // Clear the input field
      _messageController.clear();
      
      // Scroll to top (since list is reversed, top shows newest messages)
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      print('Error sending message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send message: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _showGroupMembersModal(BuildContext context) {
    final authProvider = context.read<AuthProvider>();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Group Members',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: StreamBuilder(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .orderBy('points', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return const Center(child: Text('No users found'));
                        }

                        final users = snapshot.data!.docs;

                        return ListView.builder(
                          controller: scrollController,
                          itemCount: users.length,
                          itemBuilder: (context, index) {
                            final userDoc = users[index];
                            final userData = userDoc.data();
                            final isCurrentUser = userDoc.id == authProvider.user?.id;

                            return GroupMemberCard(
                              username: userData['username'] ?? 'Unknown',
                              email: userData['email'] ?? '',
                              role: userData['role'] ?? 'Member',
                              points: userData['points'] ?? 0,
                              streak: userData['streak'] ?? 0,
                              rank: userData['rank'] ?? 1,
                              profilePhoto: userData['profilePhoto'],
                              isMafiaOfTheWeek: userData['isMafiaOfTheWeek'] ?? false,
                              isCurrentUser: isCurrentUser,
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

class ChatMessageBubble extends StatelessWidget {
  final String text;
  final String senderName;
  final bool isMe;
  final DateTime timestamp;
  final bool isFirstInSequence;
  final bool isLastInSequence;

  const ChatMessageBubble({
    super.key,
    required this.text,
    required this.senderName,
    required this.isMe,
    required this.timestamp,
    this.isFirstInSequence = true,
    this.isLastInSequence = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(
        top: isFirstInSequence ? 4 : 2,
        bottom: isLastInSequence ? 4 : 2,
        left: isMe ? MediaQuery.of(context).size.width * 0.25 : 8,
        right: isMe ? 8 : MediaQuery.of(context).size.width * 0.25,
      ),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe && isLastInSequence)
            Padding(
              padding: const EdgeInsets.only(right: 8, bottom: 2),
              child: CircleAvatar(
                radius: 12,
                backgroundColor: Colors.deepPurple[100],
                child: Text(
                  senderName.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
              ),
            ),
          
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.6,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMe && isFirstInSequence)
                    Padding(
                      padding: const EdgeInsets.only(left: 8, bottom: 2),
                      child: Text(
                        senderName,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isMe ? Colors.deepPurple : Colors.grey[100],
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(isMe ? 12 : 4),
                        topRight: Radius.circular(isMe ? 4 : 12),
                        bottomLeft: const Radius.circular(12),
                        bottomRight: const Radius.circular(12),
                      ),
                      boxShadow: isMe
                          ? [
                              BoxShadow(
                                color: Colors.deepPurple.withOpacity(0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          text,
                          style: TextStyle(
                            fontSize: 14,
                            color: isMe ? Colors.white : Colors.black,
                          ),
                          maxLines: 10,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Text(
                            DateFormat('h:mm a').format(timestamp),
                            style: TextStyle(
                              fontSize: 9,
                              color: isMe ? Colors.white70 : Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          if (isMe && isLastInSequence)
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 2),
              child: CircleAvatar(
                radius: 12,
                backgroundColor: Colors.deepPurple[100],
                child: Text(
                  senderName.substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class GroupMemberCard extends StatelessWidget {
  final String username;
  final String email;
  final String role;
  final int points;
  final int streak;
  final int rank;
  final String? profilePhoto;
  final bool isMafiaOfTheWeek;
  final bool isCurrentUser;

  const GroupMemberCard({
    super.key,
    required this.username,
    required this.email,
    required this.role,
    required this.points,
    required this.streak,
    required this.rank,
    this.profilePhoto,
    required this.isMafiaOfTheWeek,
    required this.isCurrentUser,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCurrentUser ? Colors.deepPurple[50] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrentUser ? Colors.deepPurple : Colors.grey[200]!,
          width: isCurrentUser ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.deepPurple[100],
            backgroundImage: profilePhoto != null && profilePhoto!.isNotEmpty
                ? NetworkImage(profilePhoto!) as ImageProvider
                : null,
            child: profilePhoto == null || profilePhoto!.isEmpty
                ? Text(
                    username.substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        username,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                Text(
                  email,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getRoleColor(role),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        role,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isCurrentUser)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'You',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            children: [
              _buildStatItem(Icons.score, points.toString(), 'Points'),
              const SizedBox(height: 4),
              _buildStatItem(
                  Icons.local_fire_department, streak.toString(), 'Streak'),
              const SizedBox(height: 4),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: Colors.deepPurple),
            const SizedBox(width: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Colors.red;
      case 'moderator':
        return Colors.orange;
      case 'premium':
        return Colors.blue;
      default:
        return Colors.green;
    }
  }
}