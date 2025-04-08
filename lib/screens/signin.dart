import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:loginsignup_new/screens/Dashboard.dart';
import 'package:loginsignup_new/screens/ompanySelectionScreen.dart';
import 'package:loginsignup_new/screens/subscription_expired_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:loginsignup_new/services/api_service.dart';
import 'package:loginsignup_new/services/global_company.dart';
import 'package:loginsignup_new/services/simple_subscription_service.dart';
import 'package:loginsignup_new/services/auth_service.dart';
import 'package:loginsignup_new/services/token_refresh_service.dart'; // استيراد خدمة تجديد التوكن
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../styles/app_colors.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

// استيراد الثوابت من Dashboard لضمان الاتساق
const String PREFS_SESSION_START_TIME = 'session_start_time';
const String PREFS_INITIAL_LOAD = 'initial_dashboard_load';

class Signin extends StatefulWidget {
  const Signin({Key? key}) : super(key: key);

  @override
  State<Signin> createState() => _SigninState();
}

class _SigninState extends State<Signin> with SingleTickerProviderStateMixin {
  late ApiService _apiService;
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _isInitializing = true; // مؤشر تحميل ApiService
  String _companyType = ""; // اسم الشركة الحالية
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // رقم الهاتف للتواصل
  final String phoneNumber = "+9647712248452";

  String get username => _usernameController.text.trim();
  String get password => _passwordController.text.trim();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn,
      ),
    );
    _animationController.forward();

    // تحميل ApiService باستخدام الشركة المحفوظة
    _loadApiService();
    
    // إعادة تعيين متغير التحميل الأولي للداشبورد
    _resetInitialLoadFlag();
  }
  
  // إعادة تعيين متغير التحميل الأولي
  Future<void> _resetInitialLoadFlag() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(PREFS_INITIAL_LOAD, true);
      debugPrint("?? تم إعادة تعيين مؤشر التحميل الأولي للداشبورد");
    } catch (e) {
      debugPrint("?? خطأ في إعادة تعيين مؤشر التحميل الأولي: $e");
    }
  }

  // تحميل API مع الشركة المحفوظة
  Future<void> _loadApiService() async {
    try {
      // الحصول على ApiService مع الشركة المحفوظة
      final api = await ApiService.fromSavedCompany();

      setState(() {
        _apiService = api;
        _companyType = api.companyName;
        _isInitializing = false;
      });
    } catch (e) {
      print("خطأ في تحميل API Service: $e");
      // استخدام الشركة الافتراضية في حالة الخطأ
      setState(() {
        _apiService = ApiService(serverDomain: '');
        _companyType = _apiService.companyName;
        _isInitializing = false;
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showCompanySelector() async {
    // استخدام GetX للانتقال إلى شاشة اختيار الشركة
    final result = await Get.toNamed('/company_selector');

    // إذا تم تغيير الشركة، قم بإعادة تحميل ApiService
    if (result == true) {
      setState(() {
        _isInitializing = true;
      });
      await _loadApiService();
    }
  }

  // فتح تطبيق الهاتف للاتصال مباشرة
  Future<void> _callPhoneNumber() async {
    final Uri uri = Uri(scheme: 'tel', path: phoneNumber);
    
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        // إذا لم يمكن فتح تطبيق الهاتف، قم بالنسخ بدلاً من ذلك
        _copyPhoneNumber();
      }
    } catch (e) {
      debugPrint("خطأ في الاتصال: $e");
      _copyPhoneNumber();
    }
  }

  // نسخ رقم الهاتف 
  void _copyPhoneNumber() {
    Clipboard.setData(ClipboardData(text: phoneNumber)).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم نسخ رقم الهاتف'),
          duration: Duration(seconds: 2),
        ),
      );
    });
  }

  // التحقق من حالة الاشتراك - التابع الجديد
  Future<bool> checkSubscriptionStatus(String username, String companyType) async {
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

  // الدالة المعدلة للتعامل مع تسجيل الدخول مع التحقق من الاشتراك وتفعيل تجديد التوكن
  Future<void> _handleLogin() async {
    if (username.isEmpty || password.isEmpty) {
      _showErrorDialog("خطأ", "الرجاء إدخال اسم المستخدم وكلمة المرور");
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _apiService.login(username, password);

      if (result != null && (result["status"] == 200 || result.containsKey("token"))) {
        final token = result["token"] ?? "";
        final userId = result["id"] ?? '';
        
        // تهيئة وقت بدء الجلسة عند تسجيل الدخول بنجاح
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(PREFS_SESSION_START_TIME, DateTime.now().toIso8601String());
        
        // استخدام خدمة المصادقة لحفظ بيانات جلسة المستخدم مع كلمة المرور للتجديد التلقائي
        await AuthService.saveUserSession(
          token: token,
          username: username,
          companyType: _companyType,
          userId: userId.toString(),
          password: password, // تمرير كلمة المرور للتجديد التلقائي
        );

        // بدء خدمة تجديد التوكن التلقائي
        await TokenRefreshService().startAutoRefresh();

        // عرض رسالة تحميل للتحقق من الاشتراك
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تسجيل الدخول بنجاح. جاري التحقق من الاشتراك...'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );

        // التحقق من الاشتراك باستخدام الدالة الجديدة
        bool isSubscriptionActive = await checkSubscriptionStatus(username, _companyType);

        setState(() {
          _isLoading = false;
        });

        // توجيه المستخدم بناءً على حالة الاشتراك
        if (isSubscriptionActive) {
          // الاشتراك ساري، التوجيه إلى لوحة التحكم
          debugPrint("? تم تسجيل الدخول بنجاح والاشتراك ساري");
          
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => Dashboard(token: token)),
          );
        } else {
          // الاشتراك منتهي، التوجيه إلى شاشة انتهاء الاشتراك
          debugPrint("?? تم تسجيل الدخول لكن الاشتراك منتهي");
          
          // إيقاف خدمة تجديد التوكن إذا كان الاشتراك منتهي
          TokenRefreshService().stopAutoRefresh();
          
          // استخدام GetX للانتقال إلى شاشة انتهاء الاشتراك
          Get.offAll(() => const SubscriptionExpiredScreen());
        }
      } else {
        setState(() {
          _isLoading = false;
        });
        _showErrorDialog("فشل تسجيل الدخول", result?["message"] ?? "خطأ غير معروف");
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorDialog("خطأ", "حدث خطأ ما. الرجاء المحاولة مرة أخرى.");
      debugPrint("? خطأ أثناء تسجيل الدخول: $e");
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("حسناً"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.blue,
                Color(0xFF2E86C1), // لون متدرج أغمق للخلفية
              ],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // عنوان مركزي
                        const Align(
                          alignment: Alignment.center,
                          child: Text(
                            'تسجيل الدخول',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        
                        // زر الإعدادات في اليمين
                        Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(
                            icon: const Icon(
                              Icons.settings,
                              color: Colors.white,
                            ),
                            onPressed: _showCompanySelector,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 10,
                          offset: Offset(0, -5),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: _isInitializing
                          ? _buildLoadingWidget()
                          : _buildLoginForm(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return SizedBox(
      height: 300,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text("جاري تحميل إعدادات الاتصال..."),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Hero(
          tag: 'logo',
          child: Container(
            height: 150,
            width: 150,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(75),
            ),
            child: Image.asset("assets/images/login.png"),
          ),
        ),
        const SizedBox(height: 16),
        // عرض معلومات الشركة الحالية
        if (_companyType.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.business, size: 16, color: AppColors.blue),
                const SizedBox(width: 8),
                Text(
                  "الشركة: $_companyType",
                  style: TextStyle(color: Colors.grey.shade800, fontSize: 14),
                ),
                const Spacer(),
                InkWell(
                  onTap: _showCompanySelector,
                  child: Text(
                    "تغيير",
                    style: TextStyle(
                      color: AppColors.blue,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 24),
        // Username field with icon
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: "اسم المستخدم",
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Password field with icon
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              controller: _passwordController,
              obscureText: !_isPasswordVisible,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: "كلمة المرور",
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isPasswordVisible
                        ? Icons.visibility
                        : Icons.visibility_off,
                    color: AppColors.blue,
                  ),
                  onPressed: () {
                    setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    });
                  },
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Sign in button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.blue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  )
                : const Text(
                    "تسجيل الدخول",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 40),
        
        // معلومات التواصل
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              const Text(
                "للاستفسار والدعم الفني",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _callPhoneNumber,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.phone, color: AppColors.blue, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      phoneNumber,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppColors.blue,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.call, color: Colors.green, size: 16),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _callPhoneNumber,
                icon: const Icon(Icons.phone_in_talk, color: Colors.white),
                label: const Text(
                  "اتصل بنا الآن",
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 20),
      ],
    );
  }
}