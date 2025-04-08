class User {
  final String username;
  final String ipAddress;
  final int downloadBytes;
  final int uploadBytes;
  final int uptimeSeconds; // 🕒 مدة الاتصال بالثواني

  User({
    required this.username,
    required this.ipAddress,
    required this.downloadBytes,
    required this.uploadBytes,
    required this.uptimeSeconds,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      username: json['username'] ?? "غير معروف",
      ipAddress: json['framedipaddress'] ?? "",
      downloadBytes: json['acctoutputoctets'] ?? 0, // ✅ تأكد من أن التحميل هو `output`
      uploadBytes: json['acctinputoctets'] ?? 0, // ✅ تأكد من أن الرفع هو `input`
      uptimeSeconds: json['acctsessiontime'] ?? 0, // ✅ مدة الاتصال بالثواني
    );
  }

  /// **🔹 تحويل البايت إلى ميغابايت أو غيغابايت**
  String _formatDataSize(int bytes) {
    double sizeInMB = bytes / (1024 * 1024);
    return (sizeInMB >= 1000)
        ? "${(sizeInMB / 1024).toStringAsFixed(2)} GB"
        : "${sizeInMB.toStringAsFixed(2)} MB";
  }

  /// **⬇️ تحميل (Download)**
  String get formattedDownload => _formatDataSize(downloadBytes);

  /// **⬆️ رفع (Upload)**
  String get formattedUpload => _formatDataSize(uploadBytes);

  /// **⏳ تحويل Uptime إلى صيغة مقروءة**
  String get formattedUptime {
    int days = uptimeSeconds ~/ 86400; // 86400 ثانية = يوم واحد
    int hours = (uptimeSeconds % 86400) ~/ 3600;
    int minutes = (uptimeSeconds % 3600) ~/ 60;

    if (days > 0) {
      return "$days يوم";
    } else {
      return "$hours ساعة و $minutes دقيقة";
    }
  }
}
