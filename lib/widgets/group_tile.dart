import 'dart:async';

import 'package:chatapp_firebase/pages/chat_page.dart';
import 'package:chatapp_firebase/service/database_service.dart';
import 'package:chatapp_firebase/widgets/widgets.dart';
import 'package:flutter/material.dart';

class GroupTile extends StatefulWidget {
  final String userName;
  final String groupId;
  final String groupName;

  const GroupTile({
    Key? key,
    required this.groupId,
    required this.groupName,
    required this.userName,
  }) : super(key: key);

  @override
  State<GroupTile> createState() => _GroupTileState();
}

class _GroupTileState extends State<GroupTile> {
  String latestMessage = '';
  bool hasUnread = false;
  Timer? refreshTimer;

  @override
  void initState() {
    super.initState();
    fetchLatestMessage();
    checkUnreadStatus();
    // Cập nhật mỗi 5 giây
    refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      fetchLatestMessage();
      checkUnreadStatus();
    });
  }

  void fetchLatestMessage() async {
    DatabaseService().getLastMessage(widget.groupId).listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final message = snapshot.docs.first['message'] ?? '[Ảnh]';
        if (message != latestMessage) {
          setState(() {
            latestMessage = message;
          });
        }
      }
    });
  }

  void checkUnreadStatus() async {
    DatabaseService()
        .hasUnreadMessages(widget.groupId, widget.userName)
        .listen((isUnread) {
      if (isUnread != hasUnread) {
        setState(() {
          hasUnread = isUnread;
        });
      }
    });
  }

  void markAsRead() async {
    await DatabaseService().markMessagesAsRead(widget.groupId, widget.userName);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        markAsRead();
        nextScreen(
          context,
          ChatPage(
            groupId: widget.groupId,
            groupName: widget.groupName,
            userName: widget.userName,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 5),
        decoration: BoxDecoration(
          color: hasUnread ? const Color(0xFFC2EBFC) : Colors.white, // màu nền khi có tin mới
          borderRadius: BorderRadius.circular(8),
        ),
        child: ListTile(
          leading: CircleAvatar(
            radius: 30,
            backgroundColor: const Color(0xff4daaf8),
            child: Text(
              widget.groupName.substring(0, 1).toUpperCase(),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
            ),
          ),
          title: Text(
            widget.groupName,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            latestMessage.isEmpty
                ? "Join the conversation as ${widget.userName}"
                : latestMessage,
            style: const TextStyle(fontSize: 13),
          ),
          trailing: hasUnread
              ? const Icon(Icons.fiber_new, color: Colors.blue, size: 30)
              : null,
        ),
      )
    );
  }
}
