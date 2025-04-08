import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class SimpleSubscriptionService {

  // دالة للتحقق من حالة الاشتراك باستخدام API الجديدة
  static Future<bool> checkSubscriptionStatus(String username, String companyType) async {
    try {
      // استخدام POST بدلاً من GET مع JSON في الجسم
      final response = await http.post(
        Uri.parse('http://45.132.107.18/api/subscriptions'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          "username": username,
          "company_type": companyType
        }),
      ).timeout(const Duration(seconds: 15));
      
      debugPrint("?? استجابة التحقق من الاشتراك: ${response.statusCode}");
      
      if (response.statusCode == 200) {
        // تحليل الاستجابة للتأكد من تنشيط الاشتراك
        final Map<String, dynamic> data = jsonDecode(response.body);
        debugPrint("?? محتوى استجابة الاشتراك: ${data['message']}");
        
        // التحقق من وجود حقل is_active في بيانات الاشتراك
        if (data.containsKey('subscription') && data['subscription'] is Map) {
          final subscriptionData = data['subscription'] as Map<String, dynamic>;
          final isActive = subscriptionData['is_active'];
          
          // تحويل القيمة إلى boolean حسب النوع (قد تكون int أو bool)
          return isActive == true || isActive == 1;
        }
        
        // إذا لم يكن هناك بيانات تفصيلية، نعتبر أن الرمز 200 يعني أن الاشتراك فعال
        return true;
      }
      
      return false; // أي رمز استجابة آخر يعني أن الاشتراك غير فعال
    } catch (e) {
      debugPrint("? خطأ أثناء التحقق من الاشتراك: $e");
      return false; // اعتبر الاشتراك منتهي في حالة حدوث خطأ
    }
  }
}