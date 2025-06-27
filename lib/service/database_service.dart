import 'package:cloud_firestore/cloud_firestore.dart';

class DatabaseService {
  final String? uid;
  DatabaseService({this.uid});

  // reference for our collections
  final CollectionReference userCollection =
      FirebaseFirestore.instance.collection("users");
  final CollectionReference groupCollection =
      FirebaseFirestore.instance.collection("groups");

  // saving the userdata
  Future savingUserData(String fullName, String email) async {
    return await userCollection.doc(uid).set({
      "fullName": fullName,
      "email": email,
      "groups": [],
      "profilePic": "",
      "uid": uid,
    });
  }

  // getting user data
  Future gettingUserData(String email) async {
    QuerySnapshot snapshot =
        await userCollection.where("email", isEqualTo: email).get();
    return snapshot;
  }

  // get user groups
  getUserGroups() async {
    return userCollection.doc(uid).snapshots();
  }

  // creating a group
  Future createGroup(String userName, String id, String groupName) async {
    DocumentReference groupDocumentReference = await groupCollection.add({
      "groupName": groupName,
      "groupIcon": "",
      "admin": "${id}_$userName",
      "members": [],
      "groupId": "",
      "recentMessage": "",
      "recentMessageSender": "",
    });
    // update the members
    await groupDocumentReference.update({
      "members": FieldValue.arrayUnion(["${uid}_$userName"]),
      "groupId": groupDocumentReference.id,
    });

    DocumentReference userDocumentReference = userCollection.doc(uid);
    return await userDocumentReference.update({
      "groups":
          FieldValue.arrayUnion(["${groupDocumentReference.id}_$groupName"])
    });
  }

  // getting the chats
  getChats(String groupId) async {
    return groupCollection
        .doc(groupId)
        .collection("messages")
        .orderBy("time")
        .snapshots();
  }

  Future getGroupAdmin(String groupId) async {
    DocumentReference d = groupCollection.doc(groupId);
    DocumentSnapshot documentSnapshot = await d.get();
    return documentSnapshot['admin'];
  }

  // get group members
  getGroupMembers(groupId) async {
    return groupCollection.doc(groupId).snapshots();
  }

  // search
  searchByName(String groupName) {
    return groupCollection.where("groupName", isEqualTo: groupName).get();
  }

  // function -> bool
  Future<bool> isUserJoined(
      String groupName, String groupId, String userName) async {
    DocumentReference userDocumentReference = userCollection.doc(uid);
    DocumentSnapshot documentSnapshot = await userDocumentReference.get();

    List<dynamic> groups = await documentSnapshot['groups'];
    if (groups.contains("${groupId}_$groupName")) {
      return true;
    } else {
      return false;
    }
  }

  Future toggleGroupJoin(
      String groupId, String userName, String groupName) async {
    DocumentReference userDocumentReference = userCollection.doc(uid);
    DocumentReference groupDocumentReference = groupCollection.doc(groupId);

    DocumentSnapshot userSnapshot = await userDocumentReference.get();
    List<dynamic> groups = userSnapshot['groups'];

    if (groups.contains("${groupId}_$groupName")) {
      // User is leaving the group
      await userDocumentReference.update({
        "groups": FieldValue.arrayRemove(["${groupId}_$groupName"])
      });

      await groupDocumentReference.update({
        "members": FieldValue.arrayRemove(["${uid}_$userName"])
      });

      // Check if group has no members left, then delete it
      DocumentSnapshot updatedGroupSnapshot = await groupDocumentReference.get();
      List<dynamic> members = updatedGroupSnapshot['members'];

      if (members.isEmpty) {
        await groupDocumentReference.delete();
      }
    } else {
      // User is joining the group
      await userDocumentReference.update({
        "groups": FieldValue.arrayUnion(["${groupId}_$groupName"])
      });

      await groupDocumentReference.update({
        "members": FieldValue.arrayUnion(["${uid}_$userName"])
      });
    }
  }


  // send message
  sendMessage(String groupId, Map<String, dynamic> chatMessageData) async {
    groupCollection.doc(groupId).collection("messages").add(chatMessageData);
    groupCollection.doc(groupId).update({
      "recentMessage": chatMessageData['message'],
      "recentMessageSender": chatMessageData['sender'],
      "recentMessageTime": chatMessageData['time'].toString(),
    });
  }

  // Lấy tin nhắn mới nhất
  Stream<QuerySnapshot> getLastMessage(String groupId) {
    return FirebaseFirestore.instance
        .collection("groups")
        .doc(groupId)
        .collection("messages")
        .orderBy("time", descending: true)
        .limit(1)
        .snapshots();
  }

// Kiểm tra xem người dùng đã đọc hay chưa
  Stream<bool> hasUnreadMessages(String groupId, String userName) {
    return FirebaseFirestore.instance
        .collection("groups")
        .doc(groupId)
        .collection("unreads")
        .doc(userName)
        .snapshots()
        .map((doc) => doc.exists && doc['hasUnread'] == true);
  }

// Đánh dấu là đã đọc
  Future<void> markMessagesAsRead(String groupId, String userName) async {
    final unreadDoc = FirebaseFirestore.instance
        .collection("groups")
        .doc(groupId)
        .collection("unreads")
        .doc(userName);
    await unreadDoc.set({'hasUnread': false});
  }

// Khi gửi tin nhắn, cập nhật unread cho tất cả thành viên (trừ người gửi)
  Future<void> sendMessageNew(String groupId, Map<String, dynamic> messageData) async {
    final messageRef = FirebaseFirestore.instance
        .collection("groups")
        .doc(groupId)
        .collection("messages")
        .doc();

    await messageRef.set(messageData);

    final groupDoc = await FirebaseFirestore.instance.collection("groups").doc(groupId).get();
    List members = groupDoc['members'] ?? [];

    for (String member in members) {
      String name = member.substring(member.indexOf("_") + 1);
      if (name != messageData['sender']) {
        FirebaseFirestore.instance
            .collection("groups")
            .doc(groupId)
            .collection("unreads")
            .doc(name)
            .set({'hasUnread': true});
      }
    }
  }

}
