import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'company_configs.dart';

class ApiService {
  final String baseUrl;
  final String loginUrl;
  final String totalUsersUrl;
  final String onlineUsersUrl;
  final String activateUserUrl;
  final String baseUserUrl;
  final String secretKey;
  final String companyName;

  // إضافة تخزين مؤقت للبيانات
  final Map<String, CacheData> _cache = {};
  final Duration _cacheDuration = const Duration(minutes: 5);

  ApiService._internal({
    required this.baseUrl,
    required this.loginUrl,
    required this.totalUsersUrl,
    required this.onlineUsersUrl,
    required this.activateUserUrl,
    required this.baseUserUrl,
    required this.secretKey,
    required this.companyName,
  });

  factory ApiService.fromCompanyConfig(CompanyConfig config) {
    String ipAddress = config.ipAddress;
    String key = config.customKey ?? defaultSecretKey;

    debugPrint("?? إنشاء ApiService للشركة: ${config.name}");
    debugPrint("?? عنوان IP: $ipAddress");
    debugPrint("?? المفتاح المستخدم: ${config.customKey != null ? 'مخصص' : 'افتراضي'}");

    final baseUrl = "http://$ipAddress/admin/api/index.php/api";
    debugPrint("?? عنوان API الأساسي: $baseUrl");

    return ApiService._internal(
      baseUrl: baseUrl,
      loginUrl: "$baseUrl/login",
      totalUsersUrl: "$baseUrl/index/user",
      onlineUsersUrl: "$baseUrl/index/online",
      activateUserUrl: "$baseUrl/user/activate",
      baseUserUrl: "$baseUrl/user/",
      secretKey: key,
      companyName: config.name,
    );
  }

  factory ApiService.byName(String companyName) {
    debugPrint("?? محاولة إنشاء ApiService باسم الشركة: '$companyName'");

    final company = findCompanyByName(companyName);
    if (company == null) {
      debugPrint("?? لم يتم العثور على الشركة، استخدام الشركة الافتراضية");
      return ApiService.fromCompanyConfig(availableCompanies.first);
    }

    debugPrint("? تم العثور على الشركة: ${company.name}");
    return ApiService.fromCompanyConfig(company);
  }

  factory ApiService.byIp(String ipAddress) {
    debugPrint("?? محاولة إنشاء ApiService بعنوان IP: '$ipAddress'");

    final company = findCompanyByIp(ipAddress);
    if (company == null) {
      debugPrint("?? لم يتم العثور على شركة بعنوان IP، إنشاء شركة مخصصة");
      final customCompany = CompanyConfig(
        name: "شركة مخصصة",
        ipAddress: ipAddress,
      );
      return ApiService.fromCompanyConfig(customCompany);
    }

    debugPrint("? تم العثور على الشركة: ${company.name}");
    return ApiService.fromCompanyConfig(company);
  }

  factory ApiService({required String serverDomain, String? customKey}) {
    debugPrint("?? إنشاء ApiService بالإعدادات الافتراضية");
    final defaultCompany = availableCompanies.first;
    debugPrint("? استخدام الشركة الافتراضية: ${defaultCompany.name}");
    return ApiService.fromCompanyConfig(defaultCompany);
  }

  Future<void> saveSelectedCompany() async {
    try {
      debugPrint("?? محاولة حفظ الشركة المحددة: '$companyName'");
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_company', companyName);
      debugPrint("? تم حفظ الشركة المحددة في SharedPreferences");
    } catch (e) {
      debugPrint("? خطأ أثناء حفظ الشركة المحددة: $e");
    }
  }

  static Future<ApiService> fromSavedCompany() async {
    try {
      debugPrint("?? محاولة استرداد الشركة المحفوظة");
      final prefs = await SharedPreferences.getInstance();
      final savedCompany = prefs.getString('selected_company');

      if (savedCompany != null && savedCompany.isNotEmpty) {
        debugPrint("? تم العثور على شركة محفوظة: '$savedCompany'");
        return ApiService.byName(savedCompany);
      } else {
        debugPrint("?? لم يتم العثور على شركة محفوظة، استخدام الافتراضية");
        final defaultApi = ApiService(serverDomain: '');
        await defaultApi.saveSelectedCompany();
        return defaultApi;
      }
    } catch (e) {
      debugPrint("? خطأ أثناء استرداد الشركة المحفوظة: $e");
      debugPrint("?? استخدام الشركة الافتراضية بسبب الخطأ");
      return ApiService(serverDomain: '');
    }
  }

  Future<Map<String, dynamic>?> login(String username, String password) async {
    final url = Uri.parse(loginUrl);
    final formData = {"username": username, "password": password, "language": "en"};

    try {
      debugPrint("?? محاولة تسجيل الدخول إلى: $loginUrl");

      final encryptedPayload = encryptData(formData);

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"payload": encryptedPayload}),
      ).timeout(const Duration(seconds: 15)); // إضافة مهلة زمنية

      debugPrint("?? استجابة الخادم (${response.statusCode}): ${response.body.length > 100 ? '${response.body.substring(0, 100)}...' : response.body}");

      if (response.statusCode == 200) {
        try {
          final decodedResponse = jsonDecode(response.body);
          debugPrint("? تم تسجيل الدخول بنجاح");
          return decodedResponse;
        } catch (parseError) {
          debugPrint("? خطأ في تحليل الاستجابة: $parseError");
        }
      } else {
        debugPrint("? فشل تسجيل الدخول مع رمز الحالة: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("? خطأ أثناء تسجيل الدخول: $e");
    }

    return null;
  }

  // تحسين جلب جميع المستخدمين مع دعم التحميل المتدرج والتخزين المؤقت
  Future<List<Map<String, dynamic>>> getAllUsers(String token, {bool forceRefresh = false, int pageLimit = 0}) async {
    // استخدام التخزين المؤقت إذا كان البيانات صالحة وغير مطلوب تحديث قسري
    final String cacheKey = 'all_users';
    if (!forceRefresh && _isCacheValid(cacheKey)) {
      debugPrint("?? استخدام البيانات المخزنة مؤقتًا لجميع المستخدمين (${_cache[cacheKey]!.data.length} مستخدم)");
      return List<Map<String, dynamic>>.from(_cache[cacheKey]!.data);
    }

    List<Map<String, dynamic>> allUsers = [];
    try {
      debugPrint("?? محاولة جلب جميع المستخدمين");
      int currentPage = 1;
      bool hasMorePages = true;
      int processedUsers = 0;

      while (hasMorePages) {
        final url = Uri.parse("$totalUsersUrl?page=$currentPage");
        final encryptedPayload = encryptData({"token": token});

        debugPrint("?? إرسال طلب للصفحة $currentPage: $url");
        final response = await http.post(
          url,
          headers: {
            "Content-Type": "application/json",
            "Authorization": "Bearer $token",
          },
          body: jsonEncode({"payload": encryptedPayload}),
        ).timeout(const Duration(seconds: 15)); // إضافة مهلة زمنية

        if (response.statusCode == 200) {
          try {
            final responseBody = jsonDecode(response.body);
            debugPrint("? استجابة جميع المستخدمين (صفحة $currentPage): تم استلام البيانات");

            if (responseBody.containsKey('data')) {
              List<Map<String, dynamic>> currentUsers =
                  List<Map<String, dynamic>>.from(responseBody['data']);
              debugPrint("?? تم استلام ${currentUsers.length} مستخدم في الصفحة $currentPage");
              allUsers.addAll(currentUsers);
              
              processedUsers += currentUsers.length;
              
              // إذا تم تحديد حد للصفحات وتم الوصول إليه، توقف عن الجلب
              if (pageLimit > 0 && processedUsers >= pageLimit) {
                debugPrint("?? تم الوصول إلى حد المستخدمين: $pageLimit، توقف عن الجلب");
                break;
              }

              // التحقق من وجود صفحات أخرى
              hasMorePages = responseBody['next_page_url'] != null;
              if (!hasMorePages) {
                debugPrint("? لا توجد صفحات أخرى، اكتمل جلب البيانات");
              } else {
                debugPrint("?? الانتقال إلى الصفحة التالية");
                currentPage++;
              }
            } else {
              debugPrint("? خطأ: المفتاح 'data' غير موجود في استجابة API!");
              hasMorePages = false;
            }
          } catch (parseError) {
            debugPrint("? خطأ في تحليل الاستجابة: $parseError");
            hasMorePages = false;
          }
        } else {
          debugPrint("? خطأ في استجابة API: ${response.statusCode}");
          debugPrint("?? استجابة الخادم: ${response.body}");
          hasMorePages = false;
        }
      }

      debugPrint("? تم جلب ${allUsers.length} مستخدم بنجاح");
      
      // تخزين البيانات مؤقتًا للاستخدام المستقبلي
      _setCache(cacheKey, allUsers);
      
      return allUsers;
    } catch (e) {
      debugPrint("? خطأ أثناء جلب جميع المستخدمين: $e");
      
      // في حالة الخطأ، استخدم البيانات المخزنة مؤقتًا إذا كانت متوفرة
      if (_cache.containsKey(cacheKey)) {
        debugPrint("?? استخدام البيانات المخزنة مؤقتًا السابقة بسبب الخطأ");
        return List<Map<String, dynamic>>.from(_cache[cacheKey]!.data);
      }
    }

    return allUsers;
  }

  // تحسين جلب المستخدمين النشطين مع التخزين المؤقت
  Future<List<Map<String, dynamic>>> getOnlineUsers(String token, {bool forceRefresh = false}) async {
    // استخدام التخزين المؤقت إذا كان البيانات صالحة وغير مطلوب تحديث قسري
    final String cacheKey = 'online_users';
    if (!forceRefresh && _isCacheValid(cacheKey)) {
      debugPrint("?? استخدام البيانات المخزنة مؤقتًا للمستخدمين النشطين (${_cache[cacheKey]!.data.length} مستخدم)");
      return List<Map<String, dynamic>>.from(_cache[cacheKey]!.data);
    }

    List<Map<String, dynamic>> allUsers = [];
    try {
      debugPrint("?? محاولة جلب المستخدمين النشطين");
      int currentPage = 1;
      bool hasMorePages = true;

      while (hasMorePages) {
        final url = Uri.parse("$onlineUsersUrl?page=$currentPage");
        final encryptedPayload = encryptData({"token": token});
        debugPrint("?? إرسال طلب المستخدمين النشطين للصفحة $currentPage: $url");
        final response = await http.post(
          url,
          headers: {
            "Content-Type": "application/json",
            "Authorization": "Bearer $token",
          },
          body: jsonEncode({"payload": encryptedPayload}),
        ).timeout(const Duration(seconds: 15)); // إضافة مهلة زمنية
        
        if (response.statusCode == 200) {
          try {
            final responseBody = jsonDecode(response.body);
            debugPrint("? استجابة المستخدمين النشطين (صفحة $currentPage): تم استلام البيانات");

            if (responseBody.containsKey('data')) {
              List<Map<String, dynamic>> currentUsers =
                  List<Map<String, dynamic>>.from(responseBody['data']);
              debugPrint("?? تم استلام ${currentUsers.length} مستخدم نشط في الصفحة $currentPage");

              // تحسين معالجة البيانات - إضافة حقل ip_address للواجهة
              for (var user in currentUsers) {
                user['ip_address'] = user['framedipaddress'] ?? "غير متوفر";
              }

              allUsers.addAll(currentUsers);

              // التحقق من وجود صفحات أخرى
              hasMorePages = responseBody['next_page_url'] != null;
              if (!hasMorePages) {
                debugPrint("? لا توجد صفحات أخرى، اكتمل جلب البيانات");
              } else {
                debugPrint("?? الانتقال إلى الصفحة التالية");
                currentPage++;
              }
            } else {
              debugPrint("? خطأ: المفتاح 'data' غير موجود في استجابة API!");
              hasMorePages = false;
            }
          } catch (parseError) {
            debugPrint("? خطأ في تحليل الاستجابة: $parseError");
            hasMorePages = false;
          }
        } else {
          debugPrint("? خطأ في استجابة API: ${response.statusCode}");
          debugPrint("?? استجابة الخادم: ${response.body}");
          hasMorePages = false;
        }
      }

      debugPrint("? تم جلب ${allUsers.length} مستخدم نشط بنجاح");
      
      // تخزين البيانات مؤقتًا
      _setCache(cacheKey, allUsers);
      
      return allUsers;
    } catch (e) {
      debugPrint("? خطأ أثناء جلب المستخدمين النشطين: $e");
      
      // في حالة الخطأ، استخدم البيانات المخزنة مؤقتًا إذا كانت متوفرة
      if (_cache.containsKey(cacheKey)) {
        debugPrint("?? استخدام البيانات المخزنة مؤقتًا السابقة بسبب الخطأ");
        return List<Map<String, dynamic>>.from(_cache[cacheKey]!.data);
      }
    }

    return allUsers;
  }

  // تحسين جلب عدد المستخدمين الكلي مع التخزين المؤقت
  Future<int> getTotalUsers(String token, {bool forceRefresh = false}) async {
    // استخدام التخزين المؤقت إذا كان البيانات صالحة وغير مطلوب تحديث قسري
    final String cacheKey = 'total_users_count';
    if (!forceRefresh && _isCacheValid(cacheKey)) {
      debugPrint("?? استخدام العدد المخزن مؤقتًا للمستخدمين: ${_cache[cacheKey]!.data}");
      return _cache[cacheKey]!.data as int;
    }

    try {
      debugPrint("?? محاولة جلب عدد المستخدمين الكلي");
      final url = Uri.parse(totalUsersUrl);
      final encryptedPayload = encryptData({"token": token});

      debugPrint("?? إرسال طلب لعدد المستخدمين الكلي: $url");
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({"payload": encryptedPayload}),
      ).timeout(const Duration(seconds: 10)); // إضافة مهلة زمنية

      if (response.statusCode == 200) {
        try {
          final responseBody = jsonDecode(response.body);
          debugPrint("? استجابة عدد المستخدمين الكلي: تم استلام البيانات");

          if (responseBody.containsKey('total')) {
            final totalCount = int.tryParse(responseBody['total'].toString()) ?? 0;
            debugPrint("?? إجمالي عدد المستخدمين: $totalCount");
            
            // تخزين العدد مؤقتًا
            _setCache(cacheKey, totalCount);
            
            return totalCount;
          } else {
            debugPrint("? خطأ: المفتاح 'total' غير موجود في استجابة API!");
            return 0;
          }
        } catch (parseError) {
          debugPrint("? خطأ في تحليل الاستجابة: $parseError");
        }
      } else {
        debugPrint("? خطأ في استجابة API: ${response.statusCode}");
        debugPrint("?? استجابة الخادم: ${response.body}");
      }
    } catch (e) {
      debugPrint("? خطأ أثناء جلب عدد المستخدمين الكلي: $e");
      
      // في حالة الخطأ، استخدم البيانات المخزنة مؤقتًا إذا كانت متوفرة
      if (_cache.containsKey(cacheKey)) {
        debugPrint("?? استخدام العدد المخزن مؤقتًا السابق بسبب الخطأ");
        return _cache[cacheKey]!.data as int;
      }
    }

    return 0;
  }

  Future<bool> toggleUserStatus(String token, int userId, String newUsername) async {
    try {
      debugPrint("?? محاولة تفعيل المستخدم $userId");
      final url = Uri.parse(activateUserUrl);

      final payloadData = {
        "method": "credit",
        "pin": "",
        "user_id": userId.toString(),
        "new_username": newUsername,
        "money_collected": true,
        "comments": "تم تفعيل المستخدم بواسطة التطبيق",
      };

      debugPrint("?? تفعيل المستخدم بمعرف $userId واسم مستخدم جديد: $newUsername");

      final encryptedPayload = encryptData(payloadData);

      var request = http.Request('POST', url);
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Content-Type'] = 'application/x-www-form-urlencoded';
      request.bodyFields = {
        'payload': encryptedPayload,
      };

      debugPrint("?? إرسال طلب تفعيل المستخدم إلى: $url");
      http.StreamedResponse response = await request.send().timeout(const Duration(seconds: 15)); // إضافة مهلة زمنية
      String responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        debugPrint("? تم تفعيل المستخدم بنجاح");
        
        // مسح التخزين المؤقت لتحديث البيانات
        _clearCache(['all_users', 'online_users', 'total_users_count']);
        
        return true;
      } else {
        debugPrint("? فشل تفعيل المستخدم: ${response.reasonPhrase}");
        debugPrint("?? استجابة الخادم: $responseBody");
        return false;
      }
    } catch (e) {
      debugPrint("? خطأ أثناء تعديل حالة المستخدم $userId: $e");
    }

    return false;
  }

  Future<bool> deleteUser(String token, int userId) async {
    try {
      debugPrint("??? محاولة حذف المستخدم $userId");
      final url = Uri.parse("$baseUserUrl$userId");
      final formData = {"token": token};
      final encryptedPayload = encryptData(formData);

      debugPrint("?? إرسال طلب حذف المستخدم إلى: $url");
      final response = await http.delete(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"payload": encryptedPayload}),
      ).timeout(const Duration(seconds: 15)); // إضافة مهلة زمنية

      if (response.statusCode == 200) {
        debugPrint("? تم حذف المستخدم $userId بنجاح");
        
        // مسح التخزين المؤقت لتحديث البيانات
        _clearCache(['all_users', 'online_users', 'total_users_count']);
        
        return true;
      } else {
        debugPrint("? فشل حذف المستخدم: ${response.statusCode}");
        debugPrint("?? استجابة الخادم: ${response.body}");
        return false;
      }
    } catch (e) {
      debugPrint("? خطأ أثناء حذف المستخدم $userId: $e");
    }

    return false;
  }

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
      dx = md5.convert(buffer).bytes as Uint8List;
      salted.setRange(count, count + dx.length, dx);
      count += dx.length;
    }

    final aesKey = encrypt.Key(salted.sublist(0, 32));
    final iv = encrypt.IV(salted.sublist(32, 48));

    final encrypter = encrypt.Encrypter(encrypt.AES(aesKey, mode: encrypt.AESMode.cbc));
    final encryptedData = encrypter.encrypt(jsonEncode(data), iv: iv);

    final saltedPrefix = utf8.encode("Salted__") + salt + encryptedData.bytes;
    return base64Encode(saltedPrefix);
  }

  static Uint8List _generateRandomBytes(int length) {
    final bytes = Uint8List(length);
    final random = Random.secure();
    for (int i = 0; i < length; i++) {
      bytes[i] = random.nextInt(256);
    }
    return bytes;
  }

  Future<Map<String, dynamic>?> getUserProfile(String token) async {
    // استخدام التخزين المؤقت إذا كان متوفرًا
    final String cacheKey = 'user_profile';
    if (_isCacheValid(cacheKey)) {
      debugPrint("?? استخدام البيانات المخزنة مؤقتًا لملف المستخدم");
      return Map<String, dynamic>.from(_cache[cacheKey]!.data);
    }
    
    debugPrint("?? دالة getUserProfile غير منفذة بعد");
    return null;
  }

  void printServiceInfo() {
    debugPrint("?? معلومات ApiService:");
    debugPrint("?? الشركة: $companyName");
    debugPrint("?? عنوان URL الأساسي: $baseUrl");
    debugPrint("?? عنوان تسجيل الدخول: $loginUrl");
    debugPrint("?? عنوان إجمالي المستخدمين: $totalUsersUrl");
    debugPrint("?? عنوان المستخدمين النشطين: $onlineUsersUrl");
    debugPrint("? عنوان تفعيل المستخدم: $activateUserUrl");
    debugPrint("?? عنوان قاعدة المستخدم: $baseUserUrl");
    debugPrint("?? المفتاح السري: ${secretKey.substring(0, 5)}...${secretKey.substring(secretKey.length - 5)}");
  }

  // ====== وظائف التخزين المؤقت ======

  // التحقق من صلاحية البيانات المخزنة مؤقتًا
  bool _isCacheValid(String key) {
    if (_cache.containsKey(key)) {
      final cacheData = _cache[key]!;
      return cacheData.timestamp.add(_cacheDuration).isAfter(DateTime.now());
    }
    return false;
  }

  // حفظ البيانات في التخزين المؤقت
  void _setCache(String key, dynamic data) {
    _cache[key] = CacheData(
      timestamp: DateTime.now(),
      data: data,
    );
    debugPrint("?? تم حفظ البيانات في التخزين المؤقت: $key");
  }

  // مسح التخزين المؤقت
  void _clearCache(List<String> keys) {
    for (final key in keys) {
      _cache.remove(key);
    }
    debugPrint("?? تم مسح التخزين المؤقت للمفاتيح: $keys");
  }

  testTokenValidity(String token) {}
}

// كلاس لتخزين البيانات المؤقتة مع وقت الصلاحية
class CacheData {
  final DateTime timestamp;
  final dynamic data;

  CacheData({
    required this.timestamp,
    required this.data,
  });
}