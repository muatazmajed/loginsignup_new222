import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart'; // لاستخدام MD5
import 'package:encrypt/encrypt.dart'; // مكتبة التشفير

class EncryptionService {
  final String secretKey = 'abcdefghijuklmno0123456789012345'; // المفتاح السري (32 حرفًا)

  /// **📌 تشفير البيانات**
  String encryptData(Map<String, dynamic> data) {
    final salt = _generateRandomBytes(8);

    final salted = Uint8List(48);
    Uint8List dx = Uint8List(0);
    int count = 0;

    while (count < 48) {
      final buffer = Uint8List(dx.length + utf8.encode(secretKey).length + salt.length)
        ..setAll(0, dx)
        ..setAll(dx.length, utf8.encode(secretKey))
        ..setAll(dx.length + utf8.encode(secretKey).length, salt);

      dx = Uint8List.fromList(md5.convert(buffer).bytes); // ✅ إصلاح التحويل إلى Uint8List
      salted.setRange(count, count + dx.length, dx);
      count += dx.length;
    }

    final aesKey = Key(salted.sublist(0, 32));
    final iv = IV(salted.sublist(32, 48));

    final encrypter = Encrypter(AES(aesKey, mode: AESMode.cbc));
    final encryptedData = encrypter.encrypt(jsonEncode(data), iv: iv);

    final saltedPrefix = utf8.encode("Salted__") + salt + encryptedData.bytes;
    return base64Encode(saltedPrefix);
  }

  /// **📌 فك التشفير**
  String decryptData(String encryptedData) {
    final encryptedBytes = base64Decode(encryptedData);

    // ✅ التحقق من أن البيانات تحتوي على "Salted__"
    if (utf8.decode(encryptedBytes.sublist(0, 8)) != "Salted__") {
      throw Exception("⚠️ البيانات غير صالحة!");
    }

    final salt = encryptedBytes.sublist(8, 16);
    final encryptedContent = encryptedBytes.sublist(16);

    final salted = Uint8List(48);
    Uint8List dx = Uint8List(0);
    int count = 0;

    while (count < 48) {
      final buffer = Uint8List(dx.length + utf8.encode(secretKey).length + salt.length)
        ..setAll(0, dx)
        ..setAll(dx.length, utf8.encode(secretKey))
        ..setAll(dx.length + utf8.encode(secretKey).length, salt);

      dx = Uint8List.fromList(md5.convert(buffer).bytes); // ✅ إصلاح التحويل
      salted.setRange(count, count + dx.length, dx);
      count += dx.length;
    }

    final aesKey = Key(salted.sublist(0, 32));
    final iv = IV(salted.sublist(32, 48));

    final encrypter = Encrypter(AES(aesKey, mode: AESMode.cbc));
    final decryptedData = encrypter.decrypt(Encrypted(encryptedContent), iv: iv);

    return decryptedData;
  }

  /// **📌 إنشاء بايتات عشوائية**
  static Uint8List _generateRandomBytes(int length) {
    final bytes = Uint8List(length);
    final random = Random.secure();
    for (int i = 0; i < length; i++) {
      bytes[i] = random.nextInt(256);
    }
    return bytes;
  }
}
