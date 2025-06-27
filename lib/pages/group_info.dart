import 'package:chatapp_firebase/pages/home_page.dart';
import 'package:chatapp_firebase/service/database_service.dart';
import 'package:chatapp_firebase/widgets/widgets.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class GroupInfo extends StatefulWidget {
  final String groupId;    // id nhóm chat
  final String groupName;  // tên nhóm chat
  final String adminName;  // tên admin nhóm (có dạng "id_name")
  const GroupInfo(
      {Key? key,
        required this.adminName,
        required this.groupName,
        required this.groupId})
      : super(key: key);

  @override
  State<GroupInfo> createState() => _GroupInfoState();
}

class _GroupInfoState extends State<GroupInfo> {
  Stream? members;  // stream dữ liệu thành viên nhóm (để lắng nghe realtime)

  @override
  void initState() {
    getMembers();  // khi widget khởi tạo thì gọi hàm load danh sách thành viên nhóm
    super.initState();
  }

  getMembers() async {
    // Gọi service lấy stream thành viên nhóm từ database dựa theo groupId
    DatabaseService(uid: FirebaseAuth.instance.currentUser!.uid)
        .getGroupMembers(widget.groupId)
        .then((val) {
      setState(() {
        members = val;  // cập nhật stream thành viên vào biến 'members' để UI nghe
      });
    });
  }

  String getName(String r) {
    // Lấy tên thành viên từ chuỗi kiểu "id_name" (lấy phần sau dấu '_')
    return r.substring(r.indexOf("_") + 1);
  }

  String getId(String res) {
    // Lấy id thành viên từ chuỗi kiểu "id_name" (lấy phần trước dấu '_')
    return res.substring(0, res.indexOf("_"));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(
          // Tạo background gradient cho thanh app bar
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blueAccent, Colors.lightBlueAccent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Text("Group Info"),
        actions: [
          IconButton(
              onPressed: () {
                // Khi nhấn nút thoát nhóm thì hiển thị dialog xác nhận
                showDialog(
                    barrierDismissible: false,  // phải chọn mới đóng dialog
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: const Text("Exit"),
                        content:
                        const Text("Are you sure you exit the group? "),
                        actions: [
                          IconButton(
                            onPressed: () {
                              Navigator.pop(context);  // hủy thoát nhóm, đóng dialog
                            },
                            icon: const Icon(
                              Icons.cancel,
                              color: Colors.red,
                            ),
                          ),
                          IconButton(
                            onPressed: () async {
                              // Nếu đồng ý thoát nhóm, gọi hàm toggleGroupJoin để rời nhóm
                              // Khi hoàn thành, chuyển về trang HomePage
                              DatabaseService(
                                  uid: FirebaseAuth
                                      .instance.currentUser!.uid)
                                  .toggleGroupJoin(
                                  widget.groupId,
                                  getName(widget.adminName),
                                  widget.groupName)
                                  .whenComplete(() {
                                nextScreenReplace(context, const HomePage());
                              });
                            },
                            icon: const Icon(
                              Icons.done,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      );
                    });
              },
              icon: const Icon(Icons.exit_to_app))
        ],
      ),
      body: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  color: const Color(0xffbbddf8)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: const Color(0xff4daaf8),
                    child: Text(
                      // Hiển thị chữ cái đầu của tên nhóm (in hoa)
                      widget.groupName.substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  const SizedBox(
                    width: 20,
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Group: ${widget.groupName}",  // Hiển thị tên nhóm
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(
                        height: 5,
                      ),
                      Text("Admin: ${getName(widget.adminName)}")  // Hiển thị tên admin
                    ],
                  )
                ],
              ),
            ),
            memberList(),  // Hiển thị danh sách thành viên nhóm bên dưới
          ],
        ),
      ),
    );
  }

  // Widget hiển thị danh sách thành viên nhóm dựa trên stream dữ liệu 'members'
  memberList() {
    return StreamBuilder(
      stream: members,  // stream thành viên nhóm lấy từ DB
      builder: (context, AsyncSnapshot snapshot) {
        if (snapshot.hasData) {  // nếu đã có dữ liệu
          if (snapshot.data['members'] != null) {
            if (snapshot.data['members'].length != 0) {
              // nếu có thành viên thì build ListView hiển thị từng thành viên
              return ListView.builder(
                itemCount: snapshot.data['members'].length,  // số lượng thành viên
                shrinkWrap: true,
                itemBuilder: (context, index) {
                  return Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 10),
                    child: ListTile(
                      leading: CircleAvatar(
                        radius: 30,
                        backgroundColor: const Color(0xff4daaf8),
                        child: Text(
                          // Hiển thị chữ cái đầu tên thành viên in hoa
                          getName(snapshot.data['members'][index])
                              .substring(0, 1)
                              .toUpperCase(),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(getName(snapshot.data['members'][index])), // tên thành viên
                      subtitle: Text(getId(snapshot.data['members'][index])), // id thành viên
                    ),
                  );
                },
              );
            } else {
              // nếu danh sách thành viên trống thì hiển thị dòng "NO MEMBERS"
              return const Center(
                child: Text("NO MEMBERS"),
              );
            }
          } else {
            // nếu trường 'members' trong dữ liệu null thì cũng hiển thị "NO MEMBERS"
            return const Center(
              child: Text("NO MEMBERS"),
            );
          }
        } else {
          // Nếu chưa có dữ liệu (đang tải) thì hiển thị vòng loading
          return Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).primaryColor,
              ));
        }
      },
    );
  }
}
