import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:loginsignup_new/styles/app_colors.dart';
import 'package:loginsignup_new/screens/signin.dart';
import 'package:loginsignup_new/screens/dashboard.dart'; // استيراد شاشة Dashboard
import 'package:url_launcher/url_launcher.dart'; // استيراد مكتبة url_launcher للاتصال بواتساب

class SubscriptionExpiredScreen extends StatefulWidget {
  const SubscriptionExpiredScreen({Key? key}) : super(key: key);

  @override
  State<SubscriptionExpiredScreen> createState() => _SubscriptionExpiredScreenState();
}

class _SubscriptionExpiredScreenState extends State<SubscriptionExpiredScreen> {
  String _username = '';
  String _companyType = '';
  DateTime _expiryDate = DateTime.now();
  bool _isLoading = false;
  bool _isSubscriptionActive = false; // حالة الاشتراك
  
  // رقم الهاتف للتواصل
  final String _phoneNumber = '+9647808867402';

  @override
  void initState() {
    super.initState();
    _logoutUserData();
    _loadUserInfo();
    _startSubscriptionCheck(); // بدء التحقق الدوري
  }

  // بدء التحقق الدوري من حالة الاشتراك
  void _startSubscriptionCheck() {
    Future.delayed(const Duration(seconds: 5), () async {
      if (!_isSubscriptionActive) {
        bool isActive = await _checkSubscriptionStatus();
        if (isActive) {
          setState(() {
            _isSubscriptionActive = true;
          });
          // تحويل المستخدم إلى Dashboard
          Get.offAll(() => Dashboard(token: 'your_token_here')); // استبدل 'your_token_here' بالتوكن الفعلي
        } else {
          _startSubscriptionCheck(); // الاستمرار في التحقق
        }
      }
    });
  }

  // التحقق من حالة الاشتراك
  Future<bool> _checkSubscriptionStatus() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      bool isExpired = prefs.getBool('subscription_expired') ?? true;
      return !isExpired; // إذا لم يكن منتهيًا، يعتبر نشطًا
    } catch (e) {
      debugPrint("❌ خطأ أثناء التحقق من حالة الاشتراك: $e");
      return false;
    }
  }

  // تسجيل خروج المستخدم وحفظ حالة انتهاء الاشتراك
  Future<void> _logoutUserData() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('subscription_expired', true);
      await prefs.remove('authToken');
      await prefs.remove('api_token');
    } catch (e) {
      debugPrint("❌ خطأ أثناء تسجيل خروج المستخدم: $e");
    }
  }

  // تحميل معلومات المستخدم
  void _loadUserInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _username = prefs.getString('username') ?? 'المستخدم';
        _companyType = prefs.getString('company_type') ?? 'الشركة';
        String? expiryDateStr = prefs.getString('subscription_end_date');
        if (expiryDateStr != null) {
          try {
            _expiryDate = DateTime.parse(expiryDateStr);
          } catch (e) {
            debugPrint("❌ خطأ في تحليل تاريخ انتهاء الاشتراك: $e");
          }
        }
      });
    } catch (e) {
      debugPrint("❌ خطأ في تحميل معلومات المستخدم: $e");
    }
  }

  // العودة إلى شاشة تسجيل الدخول
  void _backToLogin() {
    Get.offAll(() => const Signin());
  }
  
  // فتح واتساب مع الرقم المحدد
  Future<void> _openWhatsApp() async {
    String message = 'مرحباً، أنا ${_username} من ${_companyType}. أرغب في تجديد اشتراكي في التطبيق.';
    String encodedMessage = Uri.encodeComponent(message);
    String whatsappUrl = "https://wa.me/$_phoneNumber?text=$encodedMessage";
    
    try {
      await launchUrl(Uri.parse(whatsappUrl), mode: LaunchMode.externalApplication);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('لا يمكن فتح واتساب. يرجى التأكد من تثبيت التطبيق.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // فتح تطبيق الهاتف للاتصال
  Future<void> _makePhoneCall() async {
    String phoneUrl = "tel:$_phoneNumber";
    try {
      await launchUrl(Uri.parse(phoneUrl));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('لا يمكن فتح تطبيق الهاتف. يرجى التأكد من توفر التطبيق.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // رمز انتهاء الاشتراك
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.access_time_filled_rounded,
                    size: 60,
                    color: Colors.red.shade500,
                  ),
                ),
                const SizedBox(height: 24),
                
                // عنوان
                Text(
                  'انتهت صلاحية الاشتراك',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),
                const SizedBox(height: 16),
                
                // رسالة
                Text(
                  'عذراً، لقد انتهت صلاحية اشتراكك. يرجى التواصل مع الإدارة لتجديد الاشتراك.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 12),
                
                // معلومات المستخدم
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.person, color: Colors.grey.shade600, size: 20),
                          const SizedBox(width: 8),
                          Text('المستخدم:', style: TextStyle(color: Colors.grey.shade600)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_username, 
                              style: const TextStyle(fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.business, color: Colors.grey.shade600, size: 20),
                          const SizedBox(width: 8),
                          Text('الشركة:', style: TextStyle(color: Colors.grey.shade600)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_companyType, 
                              style: const TextStyle(fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // رسالة تفاعلية
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'لتفعيل الاشتراك، يرجى الضغط على الرابط أدناه للتواصل عبر واتساب أو الاتصال بالرقم المذكور:',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.blue.shade800,
                        ),
                      ),
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: _openWhatsApp,
                        child: Text(
                          'اضغط هنا للتواصل عبر واتساب',
                          style: TextStyle(
                            color: Colors.blue.shade800,
                            decoration: TextDecoration.underline,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _makePhoneCall,
                        child: Text(
                          'أو اضغط هنا للاتصال مباشرة: $_phoneNumber',
                          style: TextStyle(
                            color: Colors.blue.shade800,
                            decoration: TextDecoration.underline,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // زر تسجيل الخروج
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _backToLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.blue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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
                          'العودة لتسجيل الدخول',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}