import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../screens/subscription_expired_screen.dart';
import 'simple_subscription_service.dart';

/// بوابة التحقق من الاشتراك - مسؤولة عن ضمان عدم وصول المستخدمين ذوي الاشتراكات المنتهية للتطبيق
class SubscriptionGateway {
  // تحكم في فترة التحقق الدوري
  static const Duration _checkInterval = Duration(minutes: 5);
  
  // مؤقت للتحقق الدوري
  static Timer? _periodicTimer;
  
  // حالة القفل - للإشارة إلى أن الاشتراك منتهي وتم قفل التطبيق
  static bool _isLocked = false;
  
  // آخر معلومات المستخدم تم التحقق منها
  static String? _lastCheckedUsername;
  static String? _lastCheckedCompany;
  
  /// تهيئة بوابة الاشتراك
  static Future<void> initialize() async {
    // إيقاف أي مؤقت سابق
    _periodicTimer?.cancel();
    
    // إعادة ضبط حالة القفل
    _isLocked = false;
    
    // بدء عملية التحقق الدوري
    _periodicTimer = Timer.periodic(_checkInterval, (_) async {
      try {
        // الحصول على بيانات المستخدم الحالي 
        if (_lastCheckedUsername != null && _lastCheckedCompany != null) {
          debugPrint("🔄 SubscriptionGateway: تحقق دوري من اشتراك المستخدم: $_lastCheckedUsername");
          
          // التحقق من الاشتراك
          bool isExpired = !(await SimpleSubscriptionService.checkSubscriptionStatus(
            _lastCheckedUsername!, 
            _lastCheckedCompany!
          ));
          
          // إذا كان الاشتراك منتهيًا، قم بتأمين التطبيق
          if (isExpired && !_isLocked) {
            debugPrint("🔒 SubscriptionGateway: تم اكتشاف انتهاء الاشتراك - قفل التطبيق");
            _isLocked = true;
            _lockApplication();
          }
        }
      } catch (e) {
        debugPrint("❌ خطأ في التحقق الدوري: $e");
      }
    });
  }

  /// توقف عمل بوابة الاشتراك
  static void dispose() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }
  
  /// التحقق من حالة الاشتراك
  /// يعيد true إذا كان الاشتراك منتهي، false إذا كان ساري
  static Future<bool> checkSubscriptionStatus({bool forceServerCheck = false}) async {
    try {
      // الحصول على معلومات المستخدم الحالي
      String? username = _lastCheckedUsername;
      String? companyType = _lastCheckedCompany;
      
      // لا يمكن التحقق بدون اسم مستخدم
      if (username == null || username.isEmpty || companyType == null || companyType.isEmpty) {
        debugPrint("⚠️ SubscriptionGateway: لا توجد معلومات مستخدم للتحقق من الاشتراك");
        return false;
      }
      
      // دائماً نتحقق من الخادم مباشرة
      bool isSubscriptionActive = await SimpleSubscriptionService.checkSubscriptionStatus(username, companyType);
      
      // عكس النتيجة لأن الدالة تعيد true إذا كان الاشتراك ساري
      bool isExpired = !isSubscriptionActive;
      
      debugPrint("ℹ️ SubscriptionGateway: نتيجة التحقق: ${isExpired ? 'منتهي' : 'ساري'}");
      
      // إذا كان الاشتراك منتهيًا، قم بتأمين التطبيق
      if (isExpired && !_isLocked) {
        debugPrint("🔒 SubscriptionGateway: تم اكتشاف انتهاء الاشتراك - قفل التطبيق");
        _isLocked = true;
        _lockApplication();
      } else if (!isExpired && _isLocked) {
        // إذا كان الاشتراك ساري لكن التطبيق مقفل، أعد ضبط حالة القفل
        debugPrint("🔓 SubscriptionGateway: الاشتراك ساري لكن التطبيق مقفل - إلغاء القفل");
        _isLocked = false;
      }
      
      return isExpired;
    } catch (e) {
      debugPrint("❌ SubscriptionGateway: خطأ أثناء التحقق من الاشتراك: $e");
      
      // في حالة الفشل، نتحفظ ونفترض أن الاشتراك غير منتهي
      return false;
    }
  }
  
  /// قفل التطبيق وتوجيه المستخدم إلى شاشة انتهاء الاشتراك
  static void _lockApplication() {
    // استدعاء على القناة الرئيسية لتجنب أخطاء واجهة المستخدم
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // استخدام GetX.offAll لضمان إزالة جميع الشاشات السابقة
      Get.offAll(() => const SubscriptionExpiredScreen());
      
      // إظهار إشعار للمستخدم
      if (Get.context != null) {
        ScaffoldMessenger.of(Get.context!).showSnackBar(
          const SnackBar(
            content: Text('تم اكتشاف انتهاء الاشتراك، الرجاء التواصل مع الإدارة'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    });
  }
  
  /// تحديث معلومات المستخدم
  static void updateUserInfo(String username, String companyType) {
    _lastCheckedUsername = username;
    _lastCheckedCompany = companyType;
    debugPrint("ℹ️ SubscriptionGateway: تم تحديث معلومات المستخدم: $username / $companyType");
  }
  
  /// التحقق من الاشتراك عند تسجيل الدخول
  /// يعيد true إذا كان الاشتراك منتهي وfalse إذا كان ساري
  static Future<bool> checkOnLogin(String username, String companyType) async {
    // تحديث معلومات المستخدم
    updateUserInfo(username, companyType);
    
    try {
      debugPrint("🔐 SubscriptionGateway: التحقق من الاشتراك عند تسجيل الدخول");
      
      // دائماً نتحقق من الخادم مباشرة
      bool isSubscriptionActive = await SimpleSubscriptionService.checkSubscriptionStatus(username, companyType);
      
      // عكس النتيجة لأن الدالة تعيد true إذا كان الاشتراك ساري
      bool isExpired = !isSubscriptionActive;
      
      // تحديث حالة القفل
      if (isExpired) {
        _isLocked = true;
      } else {
        _isLocked = false;
        
        // تهيئة بوابة الاشتراك للتحقق الدوري
        initialize();
      }
      
      debugPrint(isExpired 
          ? "⚠️ SubscriptionGateway: الاشتراك منتهي للمستخدم: $username" 
          : "✅ SubscriptionGateway: الاشتراك ساري للمستخدم: $username");
      
      return isExpired;
    } catch (e) {
      debugPrint("❌ SubscriptionGateway: خطأ في التحقق من الاشتراك عند تسجيل الدخول: $e");
      
      // في حالة الفشل، نتحفظ ونفترض أن الاشتراك غير منتهي
      return false;
    }
  }
  
  /// إعادة تعيين قفل التطبيق (يستخدم بعد تجديد الاشتراك)
  static Future<void> resetLock() async {
    try {
      _isLocked = false;
      debugPrint("✅ SubscriptionGateway: تم إعادة تعيين قفل التطبيق");
    } catch (e) {
      debugPrint("❌ SubscriptionGateway: خطأ في إعادة تعيين قفل التطبيق: $e");
    }
  }
}