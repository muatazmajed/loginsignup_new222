import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:math';

class SubscriptionService {
  static const String _baseUrl = 'http://185.209.21.151/api';
  static const String _checkUrl = 'http://185.209.21.151/check_subscription.php';
  static const String _endDateKey = 'subscription_end_date';
  static const String _userSubscriptionKey = 'user_subscription_status';
  static const String _globalSubscriptionStatusKey = 'subscription_expired';
  static const String _companyTypeKey = 'company_type';

  // وضع التطوير - يتجاوز التحقق من انتهاء الاشتراك
  static bool _devMode = false;  // تم التعديل للإنتاج

  // التحقق من انتهاء الاشتراك باستخدام واجهة API الجديدة
  static Future<bool> checkUserSubscriptionStatus(String username, String companyName) async {
    try {
      debugPrint("?? التحقق من حالة اشتراك المستخدم: $username في الشركة: $companyName");
      
      // تشفير اسم الشركة إذا كان يحتوي على أحرف عربية
      String encodedCompany = Uri.encodeComponent(companyName);
      
      // استدعاء واجهة API الجديدة
      final response = await http.get(
        Uri.parse('$_checkUrl?username=$username&company=$encodedCompany'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      debugPrint("?? استجابة API للتحقق من الاشتراك: ${response.statusCode}");
      
      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          debugPrint("?? محتوى الاستجابة: $data");
          
          // التحقق من نجاح الاستجابة
          if (data['success'] == true) {
            // استخراج حالة انتهاء الاشتراك من الاستجابة
            final bool isExpired = data['is_expired'] ?? true;
            
            // تخزين الحالة محليًا
            await _saveSubscriptionStatus(username, isExpired);
            await _saveGlobalSubscriptionStatus(isExpired);
            
            // تخزين نوع الشركة إذا كان موجودًا
            String companyType = data['company'] ?? companyName;
            await _saveCompanyType(companyType);
            
            debugPrint("?? حالة اشتراك المستخدم: ${isExpired ? 'منتهي' : 'ساري'}");
            
            return isExpired;
          } else {
            debugPrint("?? استجابة غير ناجحة من API");
            // في حالة عدم نجاح الاستجابة، ننتقل إلى الطريقة التقليدية
            return await isSubscriptionExpired(username, true);
          }
        } catch (e) {
          debugPrint("? خطأ في تحليل استجابة API: $e");
          // في حالة حدوث خطأ، ننتقل إلى الطريقة التقليدية
          return await isSubscriptionExpired(username, true);
        }
      } else {
        debugPrint("?? فشل استدعاء API للتحقق من الاشتراك: ${response.statusCode}");
        // في حالة فشل الاستدعاء، ننتقل إلى الطريقة التقليدية
        return await isSubscriptionExpired(username, true);
      }
    } catch (e) {
      debugPrint("? استثناء أثناء التحقق من حالة الاشتراك باستخدام API الجديدة: $e");
      // في حالة حدوث استثناء، ننتقل إلى الطريقة التقليدية
      return await isSubscriptionExpired(username, true);
    }
  }

  // إنشاء المستخدم إذا لم يكن موجودًا
  static Future<bool> createUserIfNotExists(String username, String companyName) async {
    try {
      debugPrint("?? التحقق من وجود المستخدم وإنشائه إذا لم يكن موجودًا: $username");
      
      // تشفير اسم الشركة إذا كان يحتوي على أحرف عربية
      String encodedCompany = Uri.encodeComponent(companyName);
      
      // استدعاء واجهة API الجديدة أولاً للتحقق
      final checkResponse = await http.get(
        Uri.parse('$_checkUrl?username=$username&company=$encodedCompany'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));
      
      if (checkResponse.statusCode == 200) {
        final data = jsonDecode(checkResponse.body);
        // إذا كان المستخدم موجودًا بالفعل، نعود بحالة الاشتراك
        if (data['success'] == true) {
          debugPrint("? المستخدم موجود بالفعل، حالة الاشتراك: ${data['is_expired'] ? 'منتهي' : 'ساري'}");
          return data['is_expired'] ?? true;
        }
      }
      
      // إذا لم يكن المستخدم موجودًا، نقوم بإنشائه
      debugPrint("?? المستخدم غير موجود، جاري إنشاء اشتراك جديد");
      return await createSubscription(username, companyName);
    } catch (e) {
      debugPrint("? استثناء أثناء التحقق من وجود المستخدم وإنشائه: $e");
      // في حالة حدوث خطأ، نقوم بإنشاء اشتراك جديد
      return await createSubscription(username, companyName);
    }
  }

  // إنشاء اشتراك جديد للمستخدم
  static Future<bool> createSubscription(String username, String companyName) async {
    try {
      // حساب تاريخ البداية والنهاية
      DateTime startDate = DateTime.now();
      DateTime endDate = startDate.add(const Duration(days: 30));

      // تنسيق التاريخ
      DateFormat dateFormat = DateFormat('yyyy-MM-dd');
      String formattedStartDate = dateFormat.format(startDate);
      String formattedEndDate = dateFormat.format(endDate);

      debugPrint("?? إنشاء اشتراك جديد - البداية: $formattedStartDate، النهاية: $formattedEndDate");

      final response = await http.post(
        Uri.parse('$_baseUrl/subscriptions'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          "username": username,
          "company_type": companyName,
          "start_date": formattedStartDate,
          "end_date": formattedEndDate,
          "is_active": 1
        }),
      ).timeout(const Duration(seconds: 15));

      debugPrint("?? استجابة إنشاء الاشتراك: ${response.statusCode}");
      
      if (response.statusCode == 201 || response.statusCode == 200) {
        debugPrint("? تم إنشاء الاشتراك بنجاح");
        
        // حفظ بيانات الاشتراك محليًا
        await saveSubscriptionEndDate(endDate);
        await _saveCompanyType(companyName);
        await _saveSubscriptionStatus(username, false);
        await _saveGlobalSubscriptionStatus(false);
        
        return false; // الاشتراك الجديد غير منتهي
      } else {
        debugPrint("?? فشل إنشاء الاشتراك: ${response.statusCode}");
        debugPrint("?? محتوى الاستجابة: ${response.body}");
        return true; // اعتبار الاشتراك منتهي في حالة الفشل
      }
    } catch (e) {
      debugPrint("? استثناء أثناء إنشاء الاشتراك: $e");
      return true; // اعتبار الاشتراك منتهي في حالة حدوث خطأ
    }
  }

  // التحقق من انتهاء الاشتراك - الدالة الرئيسية (الطريقة التقليدية)
  static Future<bool> isSubscriptionExpired(String username, bool forceCheck) async {
    // إذا كان وضع التطوير مفعل، دائماً نعتبر الاشتراك ساري
    if (_devMode) {
      debugPrint("?? SubscriptionService: وضع التطوير مفعل. اعتبار الاشتراك ساري...");
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_globalSubscriptionStatusKey, false);
      await prefs.setBool('subscription_expired', false);
      return false;
    }
    
    try {
      // حالة خاصة: Admin دائماً يمكنه الدخول
      if (username.toLowerCase() == 'x' || 
          username.toLowerCase() == 'x' || 
          username.toLowerCase().contains('x')) {
        debugPrint("? SubscriptionService: مستخدم مسؤول، السماح بالوصول دائماً");
        // حفظ حالة الاشتراك كغير منتهي للمسؤول
        await _saveSubscriptionStatus(username, false);
        await _saveGlobalSubscriptionStatus(false);
        return false;
      }
      
      // إذا كان هناك طلب للتحقق من الخادم أو عدم وجود بيانات محلية
      if (forceCheck) {
        debugPrint("?? التحقق من حالة الاشتراك من الخادم للمستخدم: $username");
        
        // 1. نستعلم عن الاشتراكات
        final response = await http.get(
          Uri.parse('$_baseUrl/subscriptions'),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          try {
            final dynamic responseData = jsonDecode(response.body);
            List<dynamic> subscriptions = [];
            
            // معالجة البيانات استناداً إلى شكل الاستجابة
            if (responseData is List) {
              // إذا كانت الاستجابة قائمة، استخدمها مباشرة
              subscriptions = responseData;
            } else if (responseData is Map) {
              // إذا كانت الاستجابة كائن، أضفه كعنصر في قائمة
              subscriptions = [responseData];
            }
            
            // تصفية الاشتراكات للتشخيص
            debugPrint("?? SubscriptionService: تم استلام ${subscriptions.length} اشتراك من الخادم");
            
            // 2. تصفية الاشتراكات الخاصة بالمستخدم
            final userSubscriptions = subscriptions.where(
              (sub) => sub['username'].toString() == username && sub['is_active'] == 1
            ).toList();
            
            debugPrint("?? عدد اشتراكات المستخدم $username: ${userSubscriptions.length}");
            
            // 3. التحقق من وجود اشتراك ساري
            bool hasActiveSubscription = false;
            DateTime now = DateTime.now();
            String companyType = "";
            
            for (var sub in userSubscriptions) {
              try {
                DateTime endDate = DateTime.parse(sub['end_date'].toString());
                
                // اشتراك ساري إذا كان تاريخ انتهائه بعد التاريخ الحالي
                if (endDate.isAfter(now)) {
                  hasActiveSubscription = true;
                  companyType = sub['company_type']?.toString() ?? "";
                  debugPrint("? وجدنا اشتراك ساري ينتهي في: ${endDate.toString()}");
                  
                  // حفظ نوع الشركة
                  _saveCompanyType(companyType);
                  break;
                }
              } catch (e) {
                debugPrint("?? خطأ في تحليل تاريخ انتهاء الاشتراك: $e");
              }
            }
            
            // عكس النتيجة - إذا كان ليس لديه اشتراك نشط فهو منتهي
            final bool isExpired = !hasActiveSubscription;
            
            // حفظ حالة الاشتراك محليًا
            await _saveSubscriptionStatus(username, isExpired);
            await _saveGlobalSubscriptionStatus(isExpired);
            
            debugPrint(isExpired 
                ? "?? الاشتراك منتهي للمستخدم: $username (وفقًا للخادم)" 
                : "? الاشتراك ساري للمستخدم: $username (وفقًا للخادم)");
            
            return isExpired;
          } catch (parseError) {
            debugPrint("? خطأ في تحليل بيانات الاشتراك: $parseError");
            debugPrint("?? محتوى الاستجابة: ${response.body.substring(0, min(200, response.body.length))}...");
            
            // عند فشل التحليل، نفترض أن الاشتراك منتهي لتكون آمناً
            await _saveSubscriptionStatus(username, true);
            await _saveGlobalSubscriptionStatus(true);
            return true;
          }
        } else {
          debugPrint("? خطأ في التحقق من الاشتراك: ${response.statusCode}");
          debugPrint("?? محتوى الاستجابة: ${response.body.substring(0, min(200, response.body.length))}...");
          
          // في حالة خطأ الخادم، افترض أن الاشتراك منتهي لتكون آمناً
          await _saveSubscriptionStatus(username, true);
          await _saveGlobalSubscriptionStatus(true);
          return true;
        }
      } else {
        // استخدام البيانات المحلية
        bool localStatus = await _getLocalSubscriptionStatus(username);
        return localStatus;
      }
    } catch (e) {
      debugPrint("? استثناء أثناء التحقق من الاشتراك: $e");
      
      // في حالة الخطأ، افترض أن الاشتراك منتهي لتكون آمناً
      await _saveSubscriptionStatus(username, true);
      await _saveGlobalSubscriptionStatus(true);
      return true;
    }
  }

  // التحقق من وجود اشتراك نشط للمستخدم
  static Future<bool> hasActiveSubscription(String username) async {
    // إذا كان وضع التطوير مفعل، دائماً نعتبر أن المستخدم لديه اشتراك نشط
    if (_devMode) {
      return true;
    }
    
    // حالة خاصة: Admin دائماً لديه اشتراك نشط
    if (username.toLowerCase() == 'admin' || 
        username.toLowerCase() == 'admin@ing' || 
        username.toLowerCase().contains('admin')) {
      return true;
    }
    
    try {
      debugPrint("?? التحقق من وجود اشتراك نشط للمستخدم: $username");
      
      // استعلام عن كل الاشتراكات
      final response = await http.get(
        Uri.parse('$_baseUrl/subscriptions'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        try {
          final dynamic responseData = jsonDecode(response.body);
          List<dynamic> subscriptions = [];
          
          // معالجة البيانات استناداً إلى شكل الاستجابة
          if (responseData is List) {
            subscriptions = responseData;
          } else if (responseData is Map) {
            subscriptions = [responseData];
          }
          
          // تصفية الاشتراكات النشطة للمستخدم
          final activeSubscriptions = subscriptions.where(
            (sub) => sub['username'].toString() == username && sub['is_active'] == 1
          ).toList();
          
          // التحقق من وجود اشتراك ساري
          bool hasActive = false;
          DateTime now = DateTime.now();
          String companyType = "";
          
          for (var sub in activeSubscriptions) {
            try {
              DateTime endDate = DateTime.parse(sub['end_date'].toString());
              if (endDate.isAfter(now)) {
                hasActive = true;
                companyType = sub['company_type']?.toString() ?? "";
                
                // حفظ نوع الشركة
                _saveCompanyType(companyType);
                break;
              }
            } catch (e) {
              debugPrint("?? خطأ في تحليل تاريخ انتهاء الاشتراك: $e");
            }
          }
          
          // تحديث حالة الاشتراك إذا كان نشطًا
          if (hasActive) {
            await _saveSubscriptionStatus(username, false);
            await _saveGlobalSubscriptionStatus(false);
          } else {
            await _saveSubscriptionStatus(username, true);
            await _saveGlobalSubscriptionStatus(true);
          }
          
          debugPrint(hasActive 
              ? "? المستخدم $username لديه اشتراك نشط" 
              : "?? المستخدم $username ليس لديه اشتراك نشط");
          
          return hasActive;
        } catch (parseError) {
          debugPrint("? خطأ في تحليل بيانات الاشتراك: $parseError");
          return false; // افتراض عدم وجود اشتراك نشط في حالة الخطأ
        }
      } else {
        debugPrint("? خطأ في التحقق من وجود اشتراك نشط: ${response.statusCode}");
        return false; // افتراض عدم وجود اشتراك نشط في حالة الخطأ
      }
    } catch (e) {
      debugPrint("? استثناء أثناء التحقق من وجود اشتراك نشط: $e");
      return false; // افتراض عدم وجود اشتراك نشط في حالة الخطأ
    }
  }

  // الحصول على تفاصيل الاشتراك للمستخدم
  static Future<Map<String, dynamic>?> getSubscriptionDetails(String username) async {
    // حالة خاصة: Admin
    if (username.toLowerCase() == 'admin' || 
        username.toLowerCase() == 'admin@ing' || 
        username.toLowerCase().contains('admin')) {
      // إنشاء تفاصيل اشتراك وهمي للمسؤول
      final adminSubscription = {
        'username': username,
        'company_type': 'الشركة الرئيسية',
        'start_date': DateTime.now().subtract(Duration(days: 30)).toIso8601String(),
        'end_date': DateTime.now().add(Duration(days: 365)).toIso8601String(),
        'is_active': 1,
        'is_expired': false
      };
      return adminSubscription;
    }
    
    try {
      debugPrint("?? جلب تفاصيل اشتراك المستخدم: $username");
      
      // استعلام عن الاشتراكات
      final response = await http.get(
        Uri.parse('$_baseUrl/subscriptions'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        try {
          final dynamic responseData = jsonDecode(response.body);
          List<dynamic> subscriptions = [];
          
          // معالجة البيانات استناداً إلى شكل الاستجابة
          if (responseData is List) {
            subscriptions = responseData;
          } else if (responseData is Map) {
            // إذا كان اسم المستخدم يتطابق، أعد الكائن مباشرة
            if (responseData['username'].toString() == username && 
                responseData['is_active'] == 1) {
              
              // حفظ نوع الشركة
              String companyType = responseData['company_type']?.toString() ?? "";
              _saveCompanyType(companyType);
              
              return Map<String, dynamic>.from(responseData);
            }
            
            // وإلا أضفه إلى قائمة للتصفية لاحقاً
            subscriptions = [responseData];
          }
          
          // تصفية الاشتراكات النشطة للمستخدم
          final userSubscriptions = subscriptions.where(
            (sub) => sub['username'].toString() == username && sub['is_active'] == 1
          ).toList();
          
          if (userSubscriptions.isEmpty) {
            debugPrint("?? لم يتم العثور على اشتراكات للمستخدم: $username");
            return null;
          }
          
          // البحث عن أحدث اشتراك (بناءً على تاريخ الانتهاء)
          Map<String, dynamic>? latestSubscription;
          DateTime latestEndDate = DateTime(1970);
          
          for (var sub in userSubscriptions) {
            try {
              DateTime endDate = DateTime.parse(sub['end_date'].toString());
              if (endDate.isAfter(latestEndDate)) {
                latestEndDate = endDate;
                latestSubscription = Map<String, dynamic>.from(sub);
              }
            } catch (e) {
              debugPrint("?? خطأ في تحليل تاريخ انتهاء الاشتراك: $e");
            }
          }
          
          if (latestSubscription != null) {
            // إضافة معلومات إضافية
            DateTime now = DateTime.now();
            bool isExpired = latestEndDate.isBefore(now);
            latestSubscription['is_expired'] = isExpired;
            
            // حفظ نوع الشركة
            String companyType = latestSubscription['company_type']?.toString() ?? "";
            _saveCompanyType(companyType);
            
            // تحديث حالة الاشتراك
            await _saveSubscriptionStatus(username, isExpired);
            await _saveGlobalSubscriptionStatus(isExpired);
            
            debugPrint("? تم جلب تفاصيل اشتراك المستخدم: $username");
            return latestSubscription;
          }
          
          return null;
        } catch (parseError) {
          debugPrint("? خطأ في تحليل بيانات الاشتراك: $parseError");
          return null;
        }
      } else {
        debugPrint("? خطأ في جلب تفاصيل الاشتراك: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      debugPrint("? استثناء أثناء جلب تفاصيل الاشتراك: $e");
      return null;
    }
  }

  // تجديد اشتراك المستخدم
  static Future<bool> renewSubscription(String username, String companyType, int durationInDays) async {
    try {
      debugPrint("?? تجديد اشتراك المستخدم: $username لمدة $durationInDays يوم");
      
      // حساب تاريخ البداية والنهاية
      DateTime startDate = DateTime.now();
      DateTime endDate = startDate.add(Duration(days: durationInDays));

      // تنسيق التاريخ
      DateFormat dateFormat = DateFormat('yyyy-MM-dd');
      String formattedStartDate = dateFormat.format(startDate);
      String formattedEndDate = dateFormat.format(endDate);

      final response = await http.post(
        Uri.parse('$_baseUrl/subscriptions'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          "username": username,
          "company_type": companyType,
          "start_date": formattedStartDate,
          "end_date": formattedEndDate,
          "is_active": 1
        }),
      ).timeout(const Duration(seconds: 15));

      debugPrint("?? استجابة تجديد الاشتراك: ${response.statusCode}");
      if (response.body.isNotEmpty) {
        debugPrint("?? محتوى الاستجابة: ${response.body}");
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint("? تم تجديد اشتراك المستخدم: $username بنجاح");
        
        // حفظ تاريخ انتهاء الاشتراك الجديد
        await saveSubscriptionEndDate(endDate);
        
        // حفظ نوع الشركة
        _saveCompanyType(companyType);
        
        // تحديث حالة الاشتراك محليًا - الاشتراك ساري بعد التجديد
        await _saveSubscriptionStatus(username, false);
        await _saveGlobalSubscriptionStatus(false);
        
        // إعادة تعيين حالة الاشتراك بشكل كامل
        await resetSubscriptionStatus(username);
        
        return true;
      } else {
        debugPrint("?? خطأ في تجديد الاشتراك: ${response.statusCode}");
        if (response.body.isNotEmpty) {
          debugPrint("?? محتوى الاستجابة: ${response.body}");
        }
        return false;
      }
    } catch (e) {
      debugPrint("? استثناء أثناء تجديد الاشتراك: $e");
      return false;
    }
  }

  // إلغاء اشتراك المستخدم
  static Future<bool> cancelSubscription(String username) async {
    try {
      debugPrint("??? إلغاء اشتراك المستخدم: $username");
      
      // البحث عن الاشتراكات النشطة للمستخدم أولاً
      final getResponse = await http.get(
        Uri.parse('$_baseUrl/subscriptions'),
        headers: {
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));
      
      if (getResponse.statusCode == 200) {
        try {
          final dynamic responseData = jsonDecode(getResponse.body);
          List<dynamic> subscriptions = [];
          
         // معالجة البيانات استناداً إلى شكل الاستجابة
          if (responseData is List) {
            subscriptions = responseData;
          } else if (responseData is Map) {
            subscriptions = [responseData];
          }
          
          // تصفية الاشتراكات النشطة للمستخدم
          final activeSubscriptions = subscriptions.where(
            (sub) => sub['username'].toString() == username && sub['is_active'] == 1
          ).toList();
          
          if (activeSubscriptions.isEmpty) {
            debugPrint("?? لم يتم العثور على اشتراكات نشطة للمستخدم: $username");
            return false;
          }
          
          // إلغاء كل اشتراك نشط
          bool allCancelled = true;
          for (var sub in activeSubscriptions) {
            final id = sub['id'];
            
            final cancelResponse = await http.put(
              Uri.parse('$_baseUrl/subscriptions/$id'),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
              body: jsonEncode({
                "is_active": 0
              }),
            ).timeout(const Duration(seconds: 15));
            
            if (cancelResponse.statusCode != 200) {
              allCancelled = false;
              debugPrint("?? فشل في إلغاء الاشتراك رقم $id: ${cancelResponse.statusCode}");
            }
          }
          
          if (allCancelled) {
            debugPrint("? تم إلغاء جميع اشتراكات المستخدم: $username بنجاح");
            
            // تحديث حالة الاشتراك محليًا - الاشتراك منتهي بعد الإلغاء
            await _saveSubscriptionStatus(username, true);
            await _saveGlobalSubscriptionStatus(true);
            
            return true;
          } else {
            debugPrint("?? تم إلغاء بعض الاشتراكات فقط للمستخدم: $username");
            return false;
          }
        } catch (parseError) {
          debugPrint("? خطأ في تحليل بيانات الاشتراك: $parseError");
          return false;
        }
      } else {
        debugPrint("? خطأ في جلب اشتراكات المستخدم: ${getResponse.statusCode}");
        return false;
      }
    } catch (e) {
      debugPrint("? استثناء أثناء إلغاء الاشتراك: $e");
      return false;
    }
  }

  // حفظ تاريخ انتهاء الاشتراك في التخزين المحلي
  static Future<void> saveSubscriptionEndDate(DateTime endDate) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_endDateKey, endDate.toIso8601String());
      debugPrint("?? تم حفظ تاريخ انتهاء الاشتراك محليًا: ${endDate.toString()}");
    } catch (e) {
      debugPrint("? خطأ في حفظ تاريخ انتهاء الاشتراك: $e");
    }
  }

  // استرجاع تاريخ انتهاء الاشتراك من التخزين المحلي
  static Future<DateTime?> getSubscriptionEndDate() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? endDateStr = prefs.getString(_endDateKey);
      
      if (endDateStr == null) {
        return null;
      }
      
      DateTime endDate = DateTime.parse(endDateStr);
      return endDate;
    } catch (e) {
      debugPrint("? خطأ في استرجاع تاريخ انتهاء الاشتراك: $e");
      return null;
    }
  }
  
  // حفظ نوع الشركة في التخزين المحلي
  static Future<void> _saveCompanyType(String companyType) async {
    try {
      if (companyType.isNotEmpty) {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString(_companyTypeKey, companyType);
        debugPrint("?? تم حفظ نوع الشركة محليًا: $companyType");
      }
    } catch (e) {
      debugPrint("? خطأ في حفظ نوع الشركة: $e");
    }
  }
  
  // استرجاع نوع الشركة من التخزين المحلي
  static Future<String> getCompanyType() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getString(_companyTypeKey) ?? "";
    } catch (e) {
      debugPrint("? خطأ في استرجاع نوع الشركة: $e");
      return "";
    }
  }

  // حفظ حالة اشتراك المستخدم في التخزين المحلي
  static Future<void> _saveSubscriptionStatus(String username, bool isExpired) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final key = "${_userSubscriptionKey}_$username";
      await prefs.setBool(key, isExpired);
      debugPrint("?? تم حفظ حالة اشتراك المستخدم $username محليًا: ${isExpired ? 'منتهي' : 'ساري'}");
    } catch (e) {
      debugPrint("? خطأ في حفظ حالة الاشتراك: $e");
    }
  }

  // حفظ حالة الاشتراك العامة
  static Future<void> _saveGlobalSubscriptionStatus(bool isExpired) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_globalSubscriptionStatusKey, isExpired);
      await prefs.setBool('subscription_expired', isExpired);  // مفتاح إضافي للتوافق
      debugPrint("?? تم حفظ حالة الاشتراك العامة: ${isExpired ? 'منتهي' : 'ساري'}");
    } catch (e) {
      debugPrint("? خطأ في حفظ حالة الاشتراك العامة: $e");
    }
  }

  // استرجاع حالة اشتراك المستخدم من التخزين المحلي
  static Future<bool> _getLocalSubscriptionStatus(String username) async {
    try {
      // أولاً، التحقق من الحالة العامة للاشتراك
      SharedPreferences prefs = await SharedPreferences.getInstance();
      bool globalIsExpired = prefs.getBool(_globalSubscriptionStatusKey) ?? false;
      
      // للتوافق، تحقق أيضًا من المفتاح الإضافي
      bool additionalCheck = prefs.getBool('subscription_expired') ?? false;
      globalIsExpired = globalIsExpired || additionalCheck;
      
      // إذا كانت الحالة العامة تشير إلى أن الاشتراك منتهي، نرجع هذه القيمة
      if (globalIsExpired) {
        debugPrint("?? الحالة العامة للاشتراك تشير إلى أنه منتهي");
        return true;
      }
      
      // ثانيًا، التحقق من حالة اشتراك المستخدم المحددة
      final key = "${_userSubscriptionKey}_$username";
      bool isExpired = prefs.getBool(key) ?? false;
      
      // ثالثًا، التحقق من تاريخ انتهاء الاشتراك المحلي
      DateTime? endDate = await getSubscriptionEndDate();
      if (endDate != null) {
        // إذا كان تاريخ الانتهاء قبل التاريخ الحالي، فالاشتراك منتهي
        bool expiredByDate = DateTime.now().isAfter(endDate);
        
        // استخدام أسوأ الحالتين (إذا كانت إحدى الطريقتين تشير إلى انتهاء الاشتراك)
        isExpired = isExpired || expiredByDate;
      }
      
      // تحديث الحالة العامة إذا اكتشفنا أن الاشتراك منتهي
      if (isExpired && !globalIsExpired) {
        await _saveGlobalSubscriptionStatus(true);
      }
      
      debugPrint("?? حالة الاشتراك المحلية للمستخدم $username: ${isExpired ? 'منتهي' : 'ساري'}");
      return isExpired;
    } catch (e) {
      debugPrint("? خطأ في استرجاع حالة الاشتراك المحلية: $e");
      
      // في حالة الخطأ، نتحقق من الحالة العامة كاحتياط أخير
      try {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        bool globalStatus = prefs.getBool(_globalSubscriptionStatusKey) ?? false;
        bool additionalCheck = prefs.getBool('subscription_expired') ?? false;
        return globalStatus || additionalCheck;
      } catch (_) {
        return true; // نفترض أن الاشتراك منتهي في حالة الخطأ
      }
    }
  }

  // مسح بيانات الاشتراك - للاستخدام عند تسجيل الخروج
  static Future<void> clearSubscriptionData() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      
      // احتفظ بالمفتاح
      String? username = prefs.getString('username');
      
      // مسح بيانات الاشتراك الرئيسية
      await prefs.remove(_endDateKey);
      await prefs.remove(_globalSubscriptionStatusKey);
      await prefs.remove(_companyTypeKey);
      await prefs.remove('subscription_expired');  // مفتاح إضافي للتوافق
      
      // مسح بيانات اشتراك المستخدم المحددة إذا كانت متوفرة
      if (username != null && username.isNotEmpty) {
        final key = "${_userSubscriptionKey}_$username";
        await prefs.remove(key);
      }
      
      debugPrint("??? تم مسح بيانات الاشتراك المحلية");
    } catch (e) {
      debugPrint("? خطأ في مسح بيانات الاشتراك: $e");
    }
  }

  // إعادة تعيين حالة الاشتراك - للاستخدام عند تجديد الاشتراك
  static Future<void> resetSubscriptionStatus(String username) async {
    try {
      debugPrint("?? SubscriptionService: بدء إعادة تعيين حالة اشتراك المستخدم $username");
      
      // 1. حفظ حالة الاشتراك كغير منتهي في الخاص بالمستخدم
      await _saveSubscriptionStatus(username, false);
      debugPrint("? SubscriptionService: تم إعادة تعيين حالة اشتراك المستخدم المحددة");
      
      // 2. حفظ حالة الاشتراك العامة كغير منتهي
      await _saveGlobalSubscriptionStatus(false);
      debugPrint("? SubscriptionService: تم إعادة تعيين حالة الاشتراك العامة");
      
      // 3. تحديث تاريخ انتهاء الاشتراك إلى تاريخ مستقبلي (للاحتياط)
      DateTime futureDate = DateTime.now().add(Duration(days: 30));
      await saveSubscriptionEndDate(futureDate);
      debugPrint("? SubscriptionService: تم تحديث تاريخ انتهاء الاشتراك إلى $futureDate");
      
      // 4. حفظ حالة الاشتراك مباشرة في SharedPreferences
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_globalSubscriptionStatusKey, false);
      
      // 5. مسح جميع القيم المتعلقة بانتهاء الاشتراك من أي مكان آخر
      final key = "${_userSubscriptionKey}_$username";
      await prefs.setBool(key, false);
      await prefs.setBool('subscription_expired', false);
      
      debugPrint("? تم إعادة تعيين حالة اشتراك المستخدم $username بنجاح");
    } catch (e) {
      debugPrint("? خطأ في إعادة تعيين حالة الاشتراك: $e");
      
      // حتى في حالة الخطأ، نحاول إعادة تعيين الحالة المحلية
      try {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_globalSubscriptionStatusKey, false);
        await prefs.setBool('subscription_expired', false);
      } catch (_) {
        // تجاهل الخطأ
      }
    }
  }
  
  // تبديل وضع التطوير (لاستخدام المسؤول فقط)
  static void toggleDevMode() {
    _devMode = !_devMode;
    debugPrint("??? SubscriptionService: تم تبديل وضع التطوير إلى: ${_devMode ? 'مفعل' : 'غير مفعل'}");
  }
  
  // الحصول على حالة وضع التطوير
  static bool isDevMode() {
    return _devMode;
  }
  
  // تعيين وضع التطوير
  static void setDevMode(bool enabled) {
    _devMode = enabled;
    debugPrint("??? SubscriptionService: تم تعيين وضع التطوير إلى: ${_devMode ? 'مفعل' : 'غير مفعل'}");
  }

  static checkSubscriptionStatus(String username, String companyType) {}
}