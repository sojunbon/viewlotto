import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// ✅ ใช้สีจาก Theme เดิม
const Color kMainGreen = Color(0xFF11998E);
const Color kDeepBlue = Color(0xFF1A3D5D);

class AdminUserManagement extends StatefulWidget {
  const AdminUserManagement({super.key});

  @override
  State<AdminUserManagement> createState() => _AdminUserManagementState();
}

class _AdminUserManagementState extends State<AdminUserManagement> {
  String searchQuery = "";

  // ✅ ฟังก์ชันอัปเดตสิทธิ์ (Role)
  Future<void> _updateUserRole(String uid, String newRole) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'role': newRole,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("อัปเดตสิทธิ์เป็น $newRole เรียบร้อย")),
        );
      }
    } catch (e) {
      debugPrint("Update Error: $e");
    }
  }

  // ✅ ฟังก์ชันลบ User (หรือระงับการใช้งาน)
  Future<void> _deleteUser(String uid) async {
    bool confirm = await _showConfirmDialog();
    if (confirm) {
      await FirebaseFirestore.instance.collection('users').doc(uid).delete();
    }
  }

  Future<bool> _showConfirmDialog() async {
    return await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("ยืนยันการลบ"),
            content: const Text("คุณต้องการลบผู้ใช้งานรายนี้ใช่หรือไม่?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("ยกเลิก"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text("ลบ", style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "จัดการผู้ใช้งาน",
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        backgroundColor: kDeepBlue,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // 1. ช่องค้นหา User
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: "ค้นหาด้วย Email หรือ ชื่อ...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (val) =>
                  setState(() => searchQuery = val.toLowerCase()),
            ),
          ),

          // 2. รายชื่อ User จาก Firestore
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError)
                  return const Center(child: Text("เกิดข้อผิดพลาด"));
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                // กรองข้อมูลตามคำค้นหา
                var docs = snapshot.data!.docs.where((doc) {
                  String email = (doc.get('email') ?? "")
                      .toString()
                      .toLowerCase();
                  return email.contains(searchQuery);
                }).toList();

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var userData = docs[index].data() as Map<String, dynamic>;
                    String uid = docs[index].id;
                    String email = userData['email'] ?? 'No Email';
                    String role = userData['role'] ?? 'user';

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: role == 'admin'
                              ? Colors.orange
                              : kMainGreen,
                          child: Icon(
                            role == 'admin' ? Icons.security : Icons.person,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(
                          email,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text("สิทธิ์ปัจจุบัน: $role"),
                        trailing: PopupMenuButton<String>(
                          onSelected: (val) {
                            if (val == 'delete') {
                              _deleteUser(uid);
                            } else {
                              _updateUserRole(uid, val);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'admin',
                              child: Text("ตั้งเป็น Admin"),
                            ),
                            const PopupMenuItem(
                              value: 'user',
                              child: Text("ตั้งเป็น User ปกติ"),
                            ),
                            const PopupMenuDivider(),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text(
                                "ลบผู้ใช้",
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
