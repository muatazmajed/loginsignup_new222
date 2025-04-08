import 'dart:async';
import 'dart:isolate';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:loginsignup_new/services/company_configs.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'package:loginsignup_new/services/api_service.dart';
import 'package:loginsignup_new/services/auth_service.dart';

// معرّف وظيفة العمل في الخلفية
const String TOKEN_REFRESH_TASK = "token_refresh_task";

// خدمة تجديد التوكن مع دعم العمل في الخلفية
class TokenRefreshService {
  // إعدادات مؤقت التجديد - 40 دقيقة بدلاً من 50 دقيقة للأمان
  static const int refreshIntervalMinutes = 40;
  
  // معرّف إرسال واستقبال الرسائل في خلفية التطبيق
  static const String BACKGROUND_PORT_NAME = "token_refresh_port";
  
  // متغيرات حالة الخدمة
  Timer? _refreshTimer;
  bool _isRefreshing = false;
  
  // التاريخ الأخير لتجديد التوكن
  DateTime? _lastRefreshTime;
  
  // مؤقت مراقبة حالة التوكن
  Timer? _watchdogTimer;
  
  // الحفاظ على نسخة واحدة من الخدمة (Singleton)
  static final TokenRefreshService _instance = TokenRefreshService._internal();
  
  // المنشئ الداخلي
  TokenRefreshService._internal();
  
  // الدالة المصنعة لإرجاع النسخة الوحيدة
  factory TokenRefreshService() {
    return _instance;
  }
  
  // تسجيل مهمة تجديد التوكن في الخلفية
  Future<void> _registerBackgroundTask() async {
    try {
      // تسجيل المهمة الدورية باستخدام Workmanager
      await Workmanager().registerPeriodicTask(
        TOKEN_REFRESH_TASK,
        TOKEN_REFRESH_TASK,
        frequency: Duration(minutes: refreshIntervalMinutes),
        constraints: Constraints(
          networkType: NetworkType.connected,
        ),
        existingWorkPolicy: ExistingWorkPolicy.replace,
        backoffPolicy: BackoffPolicy.linear,
        backoffPolicyDelay: Duration(minutes: 5),
      );
      
      debugPrint("🔄✅ تم تسجيل مهمة تجديد التوكن في الخلفية");
    } catch (e) {
      debugPrint("🔄❌ خطأ في تسجيل مهمة تجديد التوكن في الخلفية: $e");
    }
  }
  
  // إلغاء مهمة تجديد التوكن في الخلفية
  Future<void> _cancelBackgroundTask() async {
    try {
      await Workmanager().cancelByUniqueName(TOKEN_REFRESH_TASK);
      debugPrint("🔄✅ تم إلغاء مهمة تجديد التوكن في الخلفية");
    } catch (e) {
      debugPrint("🔄❌ خطأ في إلغاء مهمة تجديد التوكن في الخلفية: $e");
    }
  }
  
  // بدء خدمة تجديد التوكن التلقائي
  Future<void> startAutoRefresh() async {
    debugPrint("🔄 بدء خدمة تجديد التوكن التلقائي كل $refreshIntervalMinutes دقيقة");
    
    // إلغاء أي مؤقت سابق
    _stopRefreshTimer();
    
    // تسجيل منفذ لتلقي الرسائل من الخلفية
    _registerBackgroundPort();
    
    // تسجيل مهمة التجديد في الخلفية
    await _registerBackgroundTask();
    
    // إنشاء مؤقت جديد للتجديد عندما يكون التطبيق في المقدمة
    _refreshTimer = Timer.periodic(
      Duration(minutes: refreshIntervalMinutes),
      (_) => _refreshToken(),
    );
    
    // تفعيل مؤقت مراقبة حالة التوكن (كل 10 دقائق)
    _watchdogTimer = Timer.periodic(
      Duration(minutes: 10),
      (_) => _checkTokenHealth(),
    );
    
    // تنفيذ تجديد فوري للتوكن
    await _refreshToken();
    
    // تحديث وقت آخر تجديد
    _updateLastRefreshTime();
  }
  
  // التحقق من صحة التوكن دورياً
  Future<void> _checkTokenHealth() async {
    try {
      debugPrint("🔄🔍 فحص حالة التوكن...");
      
      // التحقق من الفترة المنقضية منذ آخر تحديث
      if (_lastRefreshTime != null) {
        final duration = DateTime.now().difference(_lastRefreshTime!);
        if (duration.inMinutes > (refreshIntervalMinutes * 1.5)) {
          debugPrint("🔄⚠️ مر وقت طويل منذ آخر تحديث للتوكن: ${duration.inMinutes} دقيقة");
          await forceRefreshNow();
        } else {
          debugPrint("🔄✓ التوكن محدث (آخر تحديث منذ ${duration.inMinutes} دقيقة)");
        }
      } else {
        // لا يوجد تاريخ تحديث مسجل، قم بالتحديث الآن
        debugPrint("🔄❗ لا يوجد سجل لآخر تحديث للتوكن، تحديث الآن");
        await forceRefreshNow();
      }
      
      // التحقق من صلاحية التوكن الحالي
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('api_token');
      
      if (token == null || token.isEmpty) {
        debugPrint("🔄❗ التوكن غير موجود، إعادة المصادقة مطلوبة");
        await forceRefreshNow();
        return;
      }
      
      // محاولة استخدام التوكن في طلب بسيط للتحقق من صلاحيته
      try {
        final apiService = ApiService.fromCompanyConfig({
          'server_domain': prefs.getString('company_domain') ?? '',
          'company_name': prefs.getString('company_type') ?? ''
        } as CompanyConfig);
        
        // طلب بسيط للتحقق
        final result = await apiService.testTokenValidity(token);
        if (!result) {
          debugPrint("🔄❗ التوكن الحالي غير صالح، محاولة تجديد");
          await forceRefreshNow();
        } else {
          debugPrint("🔄✓ التوكن الحالي صالح");
        }
      } catch (e) {
        debugPrint("🔄⚠️ خطأ أثناء اختبار صلاحية التوكن: $e");
        // محاولة تجديد التوكن في حالة الخطأ
        await forceRefreshNow();
      }
    } catch (e) {
      debugPrint("🔄❌ خطأ عام في فحص حالة التوكن: $e");
    }
  }
  
  // تحديث وقت آخر تجديد للتوكن
  Future<void> _updateLastRefreshTime() async {
    try {
      _lastRefreshTime = DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token_last_refresh', _lastRefreshTime!.toIso8601String());
      debugPrint("🔄⏱️ تم تحديث وقت آخر تجديد للتوكن: ${_lastRefreshTime!.toIso8601String()}");
    } catch (e) {
      debugPrint("🔄❌ خطأ في تحديث وقت آخر تجديد للتوكن: $e");
    }
  }
  
  // إيقاف خدمة تجديد التوكن التلقائي
  Future<void> stopAutoRefresh() async {
    debugPrint("🔄🛑 إيقاف خدمة تجديد التوكن التلقائي");
    
    // إلغاء المؤقتات
    _stopRefreshTimer();
    
    // إلغاء مؤقت المراقبة
    _watchdogTimer?.cancel();
    _watchdogTimer = null;
    
    // إلغاء المهمة في الخلفية
    await _cancelBackgroundTask();
    
    // إلغاء تسجيل منفذ استقبال الرسائل
    _unregisterBackgroundPort();
  }
  
  // تسجيل منفذ لاستقبال الرسائل من خلفية التطبيق
  void _registerBackgroundPort() {
    try {
      // إلغاء تسجيل أي منفذ سابق
      IsolateNameServer.removePortNameMapping(BACKGROUND_PORT_NAME);
      
      // إنشاء منفذ استقبال
      final receivePort = ReceivePort();
      
      // تسجيل المنفذ باسم معروف
      if (IsolateNameServer.registerPortWithName(
        receivePort.sendPort, 
        BACKGROUND_PORT_NAME
      )) {
        debugPrint("🔄✅ تم تسجيل منفذ استقبال رسائل تجديد التوكن");
        
        // الاستماع للرسائل
        receivePort.listen((message) {
          debugPrint("🔄📨 تم استلام رسالة من الخلفية: $message");
          
          // إذا كانت الرسالة تطلب تجديد التوكن
          if (message == "refresh_token") {
            _refreshToken();
          }
        });
      } else {
        debugPrint("🔄❌ فشل تسجيل منفذ استقبال رسائل تجديد التوكن");
      }
    } catch (e) {
      debugPrint("🔄❌ خطأ في تسجيل منفذ استقبال الرسائل: $e");
    }
  }
  
  // إلغاء تسجيل منفذ استقبال الرسائل
  void _unregisterBackgroundPort() {
    try {
      // إلغاء تسجيل المنفذ
      if (IsolateNameServer.removePortNameMapping(BACKGROUND_PORT_NAME)) {
        debugPrint("🔄✅ تم إلغاء تسجيل منفذ استقبال رسائل تجديد التوكن");
      } else {
        debugPrint("🔄❌ فشل إلغاء تسجيل منفذ استقبال رسائل تجديد التوكن");
      }
    } catch (e) {
      debugPrint("🔄❌ خطأ في إلغاء تسجيل منفذ استقبال الرسائل: $e");
    }
  }
  
  // إيقاف المؤقت الحالي
  void _stopRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }
  
  // تنفيذ عملية تجديد التوكن
  Future<bool> _refreshToken() async {
    // تجنب التداخل في حالة استمرار عملية تجديد سابقة
    if (_isRefreshing) {
      debugPrint("🔄⚠️ تم تجاهل طلب تجديد التوكن (قيد التنفيذ بالفعل)");
      return false;
    }
    
    _isRefreshing = true;
    debugPrint("🔄🔑 بدء عملية تجديد التوكن");
    
    // تطبيق آلية إعادة المحاولة
    int retryCount = 0;
    const maxRetries = 3;
    
    while (retryCount < maxRetries) {
      try {
        // الحصول على بيانات المستخدم المخزنة
        final prefs = await SharedPreferences.getInstance();
        final username = prefs.getString('username');
        final companyType = prefs.getString('company_type');
        final password = prefs.getString('user_password');
        
        if (username == null || username.isEmpty || 
            companyType == null || companyType.isEmpty ||
            password == null || password.isEmpty) {
          debugPrint("🔄⚠️ لا يمكن تجديد التوكن: بيانات المستخدم غير متوفرة");
          _isRefreshing = false;
          return false;
        }
        
        // إنشاء ApiService بناءً على اسم الشركة
        final apiService = ApiService.byName(companyType);
        
        // تسجيل محاولة التجديد
        debugPrint("🔄🔁 محاولة تجديد التوكن #${retryCount + 1} لـ $username @ $companyType");
        
        // محاولة تسجيل الدخول للحصول على توكن جديد
        final result = await apiService.login(username, password);
        
        if (result != null && (result["status"] == 200 || result.containsKey("token"))) {
          final newToken = result["token"] ?? "";
          final userId = result["id"] ?? "";
          
          if (newToken.isEmpty) {
            debugPrint("🔄❌ فشل تجديد التوكن: التوكن الجديد فارغ");
            retryCount++;
            continue;
          }
          
          // حفظ التوكن الجديد
          await AuthService.saveUserSession(
            token: newToken,
            username: username,
            companyType: companyType,
            userId: userId.toString(),
            password: password, // إعادة حفظ كلمة المرور للتجديدات المستقبلية
          );
          
          // تحديث وقت آخر تجديد
          await _updateLastRefreshTime();
          
          // تسجيل معلومات التجديد
          final currentTime = DateTime.now();
          await prefs.setString('token_refresh_history', 
            '${prefs.getString('token_refresh_history') ?? ""}\n'
            '[${currentTime.toIso8601String()}] تم تجديد التوكن بنجاح'
          );
          
          debugPrint("🔄✅ تم تجديد التوكن بنجاح، توكن جديد: ${newToken.substring(0, 20)}...");
          _isRefreshing = false;
          return true;
        } else {
          debugPrint("🔄❌ فشل تجديد التوكن: ${result?.toString() ?? 'لا توجد استجابة'}");
          retryCount++;
          
          // انتظار قبل إعادة المحاولة
          if (retryCount < maxRetries) {
            await Future.delayed(Duration(seconds: 2 * retryCount));
          }
        }
      } catch (e) {
        debugPrint("🔄❌ خطأ أثناء تجديد التوكن: $e");
        retryCount++;
        
        // انتظار قبل إعادة المحاولة
        if (retryCount < maxRetries) {
          await Future.delayed(Duration(seconds: 2 * retryCount));
        }
      }
    }
    
    // فشل بعد جميع المحاولات
    debugPrint("🔄❌ فشل تجديد التوكن بعد $maxRetries محاولات");
    _isRefreshing = false;
    return false;
  }
  
  // تنفيذ تجديد فوري للتوكن (يمكن استدعاؤها عند الحاجة)
  Future<bool> forceRefreshNow() async {
    if (_isRefreshing) {
      debugPrint("🔄⚠️ التوكن قيد التجديد بالفعل");
      return false;
    }
    
    // إعادة ضبط المؤقت إذا كان نشطًا
    if (_refreshTimer != null) {
      _stopRefreshTimer();
      _refreshTimer = Timer.periodic(
        Duration(minutes: refreshIntervalMinutes),
        (_) => _refreshToken(),
      );
      debugPrint("🔄⏱️ تم إعادة ضبط مؤقت تجديد التوكن");
    }
    
    // تنفيذ التجديد
    final result = await _refreshToken();
    
    // إذا نجح التجديد، تحديث وقت آخر تجديد
    if (result) {
      _updateLastRefreshTime();
    }
    
    return result;
  }
  
  // استرجاع التاريخ المتوقع لانتهاء صلاحية التوكن
  Future<DateTime?> getTokenExpiryTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastRefreshStr = prefs.getString('token_last_refresh');
      
      if (lastRefreshStr == null) {
        return null;
      }
      
      final lastRefresh = DateTime.parse(lastRefreshStr);
      // افتراض أن التوكن صالح لمدة ساعتين (120 دقيقة)
      return lastRefresh.add(Duration(minutes: 120));
    } catch (e) {
      debugPrint("🔄❌ خطأ في حساب وقت انتهاء صلاحية التوكن: $e");
      return null;
    }
  }
  
  // التحقق مما إذا كان التوكن يحتاج إلى تجديد
  Future<bool> shouldRefreshToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastRefreshStr = prefs.getString('token_last_refresh');
      
      if (lastRefreshStr == null) {
        return true;
      }
      
      final lastRefresh = DateTime.parse(lastRefreshStr);
      final difference = DateTime.now().difference(lastRefresh);
      
      // تجديد التوكن إذا مر أكثر من 80% من وقت التجديد
      return difference.inMinutes > (refreshIntervalMinutes * 0.8);
    } catch (e) {
      debugPrint("🔄❌ خطأ في التحقق من الحاجة لتجديد التوكن: $e");
      return true; // تجديد التوكن في حالة الشك
    }
  }
  
  // التحقق من حالة الخدمة
  bool get isActive => _refreshTimer != null;
  
  // استرجاع وقت آخر تجديد
  DateTime? get lastRefreshTime => _lastRefreshTime;
}

// دالة معالجة مهام الخلفية - يجب استدعاؤها عند إعداد التطبيق
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    debugPrint("🔄🔙 تنفيذ مهمة الخلفية: $task");
    
    if (task == TOKEN_REFRESH_TASK) {
      try {
        // محاولة إرسال رسالة للتطبيق إذا كان في المقدمة
        SendPort? sendPort = IsolateNameServer.lookupPortByName(TokenRefreshService.BACKGROUND_PORT_NAME);
        if (sendPort != null) {
          sendPort.send("refresh_token");
          debugPrint("🔄✅ تم إرسال طلب تجديد التوكن للتطبيق");
        } else {
          debugPrint("🔄ℹ️ التطبيق غير نشط، تنفيذ تجديد التوكن في الخلفية");
          
          // تنفيذ عملية تجديد التوكن مباشرة من الخلفية
          final prefs = await SharedPreferences.getInstance();
          final username = prefs.getString('username');
          final companyType = prefs.getString('company_type');
          final password = prefs.getString('user_password');
          
          if (username != null && companyType != null && password != null) {
            final apiService = ApiService.byName(companyType);
            final result = await apiService.login(username, password);
            
            if (result != null && result.containsKey("token")) {
              final newToken = result["token"] ?? "";
              final userId = result["id"] ?? "";
              
              if (newToken.isNotEmpty) {
                // حفظ التوكن الجديد
                await prefs.setString('authToken', newToken);
                await prefs.setString('api_token', newToken);
                await prefs.setString('token_last_refresh', DateTime.now().toIso8601String());
                
                // إضافة سجل التجديد
                await prefs.setString('token_refresh_history', 
                  '${prefs.getString('token_refresh_history') ?? ""}\n'
                  '[${DateTime.now().toIso8601String()}] تم تجديد التوكن في الخلفية'
                );
                
                debugPrint("🔄✅ تم تجديد التوكن في الخلفية بنجاح");
                return true;
              }
            }
          }
        }
      } catch (e) {
        debugPrint("🔄❌ خطأ في مهمة تجديد التوكن في الخلفية: $e");
      }
    }
    
    return true;
  });
}