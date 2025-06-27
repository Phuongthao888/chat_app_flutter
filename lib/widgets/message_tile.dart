import 'package:flutter/material.dart';
import 'dart:convert';

class MessageTile extends StatefulWidget {
  // Widget hiện tin nhắn trong chat, có thể là text hoặc ảnh, có các callback xử lý xóa, thu hồi, chỉnh sửa

  // Các biến nhận dữ liệu từ ngoài truyền vào widget
  final String message;       // Nội dung tin nhắn (text)
  final String sender;        // Tên người gửi
  final bool sentByMe;        // Có phải tin nhắn do mình gửi không? (để căn chỉnh UI)
  final String? imageBase64;  // Nếu là ảnh thì mã hóa base64 của ảnh
  final String type;          // Loại tin nhắn (text, image, ...)
  final VoidCallback onDelete;  // Callback khi xóa tin nhắn
  final VoidCallback onRecall;  // Callback khi thu hồi tin nhắn
  final bool recalled;        // Tin nhắn đã bị thu hồi chưa
  final bool edited;          // Tin nhắn đã chỉnh sửa chưa
  final VoidCallback onEdit;  // Callback khi chỉnh sửa tin nhắn
  final String? currentUserName; // Tên người dùng hiện tại (để kiểm tra có phải của mình không)

  const MessageTile({
    Key? key,
    required this.message,
    required this.sender,
    required this.sentByMe,
    this.imageBase64,
    this.type = 'text',
    required this.onDelete,
    required this.onRecall,
    this.recalled = false,
    this.edited = false,
    required this.onEdit,
    this.currentUserName,
  }) : super(key: key);

  @override
  State<MessageTile> createState() => _MessageTileState();
}

class _MessageTileState extends State<MessageTile> {
  // Hàm kiểm tra url có phải là ảnh không (để hỗ trợ tương lai nếu dùng url)
  bool isImage(String url) {
    return url.startsWith('http') &&
        (url.endsWith('.png') ||
            url.endsWith('.jpg') ||
            url.endsWith('.jpeg') ||
            url.endsWith('.gif') ||
            url.endsWith('.webp'));
  }

  // Hàm hiển thị ảnh full màn hình khi người dùng nhấn vào ảnh
  // 1. Giải mã base64 thành bytes ảnh
  // 2. Mở dialog chứa InteractiveViewer (cho phép zoom, pan ảnh)
  void _showFullImage(BuildContext context) {
    if (widget.imageBase64 != null) {
      final decodedBytes = base64Decode(widget.imageBase64!);

      showDialog(
        context: context,
        builder: (BuildContext context) {
          return Dialog(
            child: InteractiveViewer(
              child: Image.memory(decodedBytes, fit: BoxFit.contain),
            ),
          );
        },
      );
    }
  }

  // Hàm hiển thị menu tùy chọn khi người dùng nhấn giữ tin nhắn
  // Hiển thị các lựa chọn: Thu hồi (chỉ nếu là tin nhắn của mình), Xóa, Chỉnh sửa (chỉ của mình)
  // Gọi callback tương ứng khi chọn
  void _showOptionsDialog(BuildContext context, String sender) {
    final isOwnMessage = sender == widget.currentUserName;

    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Nếu là tin nhắn của mình thì cho thu hồi
            if (isOwnMessage)
              ListTile(
                leading: const Icon(Icons.undo, color: Colors.blue),
                title: const Text('Thu hồi tin nhắn'),
                onTap: () {
                  Navigator.pop(context); // Đóng dialog
                  widget.onRecall();      // Gọi hàm thu hồi tin nhắn
                },
              ),
            // Luôn có lựa chọn xóa tin nhắn
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Xóa tin nhắn'),
              onTap: () {
                Navigator.pop(context); // Đóng dialog
                widget.onDelete();      // Gọi hàm xóa tin nhắn
              },
            ),
            // Nếu là tin nhắn của mình thì có thể chỉnh sửa
            if (isOwnMessage)
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.green),
                title: const Text('Chỉnh sửa tin nhắn'),
                onTap: () {
                  Navigator.pop(context); // Đóng dialog
                  widget.onEdit();        // Gọi hàm chỉnh sửa tin nhắn
                },
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget contentWidget;

    // Nếu tin nhắn đã bị thu hồi thì hiển thị text báo đã thu hồi
    if (widget.recalled) {
      contentWidget = const Text(
        'Tin nhắn đã được thu hồi',
        style: TextStyle(
          fontStyle: FontStyle.italic,
          color: Colors.white70,
          fontSize: 16,
        ),
      );
    }
    // Nếu là ảnh và có base64 thì hiển thị ảnh
    else if (widget.type == 'image' && widget.imageBase64 != null) {
      final decodedBytes = base64Decode(widget.imageBase64!);
      contentWidget = GestureDetector(
        onTap: () => _showFullImage(context), // Nhấn ảnh để xem full
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            decodedBytes,
            fit: BoxFit.cover,
            height: 200,
            width: 200,
            errorBuilder: (context, error, stackTrace) => const Text(
              'Error loading image',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
      );
    }
    // Nếu là tin nhắn text bình thường thì hiển thị nội dung
    else {
      contentWidget = Text(
        widget.message,
        textAlign: TextAlign.start,
        style: const TextStyle(fontSize: 16, color: Colors.white),
      );
    }

    return GestureDetector(
      onLongPress: () => _showOptionsDialog(context, widget.sender),
      // Nhấn giữ hiện menu tùy chọn thu hồi/xóa/chỉnh sửa

      child: Container(
        padding: EdgeInsets.only(
            top: 4,
            bottom: 4,
            left: widget.sentByMe ? 0 : 24, // Căn lề trái hoặc phải tuỳ người gửi
            right: widget.sentByMe ? 24 : 0),
        alignment:
        widget.sentByMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: widget.sentByMe
              ? const EdgeInsets.only(left: 30)
              : const EdgeInsets.only(right: 30),
          padding: const EdgeInsets.symmetric(vertical: 17, horizontal: 20),
          decoration: BoxDecoration(
            borderRadius: widget.sentByMe
                ? const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(20),
            )
                : const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
            color: widget.sentByMe ? const Color(0xff4daaf8) : Colors.grey[700],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hiển thị tên người gửi viết hoa
              Text(
                widget.sender.toUpperCase(),
                textAlign: TextAlign.start,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.5),
              ),
              // Nếu tin nhắn đã chỉnh sửa và chưa bị thu hồi thì hiện dòng (Đã chỉnh sửa)
              if (widget.edited && !widget.recalled)
                const Text(
                  "(Đã chỉnh sửa)",
                  style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: Colors.white70),
                ),
              const SizedBox(height: 8),
              // Hiển thị nội dung tin nhắn (text hoặc ảnh)
              contentWidget,
            ],
          ),
        ),
      ),
    );
  }
}
