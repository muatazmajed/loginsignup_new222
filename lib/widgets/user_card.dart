import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/user_model.dart';

class UserCard extends StatelessWidget {
  final User user;

  const UserCard({Key? key, required this.user}) : super(key: key);

  /// **🌐 فتح عنوان IP عند النقر على الاسم**
  Future<void> _launchIP(String? ipAddress) async {
    if (ipAddress == null || ipAddress.isEmpty) return;
    final url = "http://$ipAddress";
    if (await canLaunch(url)) {
      await launch(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 4,
      color: Colors.white,
      shadowColor: Colors.blue.shade100,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _launchIP(user.ipAddress),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildUserAvatar(),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.username,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueGrey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "IP: ${user.ipAddress}",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildConnectionStatus(),
                ],
              ),
              const SizedBox(height: 12),
              _buildDataUsage(),
            ],
          ),
        ),
      ),
    );
  }

  /// **🔹 أيقونة المستخدم**
  Widget _buildUserAvatar() {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.blue.shade100,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade200.withOpacity(0.5),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: const Icon(
        Icons.person,
        color: Colors.blue,
        size: 30,
      ),
    );
  }

  /// **🔹 عرض البيانات المحملة والمرفوعة**
  Widget _buildDataUsage() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildUsageTile("⬇️ Download", user.formattedDownload, Colors.blue),
        _buildUsageTile("⬆️ Upload", user.formattedUpload, Colors.green),
      ],
    );
  }

  Widget _buildUsageTile(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 14, color: color)),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  /// **🔹 حالة الاتصال (رمز الأسهم)**
  Widget _buildConnectionStatus() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.sync,
        color: Colors.green,
        size: 24,
      ),
    );
  }
}
