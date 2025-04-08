import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'simple_subscription_service.dart';

// خدمة المصادقة للتعامل مع تسجيل الدخول وحفظ الحالة
class AuthService {
  // التحقق مما إذا كان المستخدم مسجل الدخول
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('authToken');
    final username = prefs.getString('username');
    final companyType = prefs.getString('company_type');
    
    // التحقق من وجود بيانات المستخدم الأساسية
    return token != null && token.isNotEmpty && 
           username != null && username.isNotEmpty &&
           companyType != null && companyType.isNotEmpty;
  }
  
  // الحصول على معلومات المستخدم المسجل
  static Future<Map<String, String>> getUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'token': prefs.getString('authToken') ?? '',
      'username': prefs.getString('username') ?? '',
      'companyType': prefs.getString('company_type') ?? '',
      'userId': prefs.getString('user_id') ?? '',
    };
  }
  
  // التحقق من صلاحية الاشتراك
  static Future<bool> isSubscriptionActive() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString('username');
      final companyType = prefs.getString('company_type');
      
      if (username == null || username.isEmpty || 
          companyType == null || companyType.isEmpty) {
        return false;
      }
      
      // التحقق من حالة الاشتراك
      return await SimpleSubscriptionService.checkSubscriptionStatus(username, companyType);
    } catch (e) {
      debugPrint("❌ خطأ في التحقق من الاشتراك: $e");
      return false;
    }
  }
  
  // حفظ بيانات المستخدم بعد تسجيل الدخول
  static Future<void> saveUserSession({
    required String token,
    required String username,
    required String companyType,
    required String userId,
    String? password, // إضافة كلمة المرور اختيارياً للتجديد التلقائي
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('authToken', token);
      await prefs.setString('api_token', token);
      await prefs.setString('username', username);
      await prefs.setString('company_type', companyType);
      await prefs.setString('user_id', userId);
      
      // حفظ كلمة المرور إذا تم تقديمها (لتجديد التوكن)
      if (password != null && password.isNotEmpty) {
        await prefs.setString('user_password', password);
      }
      
      // حفظ وقت تسجيل الدخول لمزيد من الأمان
      await prefs.setInt('login_timestamp', DateTime.now().millisecondsSinceEpoch);
      
      debugPrint("✅ تم حفظ بيانات جلسة المستخدم بنجاح");
    } catch (e) {
      debugPrint("❌ خطأ في حفظ بيانات الجلسة: $e");
    }
  }
  
  // تسجيل الخروج
  static Future<bool> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // حذف بيانات المستخدم فقط بدون حذف seen_welcome
      await prefs.remove('authToken');
      await prefs.remove('api_token');
      await prefs.remove('username');
      await prefs.remove('user_id');
      await prefs.remove('login_timestamp');
      await prefs.remove('user_password'); // حذف كلمة المرور المخزنة
      // عدم حذف company_type لكي يتذكر التطبيق آخر شركة تم اختيارها
      
      debugPrint("✅ تم تسجيل الخروج بنجاح");
      return true;
    } catch (e) {
      debugPrint("❌ خطأ في تسجيل الخروج: $e");
      return false;
    }
  }
}