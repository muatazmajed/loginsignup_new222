import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'screens/Dashboard.dart';
import 'screens/ompanySelectionScreen.dart';
import 'screens/signin.dart';
import 'screens/subscription_expired_screen.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/api_service.dart';
import 'services/company_configs.dart';
import 'services/global_company.dart';
import 'services/subscription_gateway.dart';
import 'services/simple_subscription_service.dart';
import 'services/auth_service.dart';
import 'styles/app_colors.dart';
import 'screens/welcome_screen.dart';
import 'screens/splash_screen.dart';

// ثوابت للإشعارات
const String NOTIFICATION_CHANNEL_ID = 'subscription_expiry_channel';
const String NOTIFICATION_CHANNEL_NAME = 'تنبيه انتهاء الاشتراك';
const String NOTIFICATION_CHANNEL_DESC = 'إشعارات خاصة بانتهاء اشتراكات المستخدمين';

// متغير عام للإشعارات
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

void main() async {
  // تأكد من تهيئة Flutter قبل استدعاء أي خدمات أصلية
  WidgetsFlutterBinding.ensureInitialized();
  
  // لف الكود الرئيسي داخل try-catch للتعامل مع أي أخطاء قد تحدث أثناء بدء التشغيل
  try {
    // تحميل الشركة المحفوظة في بداية التطبيق
    await GlobalCompany.loadSavedCompany();
    
    // تهيئة الإشعارات
    await _initNotifications();
    
    // طلب الأذونات اللازمة
    await _requestPermissions();
    
    // استرجاع حالة زيارة المستخدم للتطبيق سابقاً
    final prefs = await SharedPreferences.getInstance();
    final bool seenWelcome = prefs.getBool('seen_welcome') ?? false;
    debugPrint("👋 هل تم عرض شاشة الترحيب سابقاً؟ $seenWelcome");
    
    // تهيئة بوابة التحقق من الاشتراك
    await SubscriptionGateway.initialize();
    
    // تهيئة Workmanager للمهام الخلفية
    await _initializeWorkManager();
    
    // التحقق من حالة تسجيل الدخول
    bool isLoggedIn = await AuthService.isLoggedIn();
    
    if (isLoggedIn) {
      // المستخدم مسجل دخوله بالفعل، تحقق من حالة الاشتراك
      debugPrint("👤 المستخدم مسجل دخوله بالفعل، التحقق من حالة الاشتراك...");
      bool isSubscriptionActive = await AuthService.isSubscriptionActive();
      Map<String, String> userInfo = await AuthService.getUserInfo();
      
      if (isSubscriptionActive) {
        // الاشتراك نشط، توجيه مباشر إلى لوحة التحكم
        debugPrint("✅ الاشتراك نشط، توجيه المستخدم مباشرة إلى لوحة التحكم");
        runApp(MyApp(
          showWelcomeScreen: false,
          initialRoute: '/dashboard',
          initialToken: userInfo['token'],
        ));
      } else {
        // الاشتراك منتهي، توجيه إلى شاشة انتهاء الاشتراك
        debugPrint("⚠️ الاشتراك منتهي، توجيه المستخدم إلى شاشة انتهاء الاشتراك");
        runApp(MyApp(
          showWelcomeScreen: false,
          initialRoute: '/subscription_expired',
        ));
      }
    } else {
      // المستخدم غير مسجل دخوله، عرض شاشة الترحيب (إذا كانت المرة الأولى) أو تسجيل الدخول
      debugPrint("👤 المستخدم غير مسجل دخوله، عرض شاشة السبلاش/الترحيب");
      runApp(MyApp(showWelcomeScreen: !seenWelcome));
    }
  } catch (e) {
    // تسجيل أي خطأ قد يحدث أثناء بدء التشغيل
    debugPrint("❌ خطأ أثناء بدء التشغيل: $e");
    
    // تشغيل التطبيق رغم وجود خطأ، وعرض شاشة تسجيل الدخول مباشرة
    runApp(const MyApp(showWelcomeScreen: false));
  }
}

// دالة تهيئة Workmanager
Future<void> _initializeWorkManager() async {
  try {
    // تهيئة Workmanager
    Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false,
    );
    
    // تسجيل المهمة الدورية
    Workmanager().registerPeriodicTask(
      "checkExpiredUsersTask",
      "checkExpiredUsers",
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );
    
    debugPrint("✅ تم تهيئة Workmanager بنجاح");
  } catch (e) {
    debugPrint("❌ خطأ في تهيئة Workmanager: $e");
  }
}

// دالة تهيئة الإشعارات
Future<void> _initNotifications() async {
  try {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const DarwinInitializationSettings darwinInitializationSettings =
        DarwinInitializationSettings();
    
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: darwinInitializationSettings,
    );
    
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('تم الضغط على الإشعار: ${response.payload}');
      },
    );
    
    // إنشاء قناة الإشعارات
    await _createNotificationChannel();
    
    debugPrint("✅ تم تهيئة نظام الإشعارات");
  } catch (e) {
    debugPrint("❌ خطأ في تهيئة الإشعارات: $e");
  }
}

// دالة إنشاء قناة الإشعارات
Future<void> _createNotificationChannel() async {
  try {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      NOTIFICATION_CHANNEL_ID,
      NOTIFICATION_CHANNEL_NAME,
      description: NOTIFICATION_CHANNEL_DESC,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );
    
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
    
    debugPrint("✅ تم إنشاء قناة الإشعارات");
  } catch (e) {
    debugPrint("❌ خطأ في إنشاء قناة الإشعارات: $e");
  }
}

// دالة طلب الأذونات
Future<void> _requestPermissions() async {
  try {
    if (await Permission.notification.isDenied) {
      final status = await Permission.notification.request();
      debugPrint("📱 حالة إذن الإشعارات: $status");
    }
    
    if (await Permission.ignoreBatteryOptimizations.isDenied) {
      final status = await Permission.ignoreBatteryOptimizations.request();
      debugPrint("🔋 حالة إذن تجاهل تحسينات البطارية: $status");
    }
  } catch (e) {
    debugPrint("❌ خطأ في طلب الأذونات: $e");
  }
}

// فئة التطبيق الرئيسية
class MyApp extends StatelessWidget {
  final bool showWelcomeScreen;
  final String? initialRoute;
  final String? initialToken;
  
  const MyApp({
    Key? key, 
    required this.showWelcomeScreen, 
    this.initialRoute,
    this.initialToken,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'نظام إدارة المشتركين',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        primaryColor: AppColors.blue,
        fontFamily: 'Cairo',
        scaffoldBackgroundColor: const Color(0xFF0F172A), // تحديث لون الخلفية ليتناسب مع التصميم الجديد
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontFamily: 'Cairo'),
          bodyMedium: TextStyle(fontFamily: 'Cairo'),
          titleLarge: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
          titleMedium: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
        ),
        // إضافة سمات عصرية للتطبيق
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
            elevation: 4,
          ),
        ),
        cardTheme: CardTheme(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.blue, width: 2),
          ),
          filled: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
      // تحديد الشاشة الأولية بناءً على البارامترات
      home: _determineHomeScreen(),
      getPages: [
        GetPage(name: '/splash', page: () => SplashScreen(showWelcomeScreen: showWelcomeScreen)),
        GetPage(name: '/welcome', page: () => const WelcomeScreen()),
        GetPage(name: '/signin', page: () => const Signin()),
        GetPage(
          name: '/dashboard',
          page: () => Dashboard(token: initialToken ?? Get.arguments as String),
        ),
        GetPage(
          name: '/company_selector',
          page: () => const CompanySelector(),
        ),
        GetPage(
          name: '/subscription_expired',
          page: () => const SubscriptionExpiredScreen(),
        ),
      ],
      defaultTransition: Transition.fadeIn, // تغيير الانتقال الافتراضي للشاشات
      transitionDuration: const Duration(milliseconds: 300), // تسريع الانتقالات
    );
  }
  
  // تحديد الشاشة الرئيسية بناءً على حالة التطبيق
  Widget _determineHomeScreen() {
    if (initialRoute == '/dashboard' && initialToken != null) {
      return Dashboard(token: initialToken!);
    } else if (initialRoute == '/subscription_expired') {
      return const SubscriptionExpiredScreen();
    }
    
    // الوضع الافتراضي هو شاشة السبلاش ثم الترحيب أو الدخول
    return SplashScreen(showWelcomeScreen: showWelcomeScreen);
  }
}

// إضافة @pragma لمنع حذف الدالة عند البناء
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    print("🔄 تنفيذ مهمة التحقق من الاشتراكات");
    
    try {
      // تهيئة الإشعارات
      FlutterLocalNotificationsPlugin notifications = FlutterLocalNotificationsPlugin();
      
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      
      const DarwinInitializationSettings darwinInitializationSettings =
          DarwinInitializationSettings();
      
      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: darwinInitializationSettings,
      );
      
      await notifications.initialize(initializationSettings);
      
      // إنشاء قناة الإشعارات
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        NOTIFICATION_CHANNEL_ID,
        NOTIFICATION_CHANNEL_NAME,
        description: NOTIFICATION_CHANNEL_DESC,
        importance: Importance.high,
      );
      
      await notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
      
      if (task == "checkExpiredUsers") {
        // الحصول على بيانات المستخدم
        final prefs = await SharedPreferences.getInstance();
        final username = prefs.getString('username') ?? "";
        final companyType = prefs.getString('company_type') ?? "";
        
        if (username.isNotEmpty && companyType.isNotEmpty) {
          // التحقق من الاشتراك
          bool isSubscriptionActive = await SimpleSubscriptionService.checkSubscriptionStatus(username, companyType);
          
          if (!isSubscriptionActive) {
            print("⚠️ اشتراك المستخدم $username منتهي! إرسال إشعار...");
            
            await notifications.show(
              1000,
              "تنبيه انتهاء الاشتراك",
              "انتهت صلاحية اشتراكك، يرجى التواصل مع الإدارة للتجديد",
              const NotificationDetails(
                android: AndroidNotificationDetails(
                  NOTIFICATION_CHANNEL_ID,
                  NOTIFICATION_CHANNEL_NAME,
                  channelDescription: NOTIFICATION_CHANNEL_DESC,
                  importance: Importance.high,
                  priority: Priority.high,
                ),
              ),
            );
          } else {
            print("✅ اشتراك المستخدم $username ساري");
          }
        }
      }
    } catch (e) {
      print("❌ خطأ في المهمة الخلفية: $e");
    }
    
    return Future.value(true);
  });
}