import 'package:chatapp_firebase/helper/color_circle.dart';
import 'package:chatapp_firebase/pages/group_info.dart';
import 'package:chatapp_firebase/service/database_service.dart';
import 'package:chatapp_firebase/widgets/message_tile.dart';
import 'package:chatapp_firebase/widgets/widgets.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatPage extends StatefulWidget {
  final String groupId;
  final String groupName;
  final String userName;
  final String? currentUserName;

  const ChatPage({
    Key? key,
    required this.groupId,
    required this.groupName,
    required this.userName,
    this.currentUserName,
  }) : super(key: key);

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  Stream<QuerySnapshot>? chats; // Dòng dữ liệu tin nhắn từ Firestore
  TextEditingController messageController =
      TextEditingController(); // Controller nhập tin nhắn
  final ScrollController _scrollController =
      ScrollController(); // Để cuộn đến cuối khi có tin nhắn mới
  Color chatBackgroundColor = Colors.blue[50]!; // Màu mặc định

  String admin = ""; // Lưu tên admin của nhóm

  @override
  void initState() {
    super.initState();
    getChatandAdmin(); // Gọi hàm lấy tin nhắn và admin nhóm khi khởi tạo
    loadChatBackgroundColor(); //load màu được đổi trong cuộc trò chuyền
  }

  // Hàm này dùng để lấy dữ liệu tin nhắn và admin của nhóm từ Firestore
  getChatandAdmin() {
    // Lấy stream tin nhắn
    DatabaseService().getChats(widget.groupId).then((val) {
      setState(() {
        chats = val;
      });
    });
    // Lấy tên admin nhóm
    DatabaseService().getGroupAdmin(widget.groupId).then((val) {
      setState(() {
        admin = val;
      });
    });
  }

  // Hàm này đánh dấu tin nhắn là "đã bị xóa" bởi người dùng hiện tại
  void _deleteMessage(String messageId) async {
    try {
      final docRef = FirebaseFirestore.instance
          .collection("groups")
          .doc(widget.groupId)
          .collection("messages")
          .doc(messageId);

      // Cập nhật danh sách "deletedBy" thêm người dùng hiện tại
      await docRef.update({
        "deletedBy": FieldValue.arrayUnion([widget.userName])
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Lỗi khi ẩn tin nhắn: $e")),
      );
    }
  }

  // Hàm này đánh dấu tin nhắn là "đã thu hồi"
  void _recallMessage(String messageId) async {
    final docRef = FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupId)
        .collection('messages')
        .doc(messageId);

    final docSnapshot = await docRef.get();
    if (docSnapshot.exists) {
      await docRef.update({'recalled': true});
    } else {
      print('Document with id $messageId không tồn tại!');
    }
  }

  // Hàm chọn ảnh từ thư viện và gửi lên chat dưới dạng base64
  void pickAndSendImage() async {
    final picker = ImagePicker();
    final pickedFile =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);

    if (pickedFile != null) {
      File imageFile = File(pickedFile.path);
      List<int> imageBytes = await imageFile.readAsBytes();
      String base64Image = base64Encode(imageBytes);

      // Gửi tin nhắn dạng ảnh
      Map<String, dynamic> chatMessageMap = {
        "message": "",
        "imageBase64": base64Image,
        "sender": widget.userName,
        "time": DateTime.now().millisecondsSinceEpoch,
        "type": "image",
      };

      DatabaseService().sendMessage(widget.groupId, chatMessageMap);
    }
  }

  // Load màu từ SharedPreferences
  void loadChatBackgroundColor() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int? colorValue = prefs.getInt('chatBackgroundColor_${widget.groupId}');
    if (colorValue != null) {
      setState(() {
        chatBackgroundColor = Color(colorValue);
      });
    }
  }

  // Lưu màu vào SharedPreferences
  void saveChatBackgroundColor(Color color) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('chatBackgroundColor_${widget.groupId}', color.value);
  }

  // Hàm gửi tin nhắn văn bản
  void sendMessage() {
    if (messageController.text.trim().isNotEmpty) {
      Map<String, dynamic> chatMessageMap = {
        "message": messageController.text.trim(),
        "sender": widget.userName,
        "time": DateTime.now().millisecondsSinceEpoch,
        "type": "text", // Xác định là tin nhắn văn bản
      };

      DatabaseService().sendMessageNew(widget.groupId, chatMessageMap);
      setState(() {
        messageController.clear(); // Xoá nội dung sau khi gửi
      });
    }
  }

  // Hàm này để sửa nội dung tin nhắn đã gửi
  void editMessage(String messageId, String oldMessage) {
    TextEditingController editController =
        TextEditingController(text: oldMessage);

    // Hiện hộp thoại chỉnh sửa
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Chỉnh sửa tin nhắn'),
          content: TextField(
            controller: editController,
            decoration: const InputDecoration(hintText: 'Nhập nội dung mới'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () async {
                String newText = editController.text.trim();
                if (newText.isNotEmpty) {
                  await FirebaseFirestore.instance
                      .collection("groups")
                      .doc(widget.groupId)
                      .collection("messages")
                      .doc(messageId)
                      .update({
                    'message': newText,
                    'edited': true, // Đánh dấu là đã sửa
                  });
                }
                Navigator.pop(context); // Đóng hộp thoại
              },
              child: const Text('Lưu'),
            ),
          ],
        );
      },
    );
  }

  // Cuộn đến cuối danh sách tin nhắn
  void scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  // Hàm xây dựng UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: chatBackgroundColor, // Màu nền nhẹ nhàng
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blueAccent, Colors.lightBlueAccent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        centerTitle: true,
        elevation: 5,
        title: Text(
          widget.groupName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        actions: [
          PopupMenuButton<Color>(
            icon: const Icon(Icons.color_lens, color: Colors.white),
            onSelected: (Color selectedColor) {
              setState(() {
                chatBackgroundColor = selectedColor;
              });
              saveChatBackgroundColor(selectedColor); // Lưu màu khi chọn
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: Colors.blue[50],
                child: ColorCircle(Colors.blue[50]!),
              ),
              PopupMenuItem(
                value: Colors.pink[50],
                child: ColorCircle(Colors.pink[50]!),
              ),
              PopupMenuItem(
                value: Colors.green[50],
                child: ColorCircle(Colors.green[50]!),
              ),
              PopupMenuItem(
                value: Colors.grey[200],
                child: ColorCircle(Colors.grey[200]!),
              ),
              PopupMenuItem(
                value: Colors.yellow[50],
                child: ColorCircle(Colors.yellow[50]!),
              ),
              PopupMenuItem(
                value: Colors.orange[50],
                child: ColorCircle(Colors.orange[50]!),
              ),
              PopupMenuItem(
                value: Colors.purple[50],
                child: ColorCircle(Colors.purple[50]!),
              ),
              PopupMenuItem(
                value: Colors.teal[50],
                child: ColorCircle(Colors.teal[50]!),
              ),
            ],
          ),
          IconButton(
            onPressed: () {
              nextScreen(
                context,
                GroupInfo(
                  groupId: widget.groupId,
                  groupName: widget.groupName,
                  adminName: admin,
                ),
              );
            },
            icon: const Icon(Icons.info_outline, color: Colors.white),
          ),
        ],
      ),

      body: Column(
        children: [
          Expanded(child: chatMessages()), // Danh sách tin nhắn
          chatInputArea(), // Khu vực nhập tin nhắn
        ],
      ),
    );
  }

  // Hiển thị danh sách tin nhắn
  Widget chatMessages() {
    return StreamBuilder(
      stream: chats,
      builder: (context, AsyncSnapshot snapshot) {
        if (snapshot.hasData) {
          // Tự động cuộn xuống cuối
          WidgetsBinding.instance.addPostFrameCallback((_) => scrollToBottom());

          return ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            itemCount: snapshot.data.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data.docs[index];
              // Kiểm tra xem người dùng đã xoá tin nhắn này chưa
              List<dynamic>? deletedBy =
                  doc.data().containsKey('deletedBy') ? doc['deletedBy'] : [];

              if (deletedBy != null && deletedBy.contains(widget.userName)) {
                return const SizedBox.shrink(); // Ẩn tin nhắn đã bị xoá
              }

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: MessageTile(
                  message: doc['message'],
                  imageBase64: doc.data().containsKey('imageBase64')
                      ? doc['imageBase64']
                      : null,
                  sender: doc['sender'],
                  sentByMe: widget.userName == doc['sender'],
                  type: doc.data().containsKey('type') ? doc['type'] : 'text',
                  recalled: doc.data().containsKey('recalled')
                      ? doc['recalled']
                      : false,
                  onDelete: () => _deleteMessage(doc.id),
                  onRecall: () => _recallMessage(doc.id),
                  onEdit: () => editMessage(doc.id, doc['message']),
                  currentUserName: widget.userName,
                ),
              );
            },
          );
        } else {
          return const Center(
              child: CircularProgressIndicator()); // Đang tải dữ liệu
        }
      },
    );
  }

  // Khu vực nhập tin nhắn và gửi
  Widget chatInputArea() {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.photo, color: Colors.blueAccent),
              onPressed: pickAndSendImage, // Gửi ảnh
            ),
            Expanded(
              child: TextFormField(
                controller: messageController,
                style: const TextStyle(color: Colors.black),
                decoration: const InputDecoration(
                  hintText: "Send a message...",
                  hintStyle: TextStyle(color: Colors.grey, fontSize: 16),
                  border: InputBorder.none,
                ),
              ),
            ),
            GestureDetector(
              onTap: sendMessage, // Gửi tin nhắn văn bản
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 45,
                width: 45,
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.send, color: Colors.white, size: 22),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
