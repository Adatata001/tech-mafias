import 'package:flutter/material.dart';


class ChatIconWithBadge extends StatelessWidget {
  final bool hasUnreadMessages;
  final int unreadCount;
  final VoidCallback onPressed;
  final double iconSize;

  const ChatIconWithBadge({
    super.key,
    required this.hasUnreadMessages,
    required this.unreadCount,
    required this.onPressed,
    this.iconSize = 28,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: Icon(
            Icons.chat,
            size: iconSize,
          ),
          onPressed: onPressed,
        ),
        if (hasUnreadMessages)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(
                minWidth: 14,
                minHeight: 14,
              ),
              child: unreadCount > 0
                  ? Text(
                      unreadCount > 9 ? '9+' : unreadCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    )
                  : null,
            ),
          ),
      ],
    );
  }
}