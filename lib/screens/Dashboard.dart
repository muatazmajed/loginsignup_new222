import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:loginsignup_new/screens/speed_test_service.dart';
import 'package:loginsignup_new/screens/subscription_expired_screen.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/api_service.dart';
import '../services/ping_service.dart';
import '../services/global_company.dart';
import '../services/simple_subscription_service.dart';
import '../services/token_refresh_service.dart';
import 'online_users_screen.dart';
import 'all_users_screen.dart';
import 'expired_users_screen.dart';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'package:intl/date_symbol_data_local.dart';
import 'package:loginsignup_new/screens/signin.dart';
import 'package:loginsignup_new/widgets/custom_drawer.dart';
import 'package:http/http.dart' as http;

// Constants for notification channels
const String WELCOME_CHANNEL_ID = 'welcome_channel';
const String WELCOME_CHANNEL_NAME = 'ترحيب بالمستخدم';
const String WELCOME_CHANNEL_DESC = 'إشعارات ترحيبية للمستخدم عند أول تسجيل دخول';

const String SUBSCRIPTION_CHANNEL_ID = 'subscription_expiry_channel';
const String SUBSCRIPTION_CHANNEL_NAME = 'تنبيه انتهاء الاشتراك';
const String SUBSCRIPTION_CHANNEL_DESC = 'إشعارات خاصة بانتهاء اشتراكات المستخدمين';

// إضافة ثابت لمدة الجلسة القصوى (4 ساعات)
const int MAX_SESSION_DURATION_HOURS = 4;
const String PREFS_SESSION_START_TIME = 'session_start_time';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// مفاتيح التخزين المحلي للبيانات
const String PREFS_ONLINE_USERS = 'cached_online_users';
const String PREFS_TOTAL_USERS = 'cached_total_users';
const String PREFS_OFFLINE_USERS = 'cached_offline_users';
const String PREFS_FACEBOOK_PING = 'cached_facebook_ping';
const String PREFS_GOOGLE_PING = 'cached_google_ping';
const String PREFS_TIKTOK_PING = 'cached_tiktok_ping';
const String PREFS_LAST_UPDATE_TIME = 'cached_last_update_time';
const String PREFS_ALL_USERS_DATA = 'cached_all_users_data';
const String PREFS_ONLINE_USERS_DATA = 'cached_online_users_data';
const String PREFS_EXPIRED_USERS_DATA = 'cached_expired_users_data';
const String PREFS_TOKEN_LAST_CHECK = 'token_last_check_time';

// Singleton class to store and share data across screens
class DashboardDataService {
  static final DashboardDataService _instance = DashboardDataService._internal();
  
  factory DashboardDataService() {
    return _instance;
  }
  
  DashboardDataService._internal();
  
  // User data
  String currentUserName = "جارٍ التحميل...";
  String currentUserRole = "مدير النظام";
  String currentUserEmail = "";
  String? userAvatarUrl;
  
  // Stats data
  int onlineUsers = 0;
  int totalUsers = 0;
  int offlineUsers = 0;
  int facebookPing = -1;
  int googlePing = -1;
  int tiktokPing = -1;
  DateTime lastUpdateTime = DateTime.now();
  
  // Data caching
  List<dynamic> cachedAllUsers = [];
  List<dynamic> cachedOnlineUsers = [];
  List<dynamic> cachedExpiredUsers = [];
  bool hasLocalData = false;
  
  // Loading state
  bool isLoading = true;
  String errorMessage = "";
  
  // API Service
  ApiService? apiService;
  
  // حفظ البيانات في التخزين المحلي
  Future<void> saveToLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(PREFS_ONLINE_USERS, onlineUsers);
      await prefs.setInt(PREFS_TOTAL_USERS, totalUsers);
      await prefs.setInt(PREFS_OFFLINE_USERS, offlineUsers);
      await prefs.setInt(PREFS_FACEBOOK_PING, facebookPing);
      await prefs.setInt(PREFS_GOOGLE_PING, googlePing);
      await prefs.setInt(PREFS_TIKTOK_PING, tiktokPing);
      await prefs.setString(PREFS_LAST_UPDATE_TIME, lastUpdateTime.toIso8601String());
      
      // حفظ بيانات المستخدمين كـ JSON إذا كانت متوفرة
      if (cachedAllUsers.isNotEmpty) {
        await prefs.setString(PREFS_ALL_USERS_DATA, jsonEncode(cachedAllUsers));
      }
      if (cachedOnlineUsers.isNotEmpty) {
        await prefs.setString(PREFS_ONLINE_USERS_DATA, jsonEncode(cachedOnlineUsers));
      }
      if (cachedExpiredUsers.isNotEmpty) {
        await prefs.setString(PREFS_EXPIRED_USERS_DATA, jsonEncode(cachedExpiredUsers));
      }
      
      hasLocalData = true;
      debugPrint("? تم حفظ بيانات Dashboard في التخزين المحلي");
    } catch (e) {
      debugPrint("? خطأ في حفظ البيانات في التخزين المحلي: $e");
    }
  }
  
  // قراءة البيانات من التخزين المحلي
  Future<bool> loadFromLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // التحقق من وجود بيانات مخزنة
      if (!prefs.containsKey(PREFS_ONLINE_USERS)) {
        return false;
      }
      
      onlineUsers = prefs.getInt(PREFS_ONLINE_USERS) ?? 0;
      totalUsers = prefs.getInt(PREFS_TOTAL_USERS) ?? 0;
      offlineUsers = prefs.getInt(PREFS_OFFLINE_USERS) ?? 0;
      facebookPing = prefs.getInt(PREFS_FACEBOOK_PING) ?? -1;
      googlePing = prefs.getInt(PREFS_GOOGLE_PING) ?? -1;
      tiktokPing = prefs.getInt(PREFS_TIKTOK_PING) ?? -1;
      
      String? lastUpdateTimeStr = prefs.getString(PREFS_LAST_UPDATE_TIME);
      if (lastUpdateTimeStr != null) {
        lastUpdateTime = DateTime.parse(lastUpdateTimeStr);
      }
      
      // قراءة بيانات المستخدمين المخزنة
      String? allUsersJson = prefs.getString(PREFS_ALL_USERS_DATA);
      if (allUsersJson != null) {
        cachedAllUsers = jsonDecode(allUsersJson);
      }
      
      String? onlineUsersJson = prefs.getString(PREFS_ONLINE_USERS_DATA);
      if (onlineUsersJson != null) {
        cachedOnlineUsers = jsonDecode(onlineUsersJson);
      }
      
      String? expiredUsersJson = prefs.getString(PREFS_EXPIRED_USERS_DATA);
      if (expiredUsersJson != null) {
        cachedExpiredUsers = jsonDecode(expiredUsersJson);
      }
      
      hasLocalData = true;
      debugPrint("? تم تحميل بيانات Dashboard من التخزين المحلي");
      return true;
    } catch (e) {
      debugPrint("? خطأ في تحميل البيانات من التخزين المحلي: $e");
      return false;
    }
  }
  
  // تحقق من صلاحية البيانات المخزنة
  bool shouldRefreshData() {
    if (!hasLocalData) {
      return true;
    }
    
    // تحديث البيانات إذا مر عليها أكثر من 5 دقائق
    final timeDifference = DateTime.now().difference(lastUpdateTime);
    return timeDifference.inMinutes >= 5;
  }
}

class Dashboard extends StatefulWidget {
  final String token;

  const Dashboard({Key? key, required this.token}) : super(key: key);

  @override
  _DashboardState createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> with WidgetsBindingObserver {
  // Services and state
  late ApiService _apiService;
  final PingService _pingService = PingService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  
  // Access to shared data service
  final DashboardDataService _dataService = DashboardDataService();
  
  // Timers
  late Timer _timer;
  late Timer _tokenCheckTimer; // مؤقت جديد للتحقق من صلاحية التوكن
  bool _isRefreshingData = false;
  int _selectedIndex = 0;

  // App colors
  final Color _primaryColor = const Color(0xFF3B82F6);
  final Color _secondaryColor = const Color(0xFF10B981);
  final Color _accentColor = const Color(0xFFF59E0B);
  final Color _backgroundColor = const Color(0xFF0F172A);
  final Color _surfaceColor = const Color(0xFF1E293B);
  final Color _cardColor = const Color(0xFF334155);
  final Color _textColor = Colors.white;

  // بيانات الصفحات المتنقل إليها
  List<dynamic> _allUsersData = [];
  List<dynamic> _onlineUsersData = [];
  List<dynamic> _expiredUsersData = [];
  
  // حالة التوكن
  String _currentToken = "";
  bool _isTokenRefreshing = false;

  @override
  void initState() {
    super.initState();
    
    // تسجيل التوكن الحالي للمقارنة لاحقًا
    _currentToken = widget.token;
    
    // Initialize Arabic date formatting
    initializeDateFormatting('ar', null);
    
    // Add app lifecycle observer
    WidgetsBinding.instance.addObserver(this);

    // Initialize ApiService if not already initialized
    if (_dataService.apiService == null) {
      _initApiService();
    } else {
      _apiService = _dataService.apiService!;
    }
    
    // التحقق ما إذا كانت جلسة موجودة بالفعل
    SharedPreferences.getInstance().then((prefs) {
      // إذا لم يكن هناك وقت بداية للجلسة، قم بتهيئته
      if (!prefs.containsKey(PREFS_SESSION_START_TIME)) {
        prefs.setString(PREFS_SESSION_START_TIME, DateTime.now().toIso8601String());
        debugPrint("? تم تسجيل بداية جلسة جديدة");
      } else {
        // التحقق مما إذا كانت الجلسة الحالية تجاوزت المدة القصوى
        String sessionStartTimeStr = prefs.getString(PREFS_SESSION_START_TIME)!;
        DateTime sessionStartTime = DateTime.parse(sessionStartTimeStr);
        DateTime now = DateTime.now();
        Duration sessionDuration = now.difference(sessionStartTime);
        
        if (sessionDuration.inHours >= MAX_SESSION_DURATION_HOURS) {
          debugPrint("? تم اكتشاف جلسة منتهية عند بدء التطبيق");
          // إعادة تعيين وقت الجلسة وإعادة التوجيه إلى صفحة تسجيل الدخول
          prefs.remove(PREFS_SESSION_START_TIME);
          Future.delayed(Duration(seconds: 1), () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("انتهت مدة الجلسة، يرجى إعادة تسجيل الدخول"),
                backgroundColor: Colors.red,
              ),
            );
            Future.delayed(Duration(seconds: 2), () {
              Get.offAll(() => Signin());
            });
          });
          return;
        }
        
        debugPrint("? استئناف جلسة سابقة. الوقت المتبقي: ${MAX_SESSION_DURATION_HOURS - sessionDuration.inHours} ساعات");
      }
    });
    
    // Initialize notifications and permissions (only once)
    _initNotifications();
    _requestPermissions();
    
    // Save token and initialize services
    _saveToken();
    
    // تأكيد من صلاحية التوكن وبدء خدمة التجديد التلقائي
    _startTokenRefreshService();
    
    // إضافة مؤقت للتحقق من صلاحية التوكن كل 10 دقائق
    _setupTokenCheckTimer();

    // Check subscription status before loading data
    _checkSubscriptionStatus();

    // محاولة تحميل البيانات من التخزين المحلي أولاً
    _loadCachedData().then((hasLocalData) {
      if (!hasLocalData || _dataService.shouldRefreshData()) {
        // إذا لم تكن هناك بيانات محلية أو كانت قديمة، قم بتحميل البيانات من الخادم
        _fetchData();
      } else {
        // استخدام البيانات المخزنة محليًا
        setState(() {
          _dataService.isLoading = false;
        });
      }
    });
    
    // Start timer for data refresh every 5 minutes (300 seconds)
    _startTimer();

    // Load user profile and check for first login
    _loadUserProfile();
    _checkFirstLoginAndShowWelcomeNotification();

    // Check for expired users once after startup
    Future.delayed(const Duration(seconds: 3), () {
      _checkExpiredUsersOnce();
    });
  }

  // بدء خدمة تجديد التوكن التلقائي
  void _startTokenRefreshService() async {
    try {
      debugPrint("?? بدء خدمة تجديد التوكن التلقائي...");
      
      // تأكد من أن خدمة تجديد التوكن ليست نشطة بالفعل
      final tokenService = TokenRefreshService();
      if (tokenService.isActive) {
        debugPrint("?? خدمة تجديد التوكن نشطة بالفعل");
      } else {
        // بدء الخدمة
        await tokenService.startAutoRefresh();
        debugPrint("? تم بدء خدمة تجديد التوكن التلقائي بنجاح");
      }
      
      // تنفيذ تحقق فوري من صلاحية التوكن
      _validateToken();
    } catch (e) {
      debugPrint("? خطأ في بدء خدمة تجديد التوكن: $e");
    }
  }
  
  // إعداد مؤقت للتحقق من صلاحية التوكن
  void _setupTokenCheckTimer() {
    _tokenCheckTimer = Timer.periodic(Duration(minutes: 10), (timer) {
      _validateToken();
    });
    debugPrint("?? تم إعداد مؤقت التحقق من صلاحية التوكن (كل 10 دقائق)");
  }
  
  // التحقق من صلاحية التوكن
  Future<void> _validateToken() async {
    // تجنب تداخل عمليات التحقق
    if (_isTokenRefreshing) {
      debugPrint("?? جاري بالفعل التحقق من صلاحية التوكن، تم تجاهل الطلب");
      return;
    }
    
    _isTokenRefreshing = true;
    debugPrint("?? جارٍ التحقق من صلاحية التوكن...");
    
    try {
      // تحميل التوكن المخزن
      final prefs = await SharedPreferences.getInstance();
      final storedToken = prefs.getString('api_token');
      
      // التحقق من وجود التوكن
      if (storedToken == null || storedToken.isEmpty) {
        debugPrint("?? لا يوجد توكن مخزن!");
        _isTokenRefreshing = false;
        _redirectToLogin();
        return;
      }
      
      // التحقق من وقت الجلسة
      String? sessionStartTimeStr = prefs.getString(PREFS_SESSION_START_TIME);
      if (sessionStartTimeStr == null) {
        // إذا لم يكن وقت بدء الجلسة مسجلاً، قم بتهيئته
        await prefs.setString(PREFS_SESSION_START_TIME, DateTime.now().toIso8601String());
      } else {
        // التحقق مما إذا كانت الجلسة تجاوزت MAX_SESSION_DURATION_HOURS
        DateTime sessionStartTime = DateTime.parse(sessionStartTimeStr);
        DateTime now = DateTime.now();
        Duration sessionDuration = now.difference(sessionStartTime);
        
        if (sessionDuration.inHours >= MAX_SESSION_DURATION_HOURS) {
          debugPrint("?? تم تجاوز الحد الأقصى لمدة الجلسة (${MAX_SESSION_DURATION_HOURS} ساعات)");
          _isTokenRefreshing = false;
          
          // عرض رسالة للمستخدم
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("انتهت مدة الجلسة المسموح بها، يرجى إعادة تسجيل الدخول"),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
          
          // إعادة التوجيه إلى صفحة تسجيل الدخول
          Future.delayed(Duration(seconds: 2), () {
            _redirectToLogin();
          });
          return;
        }
      }
      
      // التحقق من تطابق التوكن مع التوكن الحالي
      if (storedToken != _currentToken) {
        debugPrint("?? التوكن المخزن مختلف عن التوكن الحالي!");
        _currentToken = storedToken; // تحديث التوكن المحلي
      }
      
      // تسجيل وقت التحقق من التوكن
      await prefs.setString(PREFS_TOKEN_LAST_CHECK, DateTime.now().toIso8601String());
      
      // التحقق من صلاحية التوكن مع الخادم
      final isValid = await _apiService.testTokenValidity(storedToken);
      
      if (!isValid) {
        debugPrint("?? التوكن غير صالح، محاولة تجديد التوكن...");
        final refreshed = await TokenRefreshService().forceRefreshNow();
        
        if (!refreshed) {
          debugPrint("? فشل تجديد التوكن، إعادة توجيه لتسجيل الدخول");
          _isTokenRefreshing = false;
          _redirectToLogin();
          return;
        } else {
          // تحديث التوكن المحلي
          _currentToken = prefs.getString('api_token') ?? _currentToken;
          debugPrint("? تم تجديد التوكن بنجاح");
        }
      } else {
        debugPrint("? التوكن صالح");
      }
    } catch (e) {
      debugPrint("? خطأ في التحقق من صلاحية التوكن: $e");
      // محاولة تجديد التوكن في حالة الخطأ
      try {
        final refreshed = await TokenRefreshService().forceRefreshNow();
        if (!refreshed) {
          _isTokenRefreshing = false;
          _redirectToLogin();
          return;
        }
      } catch (refreshError) {
        debugPrint("? خطأ في تجديد التوكن: $refreshError");
        _isTokenRefreshing = false;
        _redirectToLogin();
        return;
      }
    }
    
    _isTokenRefreshing = false;
  }
  
  // إعادة التوجيه لصفحة تسجيل الدخول
  void _redirectToLogin() {
    debugPrint("?? إعادة توجيه لصفحة تسجيل الدخول بسبب مشكلة في التوكن");
    
    // عرض رسالة للمستخدم قبل إعادة التوجيه
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("انتهت صلاحية الجلسة، يرجى إعادة تسجيل الدخول"),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
    
    // إيقاف خدمة تجديد التوكن
    TokenRefreshService().stopAutoRefresh();
    
    // إعادة تعيين وقت بداية الجلسة
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove(PREFS_SESSION_START_TIME);
    });
    
    // تأخير قليل قبل إعادة التوجيه
    Future.delayed(Duration(seconds: 2), () {
      Get.offAll(() => Signin());
    });
  }

  // Load cached data from local storage
  Future<bool> _loadCachedData() async {
    bool hasLocalData = await _dataService.loadFromLocalStorage();
    
    if (hasLocalData) {
      // استخدام البيانات المخزنة للصفحات الأخرى
      _allUsersData = _dataService.cachedAllUsers;
      _onlineUsersData = _dataService.cachedOnlineUsers;
      _expiredUsersData = _dataService.cachedExpiredUsers;
      
      setState(() {
        // تحديث الواجهة باستخدام البيانات المخزنة
      });
    }
    
    return hasLocalData;
  }
  
  @override
  void dispose() {
    // Remove app lifecycle observer
    WidgetsBinding.instance.removeObserver(this);
    
    // Cancel timers
    _timer.cancel();
    _tokenCheckTimer.cancel();
    
    // Note: We don't stop the token refresh service here
    // It will continue running in the background
    // It will only be stopped on logout or subscription expiry
    
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (state == AppLifecycleState.paused) {
      // App went to background, cancel timer to save system resources
      _timer.cancel();
      _tokenCheckTimer.cancel();
      
      // Don't stop token refresh service as it should work in background
    } else if (state == AppLifecycleState.resumed) {
      // App is back to foreground, restart timers
      _startTimer();
      _setupTokenCheckTimer();
      
      // التحقق فوراً من صلاحية التوكن عند استئناف التطبيق
      _validateToken();
      
      // Check subscription status
      _checkSubscriptionStatus();
      
      // تحديث البيانات إذا مر أكثر من 5 دقائق على آخر تحديث
      if (_dataService.shouldRefreshData()) {
        _fetchData();
      }
    }
  }

  // Initialize ApiService
  void _initApiService() {
    try {
      if (GlobalCompany.isCompanySet()) {
        debugPrint("Using global company: ${GlobalCompany.getCompanyName()}");
        _apiService = ApiService.fromCompanyConfig(GlobalCompany.getCompany());
      } else {
        debugPrint("Global company not set, using default");
        _apiService = ApiService(serverDomain: '');
      }
      _apiService.printServiceInfo();
      
      // Save ApiService in shared service
      _dataService.apiService = _apiService;
    } catch (e) {
      debugPrint("Error initializing ApiService: $e");
      _apiService = ApiService(serverDomain: '');
      _dataService.apiService = _apiService;
    }
  }

  // Check subscription status
  Future<void> _checkSubscriptionStatus() async {
    try {
      debugPrint("Checking subscription status...");
      final prefs = await SharedPreferences.getInstance();
      String? username = prefs.getString('username');
      String? companyType = prefs.getString('company_type');

      if (username == null || username.isEmpty || companyType == null || companyType.isEmpty) {
        debugPrint("Insufficient information to check subscription");
        return;
      }

      bool isSubscriptionActive = await SimpleSubscriptionService.checkSubscriptionStatus(username, companyType);

      if (!isSubscriptionActive) {
        debugPrint("Subscription expired - redirecting to expired screen");
        _navigateToExpiredScreen();
        return;
      }

      debugPrint("Subscription is active");
    } catch (e) {
      debugPrint("Error checking subscription status: $e");
    }
  }

  // Navigate to expired subscription screen
  void _navigateToExpiredScreen() {
    // Stop token refresh service on subscription expiry
    TokenRefreshService().stopAutoRefresh();
    
    Get.offAll(() => const SubscriptionExpiredScreen());
  }

  // Start data refresh timer (every 5 minutes)
  void _startTimer() {
    // Set refresh interval to 5 minutes (300 seconds)
    _timer = Timer.periodic(const Duration(seconds: 300), (timer) {
      _fetchData();
      
      // Check subscription every 3 cycles (15 minutes)
      if (timer.tick % 3 == 0) {
        _periodicSubscriptionCheck();
      }
    });
  }

  // Periodic subscription check
  Future<void> _periodicSubscriptionCheck() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? username = prefs.getString('username');
      String? companyType = prefs.getString('company_type');

      if (username == null || username.isEmpty || companyType == null || companyType.isEmpty) {
        debugPrint("Insufficient information for periodic subscription check");
        return;
      }

      bool isSubscriptionActive = await SimpleSubscriptionService.checkSubscriptionStatus(username, companyType);

      if (!isSubscriptionActive) {
        debugPrint("Subscription expiry detected during use");
        _navigateToExpiredScreen();
      }
    } catch (e) {
      debugPrint("Error during periodic subscription check: $e");
    }
  }

  // Save token and setup background tasks
  Future<void> _saveToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('api_token', widget.token);
      await prefs.setString('authToken', widget.token);
      await prefs.setString('token_last_refresh', DateTime.now().toIso8601String());
      
      debugPrint("Token saved: ${widget.token.substring(0, min(10, widget.token.length))}...");
      await _registerBackgroundTasks();
    } catch (e) {
      debugPrint("Error saving token: $e");
    }
  }

  // Register background tasks
  Future<void> _registerBackgroundTasks() async {
    try {
      await Workmanager().cancelAll();
      await Workmanager().registerPeriodicTask(
        "checkExpiredUsersTask",
        "checkExpiredUsers",
        frequency: const Duration(minutes: 15),
        constraints: Constraints(
          networkType: NetworkType.connected,
        ),
        existingWorkPolicy: ExistingWorkPolicy.replace,
        backoffPolicy: BackoffPolicy.linear,
        backoffPolicyDelay: const Duration(minutes: 1),
      );

      await Workmanager().registerPeriodicTask(
        "checkCurrentUserSubscriptionTask",
        "checkCurrentUserSubscription",
        frequency: const Duration(hours: 1),
        constraints: Constraints(
          networkType: NetworkType.connected,
        ),
        existingWorkPolicy: ExistingWorkPolicy.replace,
      );

      debugPrint("Background tasks registered successfully");
    } catch (e) {
      debugPrint("Error registering background tasks: $e");
    }
  }

  // Load user profile
  Future<void> _loadUserProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? username = prefs.getString('username');

      if (username != null && username.isNotEmpty) {
        setState(() {
          _dataService.currentUserName = username;
        });

        try {
          // Additional user data can be fetched from server (optional)
        } catch (apiError) {
          debugPrint("Failed to fetch additional user data: $apiError");
        }
      } else {
        debugPrint("Username not found in local storage");
      }
    } catch (e) {
      debugPrint("Error loading user profile: $e");
    }
  }

  // Logout
  Future<void> _logout() async {
    try {
      // Stop token refresh service on logout
      await TokenRefreshService().stopAutoRefresh();
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('api_token');
      await prefs.remove('authToken');
      await prefs.remove('username');
      await prefs.remove('user_password'); // Remove stored password
      await prefs.remove('user_data');
      await prefs.remove(PREFS_SESSION_START_TIME); // حذف وقت بدء الجلسة
      await Workmanager().cancelAll();
      
      Get.offAll(() => Signin());
    } catch (e) {
      debugPrint("Error during logout: $e");
      Get.offAll(() => Signin());
    }
  }

  // Fetch data with improved token handling
  Future<void> _fetchData() async {
    // Avoid overlapping data refresh operations
    if (_isRefreshingData) return;
    _isRefreshingData = true;
    
    debugPrint("Starting data refresh...");
    try {
      setState(() {
        _dataService.isLoading = true;
        _dataService.errorMessage = "";
      });

      // التحقق من صلاحية التوكن قبل جلب البيانات
      final prefs = await SharedPreferences.getInstance();
      final storedToken = prefs.getString('api_token');
      
      // التحقق من وجود التوكن وتطابقه
      if (storedToken == null || storedToken.isEmpty) {
        debugPrint("?? لا يوجد توكن مخزن، محاولة تجديد التوكن...");
        final refreshed = await TokenRefreshService().forceRefreshNow();
        
        if (!refreshed) {
          throw Exception("فشل تجديد التوكن، يرجى إعادة تسجيل الدخول");
        }
        
        // تحديث التوكن المحلي
        _currentToken = prefs.getString('api_token') ?? "";
      } else if (storedToken != _currentToken) {
        // تحديث التوكن المحلي إذا كان هناك اختلاف
        debugPrint("?? تم اكتشاف تغيير في التوكن، تحديث التوكن المحلي");
        _currentToken = storedToken;
      }

      await _fetchUserStats();
      await _fetchPings();
      
      // أيضًا تحميل بيانات المستخدمين لتخزينها للصفحات الأخرى
      await _prefetchUsersData();
      
      setState(() {
        _dataService.lastUpdateTime = DateTime.now();
        _dataService.isLoading = false;
      });
      
      // حفظ البيانات المحدثة في التخزين المحلي
      await _dataService.saveToLocalStorage();
      
      debugPrint("Data updated successfully at: ${DateFormat('HH:mm:ss').format(_dataService.lastUpdateTime)}");
    } catch (e) {
      debugPrint("? خطأ عام في تحديث البيانات: $e");
      
      // التحقق مما إذا كان الخطأ متعلقًا بالتوكن
      if (_isTokenError(e)) {
        debugPrint("?? تم اكتشاف خطأ متعلق بالتوكن، محاولة تجديد التوكن");
        
        setState(() {
          _dataService.isLoading = false;
        });
        
        // محاولة تجديد التوكن
        try {
          final refreshed = await TokenRefreshService().forceRefreshNow();
          
          if (refreshed) {
            // تحديث التوكن المحلي
            final prefs = await SharedPreferences.getInstance();
            _currentToken = prefs.getString('api_token') ?? "";
            
            debugPrint("? تم تجديد التوكن بنجاح، إعادة محاولة جلب البيانات");
            
            // انتظار لحظة قبل إعادة المحاولة
            await Future.delayed(Duration(seconds: 1));
            
            // إعادة تعيين حالة التحديث
            _isRefreshingData = false;
            
            // إعادة محاولة جلب البيانات بالتوكن الجديد
            _fetchData();
            return;
          } else {
            debugPrint("? فشل تجديد التوكن، إعادة توجيه لصفحة تسجيل الدخول");
            _isRefreshingData = false;
            setState(() {
              _dataService.errorMessage = "انتهت صلاحية الجلسة، يرجى إعادة تسجيل الدخول";
              _dataService.isLoading = false;
            });
            
            // إعطاء المستخدم وقتًا لرؤية الرسالة قبل إعادة التوجيه
            Future.delayed(Duration(seconds: 3), () {
              _redirectToLogin();
            });
            return;
          }
        } catch (refreshError) {
          debugPrint("? خطأ أثناء محاولة تجديد التوكن: $refreshError");
          _redirectToLogin();
          _isRefreshingData = false;
          return;
        }
      }
      
      // خطأ عام غير متعلق بالتوكن
      setState(() {
        _dataService.isLoading = false;
        _dataService.errorMessage = "خطأ في جلب البيانات: $e";
        _isRefreshingData = false;
      });
    }
  }

  // دالة مساعدة للتحقق من أخطاء التوكن
  bool _isTokenError(dynamic error) {
    if (error == null) return false;
    
    final errorString = error.toString().toLowerCase();
    return errorString.contains("unauthorized") || 
           errorString.contains("unauthenticated") ||
           errorString.contains("token") ||
           errorString.contains("auth") ||
           errorString.contains("401") ||
           errorString.contains("403");
  }

  // تحميل مسبق لبيانات المستخدمين للصفحات الأخرى
  Future<void> _prefetchUsersData() async {
    try {
      // التحقق من صلاحية التوكن قبل جلب البيانات
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('api_token') ?? _currentToken;
      
      // تحميل بيانات جميع المستخدمين
      final allUsers = await _apiService.getAllUsers(token);
      _allUsersData = allUsers;
      _dataService.cachedAllUsers = allUsers;
      
      // نستخدم بيانات المستخدمين المتصلين التي تم تحميلها بالفعل
      _onlineUsersData = _dataService.cachedOnlineUsers;
      
      // استخلاص المستخدمين منتهي الاشتراك
      List<dynamic> expiredUsers = [];
      final now = DateTime.now();
      
      for (var user in allUsers) {
        if (user['expiration'] != null && user['expiration'].toString().isNotEmpty) {
          try {
            final expiryDate = DateFormat("yyyy-MM-dd HH:mm:ss").parse(user['expiration'].toString());
            if (now.isAfter(expiryDate)) {
              expiredUsers.add(user);
            }
          } catch (e) {
            debugPrint("Error parsing expiry date: $e");
          }
        }
      }
      
      _expiredUsersData = expiredUsers;
      _dataService.cachedExpiredUsers = expiredUsers;
      
    } catch (e) {
      // التحقق مما إذا كان الخطأ متعلقًا بالتوكن
      if (_isTokenError(e)) {
        debugPrint("? خطأ في الوصول للبيانات: خطأ في التوكن");
        throw Exception("خطأ في المصادقة: $e");
      }
      debugPrint("? خطأ في تحميل بيانات المستخدمين: $e");
      throw e; // إعادة إلقاء الخطأ ليتم معالجته في _fetchData
    }
  }

  // Fetch user statistics with improved token handling
  Future<void> _fetchUserStats() async {
    try {
      debugPrint("جاري جلب إحصائيات المستخدمين...");
      
      // استخدام التوكن المحدث
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('api_token') ?? _currentToken;
      
      debugPrint("Using token: ${token.length > 20 ? token.substring(0, 20) + '...' : token}");

      try {
        final testUrl = Uri.parse(_apiService.baseUrl);
        debugPrint("Testing server connection: $testUrl");
        final testResponse = await http.get(testUrl).timeout(const Duration(seconds: 10));
        debugPrint("Server connection test response: ${testResponse.statusCode}");

        if (testResponse.statusCode != 200) {
          debugPrint("Server responded with unexpected status code: ${testResponse.statusCode}");
          debugPrint("Response content: ${testResponse.body.length > 100 ? testResponse.body.substring(0, 100) + '...' : testResponse.body}");
        }
      } catch (e) {
        debugPrint("? فشل اختبار الاتصال بالخادم: $e");
      }

      debugPrint("جاري جلب المستخدمين المتصلين...");
      final onlineResponse = await _apiService.getOnlineUsers(token);
      debugPrint("تم جلب ${onlineResponse.length} مستخدم متصل");
      
      // تخزين بيانات المستخدمين المتصلين
      _onlineUsersData = onlineResponse;
      _dataService.cachedOnlineUsers = onlineResponse;

      debugPrint("جاري جلب إجمالي المستخدمين...");
      final totalResponse = await _apiService.getTotalUsers(token);
      debugPrint("تم جلب $totalResponse إجمالي المستخدمين");

      setState(() {
        _dataService.onlineUsers = onlineResponse.length;
        _dataService.totalUsers = totalResponse;
        _dataService.offlineUsers = totalResponse - onlineResponse.length;
        _dataService.errorMessage = "";
      });
    } catch (e) {
      debugPrint("? خطأ في جلب إحصائيات المستخدمين: $e");
      
      // التحقق مما إذا كان الخطأ متعلقًا بالتوكن
      if (_isTokenError(e)) {
        debugPrint("? خطأ في المصادقة: $e");
        throw Exception("خطأ في المصادقة: $e");
      }
      
      setState(() {
        _dataService.errorMessage = "خطأ في جلب البيانات: $e";
      });
      throw e; // إعادة إلقاء الخطأ ليتم معالجته في _fetchData
    }
  }

  // Measure response times
  Future<void> _fetchPings() async {
    try {
      debugPrint("جاري قياس أوقات الاستجابة...");
      int fbPing = await _pingService.pingHost("facebook.com");
      debugPrint("وقت استجابة فيسبوك: $fbPing");

      int ggPing = await _pingService.pingHost("google.com");
      debugPrint("وقت استجابة جوجل: $ggPing");

      int tkPing = await _pingService.pingHost("tiktok.com");
      debugPrint("وقت استجابة تيك توك: $tkPing");

      setState(() {
        _dataService.facebookPing = fbPing;
        _dataService.googlePing = ggPing;
        _dataService.tiktokPing = tkPing;
      });
    } catch (e) {
      debugPrint("? خطأ في قياس أوقات الاستجابة: $e");
    }
  }

  // Calculate connection percentage
  double _calculatePercentage() {
    if (_dataService.totalUsers == 0) return 0.0;
    return (_dataService.onlineUsers / _dataService.totalUsers).clamp(0.0, 1.0);
  }

  // Initialize notifications
  Future<void> _initNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings darwinInitializationSettings =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: darwinInitializationSettings,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload == 'expired_users') {
          Navigator.push(
            navigatorKey.currentContext!,
            MaterialPageRoute(
              builder: (context) => ExpiredUsersScreen(token: _currentToken, cachedData: [],),
            ),
          );
        }
      },
    );

    await _createNotificationChannels();
  }

  // Create notification channels
  Future<void> _createNotificationChannels() async {
    const AndroidNotificationChannel welcomeChannel = AndroidNotificationChannel(
      WELCOME_CHANNEL_ID,
      WELCOME_CHANNEL_NAME,
      description: WELCOME_CHANNEL_DESC,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      showBadge: true,
      sound: RawResourceAndroidNotificationSound('notification_sound'),
    );

    const AndroidNotificationChannel subscriptionChannel = AndroidNotificationChannel(
      SUBSCRIPTION_CHANNEL_ID,
      SUBSCRIPTION_CHANNEL_NAME,
      description: SUBSCRIPTION_CHANNEL_DESC,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      showBadge: true,
      sound: RawResourceAndroidNotificationSound('alert_sound'),
    );

    final plugin = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (plugin != null) {
      await plugin.createNotificationChannel(welcomeChannel);
      await plugin.createNotificationChannel(subscriptionChannel);
    }
  }

  // Request permissions
  Future<void> _requestPermissions() async {
    try {
      if (await Permission.notification.isDenied) {
        await Permission.notification.request();
      }

      if (await Permission.ignoreBatteryOptimizations.isDenied) {
        await Permission.ignoreBatteryOptimizations.request();
      }
    } catch (e) {
      debugPrint("Error requesting permissions: $e");
    }
  }

  // Check first login and show welcome notification
  Future<void> _checkFirstLoginAndShowWelcomeNotification() async {
    final prefs = await SharedPreferences.getInstance();
    bool isFirstLogin = prefs.getBool('isFirstLogin') ?? true;

    if (isFirstLogin) {
      await Future.delayed(const Duration(seconds: 1));
      await _showWelcomeNotification();
      await prefs.setBool('isFirstLogin', false);
    }
  }

  // Show welcome notification
  Future<void> _showWelcomeNotification() async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      WELCOME_CHANNEL_ID,
      WELCOME_CHANNEL_NAME,
      channelDescription: WELCOME_CHANNEL_DESC,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      styleInformation: BigTextStyleInformation(
        'تم تسجيل دخولك بنجاح. سيتم إعلامك فقط عند وجود اشتراكات منتهية جديدة.<br><br>'
        '• اضغط على الإشعار للذهاب إلى التطبيق<br>'
        '• ستظهر التنبيهات فقط عند وجود مستخدمين جدد منتهي اشتراكهم<br>'
        '• يمكنك دائمًا التحقق من حالة المستخدمين داخل التطبيق',
        htmlFormatBigText: true,
        contentTitle: '<b>مرحباً بك في التطبيق</b>',
        htmlFormatContentTitle: true,
        summaryText: 'معلومات مهمة',
        htmlFormatSummaryText: true,
      ),
      color: Colors.green,
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      channelShowBadge: true,
      autoCancel: true,
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.show(
      1001,
      "مرحباً بك في التطبيق",
      "تم تسجيل دخولك بنجاح. سيتم إعلامك فقط عند وجود اشتراكات منتهية جديدة.",
      platformChannelSpecifics,
      payload: 'welcome_notification',
    );
  }

  // Check expired users once
  Future<void> _checkExpiredUsersOnce() async {
    try {
      // استخدام البيانات المخزنة محليًا إذا كانت متوفرة
      if (_allUsersData.isNotEmpty) {
        // قم بتحليل البيانات الموجودة بالفعل
        await _processExpiredUsers(_allUsersData);
        return;
      }
      
      // إذا لم تكن هناك بيانات محلية، قم بتحميلها من الخادم
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('api_token') ?? _currentToken;
      
      final usersList = await _apiService.getAllUsers(token);
      debugPrint("تم جلب ${usersList.length} مستخدم للتحقق من الاشتراكات المنتهية");
      
      // تخزين البيانات للاستخدام في المستقبل
      _allUsersData = usersList;
      _dataService.cachedAllUsers = usersList;
      await _dataService.saveToLocalStorage();
      
      await _processExpiredUsers(usersList);
    } catch (e) {
      debugPrint("? خطأ في التحقق من المستخدمين منتهي الاشتراك: $e");
      
      // التحقق مما إذا كان الخطأ متعلقًا بالتوكن وتجديده
      if (_isTokenError(e)) {
        debugPrint("?? محاولة تجديد التوكن...");
        await TokenRefreshService().forceRefreshNow();
      }
    }
  }
  
  // معالجة بيانات المستخدمين منتهي الاشتراك
  Future<void> _processExpiredUsers(List<dynamic> usersList) async {
    DateTime now = DateTime.now();
    DateTime todayStart = DateTime(now.year, now.month, now.day);
    DateTime todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final prefs = await SharedPreferences.getInstance();
    Set<String> notifiedUserIds = Set<String>.from(
        prefs.getStringList('notified_expired_users') ?? []);

    List<Map<String, dynamic>> newExpiredUsers = [];
    List<dynamic> allExpiredUsers = [];

    for (var user in usersList) {
      if (user['expiration'] == null || user['expiration'].toString().isEmpty) {
        continue;
      }

      String userId = user['id']?.toString() ?? user['username']?.toString() ?? '';

      try {
        DateTime expiryDate = DateFormat("yyyy-MM-dd HH:mm:ss").parse(user['expiration'].toString());

        // حفظ جميع المستخدمين منتهي الاشتراك
        if (now.isAfter(expiryDate)) {
          allExpiredUsers.add(user);
        }

        // التحقق من المستخدمين المنتهي اشتراكهم اليوم والذين لم يتم إخطارهم بعد
        if (expiryDate.isAfter(todayStart) &&
            expiryDate.isBefore(todayEnd) &&
            now.isAfter(expiryDate) &&
            !notifiedUserIds.contains(userId)) {

          newExpiredUsers.add(user);
          notifiedUserIds.add(userId);
        }
      } catch (e) {
        debugPrint("Error parsing user date: ${user['username']}: $e");
      }
    }

    // تخزين المستخدمين منتهي الاشتراك
    _expiredUsersData = allExpiredUsers;
    _dataService.cachedExpiredUsers = allExpiredUsers;
    await _dataService.saveToLocalStorage();

    await prefs.setStringList('notified_expired_users', notifiedUserIds.toList());

    if (newExpiredUsers.isNotEmpty) {
      debugPrint("وجدنا ${newExpiredUsers.length} مستخدم جديد منتهي الاشتراك");
      await _showNewExpiredUsersNotification(newExpiredUsers);
    } else {
      debugPrint("لا يوجد مستخدمين جدد منتهي الاشتراك اليوم");
    }
  }

  // Show notification for newly expired users
  Future<void> _showNewExpiredUsersNotification(
    List<Map<String, dynamic>> newExpiredUsers,
  ) async {
    if (newExpiredUsers.isNotEmpty) {
      String detailedContent = '';
      for (int i = 0; i < min(newExpiredUsers.length, 5); i++) {
        var user = newExpiredUsers[i];
        String expiryDate = user['expiration']?.toString() ?? 'غير محدد';
        try {
          DateTime expiry = DateFormat("yyyy-MM-dd HH:mm").parse(expiryDate);
          expiryDate = DateFormat("yyyy-MM-dd HH:mm").format(expiry);
        } catch (_) {}

        detailedContent += '<b>${user['username']}</b> - انتهى في $expiryDate<br>';
      }

      if (newExpiredUsers.length > 5) {
        detailedContent += 'و ${newExpiredUsers.length - 5} مستخدمين آخرين...';
      }

      final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          SUBSCRIPTION_CHANNEL_ID,
          SUBSCRIPTION_CHANNEL_NAME,
          channelDescription: SUBSCRIPTION_CHANNEL_DESC,
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(
            detailedContent,
            htmlFormatBigText: true,
            contentTitle: '<b>انتهاء اشتراكات جديدة</b>',
            htmlFormatContentTitle: true,
            summaryText: '${newExpiredUsers.length} مشترك جديد منتهي',
            htmlFormatSummaryText: true,
          ),
          color: Colors.red,
          largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          channelShowBadge: true,
          autoCancel: true,
      );

      final NotificationDetails platformChannelSpecifics =
          NotificationDetails(android: androidPlatformChannelSpecifics);

      List<String> usernames = newExpiredUsers.map((user) => user['username'].toString()).toList();
      String usersText = usernames.length <= 3
          ? usernames.join('، ')
          : "${usernames.sublist(0, 3).join('، ')} و${usernames.length - 3} آخرين";

      await flutterLocalNotificationsPlugin.show(
        1002,
        "انتهاء اشتراكات جديدة",
        "تم انتهاء اشتراك ${newExpiredUsers.length} مستخدم جديد: $usersText",
        platformChannelSpecifics,
        payload: 'expired_users',
      );
    }
  }

  // Navigate to screens with proper behavior to return to Dashboard - MODIFIED
  void _navigateToScreen(int index) {
    // تحديث المؤشر المحدد
    setState(() {
      _selectedIndex = index;
    });

    // إغلاق القائمة الجانبية إذا كانت مفتوحة
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }

    // العودة إذا تم اختيار الداشبورد الحالي
    if (index == 0) {
      return;
    }

    // تأخير للسماح بإغلاق القائمة الجانبية بسلاسة
    Future.delayed(const Duration(milliseconds: 300), () {
      Widget screenContent;
      
      // جلب التوكن المحدث قبل الانتقال للشاشة
      SharedPreferences.getInstance().then((prefs) {
        final token = prefs.getString('api_token') ?? _currentToken;
        
        // إنشاء الشاشة المناسبة بناءً على المؤشر مع تمرير البيانات المخزنة مسبقًا
        switch (index) {
          case 1:
            screenContent = OnlineUsersScreen(
              token: token,
              // تمرير البيانات المخزنة مسبقًا للمستخدمين المتصلين
              cachedData: _onlineUsersData,
            );
            break;
          case 2:
            screenContent = AllUsersScreen(
              token: token,
              // تمرير البيانات المخزنة مسبقًا لجميع المستخدمين
              cachedData: _allUsersData,
            );
            break;
          case 3:
            screenContent = ExpiredUsersScreen(
              token: token,
              // تمرير البيانات المخزنة مسبقًا للمستخدمين منتهي الاشتراك
              cachedData: _expiredUsersData,
            );
            break;
          case 4:
            screenContent = const SpeedTestPage();
            break;
          default:
            return;
        }

        // التنقل للشاشة باستخدام WillPopScope للتحكم في سلوك الرجوع
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => WillPopScope(
              onWillPop: () async {
                // تحديث المؤشر المحدد عند الرجوع للداشبورد
                setState(() {
                  _selectedIndex = 0;
                });
                return true; // السماح بالرجوع
              },
              child: Scaffold(
                appBar: AppBar(
                  title: Text(_getScreenTitle(index)),
                  backgroundColor: _surfaceColor,
                  foregroundColor: _textColor,
                  leading: BackButton(
                    color: _textColor,
                    onPressed: () {
                      // تحديث المؤشر المحدد للداشبورد عند الضغط على زر الرجوع
                      setState(() {
                        _selectedIndex = 0;
                      });
                      // العودة للداشبورد
                      Navigator.of(context).pop();
                    },
                  ),
                ),
                body: screenContent,
              ),
            ),
          ),
        ).then((_) {
          // تحديث المؤشر المحدد للداشبورد بعد العودة
          setState(() {
            _selectedIndex = 0;
          });
          
          // التحقق من صلاحية التوكن بعد العودة
          _validateToken();
        });
      });
    });
  }
  
  /// Get screen title based on index
  String _getScreenTitle(int index) {
    switch (index) {
      case 1:
        return "المستخدمون المتصلون";
      case 2:
        return "جميع المستخدمين";
      case 3:
        return "المستخدمون المنتهية اشتراكاتهم";
      case 4:
        return "اختبار السرعة";
      default:
        return "لوحة التحكم";
    }
  }

  // إضافة دالة جديدة لعرض مربع حوار تأكيد الخروج من التطبيق
  Future<bool> _showExitDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.exit_to_app, color: Colors.red[300]),
            SizedBox(width: 10),
            Text(
              'الخروج من التطبيق',
              style: TextStyle(color: _textColor),
            ),
          ],
        ),
        content: Text(
          'هل أنت متأكد من رغبتك في الخروج من التطبيق؟',
          style: TextStyle(color: _textColor.withOpacity(0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), // لا تخرج
            child: Text(
              'إلغاء',
              style: TextStyle(color: _textColor.withOpacity(0.8)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[400],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(context, true), // تأكيد الخروج
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text('تأكيد الخروج'),
            ),
          ),
        ],
      ),
    ) ?? false; // افتراضياً عدم الخروج إذا تم إغلاق مربع الحوار
  }

  // تعديل طريقة بناء شريط التنقل السفلي لمعالجة التغييرات الصحيحة للمؤشرات
  Widget _buildBottomNavItem(int index, IconData icon, String label) {
    bool isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () {
        // إذا كان المؤشر المحدد مختلفًا عن المؤشر الحالي
        if (_selectedIndex != index) {
          if (index == 0) {
            // إذا تم النقر على الداشبورد، فقط تحديث المؤشر
            setState(() {
              _selectedIndex = 0;
            });
          } else {
            // وإلا الانتقال للشاشة المطلوبة
            _navigateToScreen(index);
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? _primaryColor.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
       child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? _primaryColor : _textColor.withOpacity(0.7),
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? _primaryColor : _textColor.withOpacity(0.7),
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Show logout dialog
  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.logout, color: Colors.red[300]),
            SizedBox(width: 10),
            Text(
              'تسجيل الخروج',
              style: TextStyle(color: _textColor),
            ),
          ],
        ),
        content: Text(
          'هل أنت متأكد من رغبتك في تسجيل الخروج؟',
          style: TextStyle(color: _textColor.withOpacity(0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'إلغاء',
              style: TextStyle(color: _textColor.withOpacity(0.8)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[400],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: _logout,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text('تأكيد الخروج'),
            ),
          ),
        ],
      ),
    );
  }

  // Show about dialog
  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, color: _primaryColor),
            SizedBox(width: 10),
            Text(
              "حول التطبيق",
              style: TextStyle(
                color: _textColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.admin_panel_settings,
                size: 40,
                color: _primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "إدارة المشتركين",
              style: TextStyle(
                color: _textColor,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              "الإصدار 1.0.0",
              style: TextStyle(
                color: _textColor.withOpacity(0.7),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              "تطبيق لإدارة المشتركين وعرض حالة اتصالهم ومراقبة انتهاء صلاحية اشتراكاتهم.",
              style: TextStyle(
                color: _textColor.withOpacity(0.9),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  "إغلاق",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Manual data refresh - سحب الشاشة للتحديث
  Future<void> _manualRefresh() async {
    setState(() {
      _dataService.isLoading = true;
      _dataService.errorMessage = "";
    });

    debugPrint("جاري تحديث البيانات يدويًا...");

    // التحقق من صلاحية التوكن قبل تحديث البيانات
    await _validateToken();
    
    _initApiService();
    await _fetchData();
    await _checkSubscriptionStatus();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("تم تحديث البيانات"),
        backgroundColor: _primaryColor,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;

    return WillPopScope(
      onWillPop: () async {
        // عند محاولة الخروج من الشاشة الرئيسية بزر الرجوع
        if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
          // إذا كانت القائمة الجانبية مفتوحة، أغلقها فقط
          Navigator.of(context).pop();
          return false; // لا تخرج من التطبيق
        }
        
        // إذا كنا في الشاشة الرئيسية، عرض مربع حوار للتأكيد
        bool shouldExit = await _showExitDialog();
        return shouldExit; // السماح بالخروج فقط إذا تم التأكيد
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: _backgroundColor,
        appBar: _buildAppBar(screenWidth),
        drawer: _buildCustomDrawer(),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_surfaceColor, _backgroundColor],
            ),
          ),
          child: RefreshIndicator(
            onRefresh: _manualRefresh, // تحديث البيانات عند سحب الشاشة للأسفل
            color: _primaryColor,
            backgroundColor: _cardColor,
            child: _dataService.isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: _secondaryColor),
                        const SizedBox(height: 16),
                        Text(
                          "جاري تحميل البيانات...",
                          style: TextStyle(color: _textColor, fontSize: 16),
                        ),
                      ],
                    ),
                  )
                : _dataService.errorMessage.isNotEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, color: Colors.red, size: 48),
                            const SizedBox(height: 16),
                            Text(
                              _dataService.errorMessage,
                              style: const TextStyle(color: Colors.red, fontSize: 18),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: _manualRefresh,
                              icon: const Icon(Icons.refresh),
                              label: const Text("إعادة المحاولة"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : _buildDashboardContent(screenWidth),
          ),
        ),
        bottomNavigationBar: _buildBottomBar(),
      ),
    );
  }

  // Build custom drawer
  Widget _buildCustomDrawer() {
    return CustomDrawer(
      userName: _dataService.currentUserName,
      userRole: _dataService.currentUserRole,
      userEmail: _dataService.currentUserEmail,
      userAvatarUrl: _dataService.userAvatarUrl,
      onlineUsers: _dataService.onlineUsers,
      totalUsers: _dataService.totalUsers,
      offlineUsers: _dataService.offlineUsers,
      selectedIndex: _selectedIndex,
      onNavigate: _navigateToScreen,
      onLogout: _showLogoutDialog,
      onAboutTap: () {
        Navigator.pop(context);
        _showAboutDialog();
      },
      onSettingsTap: () {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('سيتم إضافة صفحة الإعدادات قريباً'),
            backgroundColor: _primaryColor,
          ),
        );
      },
      facebookPing: _dataService.facebookPing,
      googlePing: _dataService.googlePing,
      tiktokPing: _dataService.tiktokPing,
      primaryColor: _primaryColor,
      secondaryColor: _secondaryColor,
      accentColor: _accentColor,
      backgroundColor: _backgroundColor,
      surfaceColor: _surfaceColor,
      cardColor: _cardColor,
      textColor: _textColor,
      extraInfo: '${_apiService.companyName} - ${_apiService.baseUrl.split('/')[2]}',
    );
  }

  // Build enhanced app bar
  PreferredSizeWidget _buildAppBar(double screenWidth) {
    return AppBar(
      backgroundColor: _surfaceColor,
      elevation: 0,
      scrolledUnderElevation: 0,
      title: Text(
        "لوحة التحكم",
        style: TextStyle(
          color: _textColor,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          onPressed: _manualRefresh,
          icon: Icon(Icons.refresh, color: _primaryColor),
          tooltip: "تحديث البيانات",
        ),
        GestureDetector(
          onTap: _showAboutDialog,
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.info_outline,
              color: _primaryColor,
              size: 24,
            ),
          ),
        ),
      ],
      leading: GestureDetector(
        onTap: () {
          _scaffoldKey.currentState?.openDrawer();
        },
        child: Container(
          margin: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.menu,
            color: _primaryColor,
          ),
        ),
      ),
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_backgroundColor, _surfaceColor],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
      ),
    );
  }

  // Build bottom navigation bar
  Widget _buildBottomBar() {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: _surfaceColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildBottomNavItem(0, Icons.dashboard, "الرئيسية"),
          _buildBottomNavItem(1, Icons.people, "المتصلون"),
          _buildBottomNavItem(2, Icons.group, "المستخدمون"),
          _buildBottomNavItem(3, Icons.warning, "المنتهي"),
          _buildBottomNavItem(4, Icons.speed, "السرعة"),
        ],
      ),
    );
  }

  // Build main dashboard content
  Widget _buildDashboardContent(double screenWidth) {
    return SingleChildScrollView(
      physics: BouncingScrollPhysics(),
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                Text(
                  "حالة الاتصال",
                  style: TextStyle(
                    color: _textColor,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                )
                    .animate()
                    .fadeIn(duration: 500.ms)
                    .slideY(begin: -0.5, end: 0, curve: Curves.easeOut),
                SizedBox(height: 20),
                CircularPercentIndicator(
                  radius: screenWidth * 0.28,
                  lineWidth: 12.0,
                  percent: _calculatePercentage(),
                  center: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "${_dataService.onlineUsers}",
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: _secondaryColor,
                        ),
                      )
                          .animate()
                          .fadeIn(duration: 500.ms)
                          .scale(begin: const Offset(0.5, 0.5), end: const Offset(1, 1), curve: Curves.easeOut),
                      SizedBox(height: 6),
                      Text(
                        "متصل",
                        style: TextStyle(fontSize: 18, color: _textColor),
                      )
                          .animate()
                          .fadeIn(duration: 600.ms),
                      SizedBox(height: 6),
                      Text(
                        "${_dataService.onlineUsers} / ${_dataService.totalUsers}",
                        style: TextStyle(fontSize: 16, color: _textColor.withOpacity(0.7)),
                      )
                          .animate()
                          .fadeIn(duration: 700.ms),
                    ],
                  ),
                  progressColor: _secondaryColor,
                  backgroundColor: Colors.grey.shade800,
                )
                    .animate()
                    .fadeIn(duration: 800.ms)
                    .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1), curve: Curves.easeOut),
              ],
            ),
          ),
          SizedBox(height: 30),
          _buildInfoCards(screenWidth),
          SizedBox(height: 20),
          _buildNetworkCard(screenWidth),
          SizedBox(height: 20),
          _buildConnectionInfoCard(),
          SizedBox(height: 20),
          Center(
            child: Text(
              "آخر تحديث: ${DateFormat('HH:mm:ss', 'ar').format(_dataService.lastUpdateTime)}",
              style: TextStyle(
                color: _textColor.withOpacity(0.6),
                fontSize: 12,
              ),
            ),
          ),
          // عرض معلومات التوكن للتشخيص (يمكن إزالتها في الإصدار النهائي)
          SizedBox(height: 20),
          _buildTokenDebugInfo(),
        ],
      ),
    );
  }

  // بناء بطاقة معلومات التوكن للتشخيص
  Widget _buildTokenDebugInfo() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _primaryColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.security,
                color: _primaryColor,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                "في حال عدم ظهور اي نتائج اضغط على تجديد الاتصال ",
                style: TextStyle(
                  color: _textColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Text(
                "خدمة تجديد التوكن:",
                style: TextStyle(
                  color: _textColor.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
              SizedBox(width: 8),
              Text(
                TokenRefreshService().isActive ? "نشطة ?" : "غير نشطة ?",
                style: TextStyle(
                  color: TokenRefreshService().isActive ? Colors.green : Colors.red,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          FutureBuilder<DateTime?>(
            future: TokenRefreshService().getTokenExpiryTime(),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data != null) {
                final expiryTime = snapshot.data!;
                final now = DateTime.now();
                final timeDiff = expiryTime.difference(now);
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          "وقت انتهاء التوكن:",
                          style: TextStyle(
                            color: _textColor.withOpacity(0.7),
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          DateFormat('HH:mm:ss', 'ar').format(expiryTime),
                          style: TextStyle(
                            color: timeDiff.inMinutes > 30 ? Colors.green : Colors.orange,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          "الوقت المتبقي:",
                          style: TextStyle(
                            color: _textColor.withOpacity(0.7),
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          "${timeDiff.inMinutes} دقيقة",
                          style: TextStyle(
                            color: timeDiff.inMinutes > 30 ? Colors.green : 
                                  timeDiff.inMinutes > 10 ? Colors.orange : Colors.red,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    // إضافة سطر لعرض الوقت المتبقي للجلسة
                    SizedBox(height: 8),
                    FutureBuilder<SharedPreferences>(
                      future: SharedPreferences.getInstance(),
                      builder: (context, prefsSnapshot) {
                        if (prefsSnapshot.hasData) {
                          final prefs = prefsSnapshot.data!;
                          final sessionStartTimeStr = prefs.getString(PREFS_SESSION_START_TIME);
                          
                          if (sessionStartTimeStr != null) {
                            final sessionStartTime = DateTime.parse(sessionStartTimeStr);
                            final sessionDuration = now.difference(sessionStartTime);
                            final remainingTime = Duration(hours: MAX_SESSION_DURATION_HOURS) - sessionDuration;
                            
                            final hours = remainingTime.inHours;
                            final minutes = remainingTime.inMinutes.remainder(60);
                            
                            return Row(
                              children: [
                                Text(
                                  "وقت الجلسة المتبقي:",
                                  style: TextStyle(
                                    color: _textColor.withOpacity(0.7),
                                    fontSize: 14,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  "$hours ساعة و $minutes دقيقة",
                                  style: TextStyle(
                                    color: remainingTime.inMinutes > 60 ? Colors.green : 
                                          remainingTime.inMinutes > 30 ? Colors.orange : Colors.red,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            );
                          }
                        }
                        return SizedBox.shrink();
                      },
                    ),
                  ],
                );
              } else {
                return Text(
                  "لا توجد معلومات عن انتهاء التوكن",
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 14,
                  ),
                );
              }
            },
          ),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton.icon(
                onPressed: () async {
                  // تجديد التوكن
                  final refreshed = await TokenRefreshService().forceRefreshNow();
                  
                  // تحديث كامل للوحة التحكم بعد تجديد التوكن
                  if (refreshed) {
                    await _manualRefresh();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("تم تجديد التوكن وتحديث البيانات بنجاح"),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("فشل تجديد التوكن"),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                  setState(() {}); // تحديث الواجهة
                },
                icon: Icon(Icons.refresh, size: 16),
                label: Text("تجديد التوكن"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  textStyle: TextStyle(fontSize: 12),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  // التحقق من صلاحية التوكن وتحديث كامل للبيانات
                  await _validateToken();
                  await _manualRefresh();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("تم تجديد الاتصال وتحديث البيانات"),
                      backgroundColor: _primaryColor,
                    ),
                  );
                  setState(() {}); // تحديث الواجهة
                },
                icon: Icon(Icons.check_circle, size: 16),
                label: Text("تجديد الاتصال"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _secondaryColor,
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  textStyle: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Build info cards for user statistics
  Widget _buildInfoCards(double screenWidth) {
    final double cardPadding = 16;
    final double cardWidth = (screenWidth - cardPadding * 4) / 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "إحصائيات المستخدمين",
          style: TextStyle(
            color: _textColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildInfoCard(
              title: "متصل",
              value: _dataService.onlineUsers,
              icon: Icons.people,
              color: _secondaryColor,
              width: cardWidth,
            ),
            _buildInfoCard(
              title: "غير متصل",
              value: _dataService.offlineUsers,
              icon: Icons.person_off,
              color: Colors.grey,
              width: cardWidth,
            ),
          ],
        ),
        SizedBox(height: cardPadding),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildInfoCard(
              title: "الإجمالي",
              value: _dataService.totalUsers,
              icon: Icons.group,
              color: _primaryColor,
              width: cardWidth,
            ),
            _buildPercentCard(
              title: "نسبة الاتصال",
              percent: _calculatePercentage() * 100,
              icon: Icons.percent,
              color: _accentColor,
              width: cardWidth,
            ),
          ],
        ),
      ],
    );
  }

  // Build info card for numbers
  Widget _buildInfoCard({
    required String title,
    required int value,
    required IconData icon,
    required Color color,
    required double width,
  }) {
    return Container(
      width: width,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceColor.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: _textColor.withOpacity(0.8),
                  fontSize: 14,
                ),
              ),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 16,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            value.toString(),
            style: TextStyle(
              color: _textColor,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          LinearProgressIndicator(
            value: value > 0 ? 1.0 : 0.0,
            backgroundColor: _cardColor,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            borderRadius: BorderRadius.circular(10),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 600.ms)
        .slideY(begin: 0.2, end: 0);
  }

  // Build info card for percentages
  Widget _buildPercentCard({
    required String title,
    required double percent,
    required IconData icon,
    required Color color,
    required double width,
  }) {
    return Container(
      width: width,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceColor.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: _textColor.withOpacity(0.8),
                  fontSize: 14,
                ),
              ),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 16,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            "${percent.toStringAsFixed(1)}%",
            style: TextStyle(
              color: _textColor,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          LinearProgressIndicator(
            value: percent / 100,
            backgroundColor: _cardColor,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            borderRadius: BorderRadius.circular(10),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 600.ms)
        .slideY(begin: 0.2, end: 0);
  }

  // Build network speed card
  Widget _buildNetworkCard(double screenWidth) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceColor.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.network_check,
                color: _primaryColor,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                "سرعة الاتصال",
                style: TextStyle(
                  color: _textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNetworkItem("فيسبوك", _dataService.facebookPing, Icons.facebook),
              _buildNetworkItem("جوجل", _dataService.googlePing, Icons.search),
              _buildNetworkItem("تيك توك", _dataService.tiktokPing, Icons.music_video),
            ],
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 800.ms)
        .slideY(begin: 0.3, end: 0);
  }

  // Build network speed item
  Widget _buildNetworkItem(String name, int ping, IconData icon) {
    String status;
    Color color;

    if (ping < 0) {
      status = "غير متصل";
      color = Colors.red;
    } else if (ping < 100) {
      status = "ممتاز";
      color = _secondaryColor;
    } else if (ping < 200) {
      status = "جيد";
      color = _accentColor;
    } else {
      status = "بطيء";
      color = Colors.red;
    }

    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _cardColor,
            shape: BoxShape.circle,
            border: Border.all(
              color: color,
              width: 2,
            ),
          ),
          child: Icon(
            icon,
            color: _textColor,
            size: 24,
          ),
        ),
        SizedBox(height: 8),
        Text(
          name,
          style: TextStyle(
            color: _textColor,
            fontSize: 14,
          ),
        ),
        SizedBox(height: 4),
        Text(
          ping >= 0 ? "$ping ms" : "--",
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 2),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            status,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  // Build connection info card
  Widget _buildConnectionInfoCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceColor.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: _primaryColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.link,
                color: _primaryColor,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                "معلومات الاتصال",
                style: TextStyle(
                  color: _textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          _buildInfoRow("الشركة:", _apiService.companyName),
          _buildInfoRow("الخادم:", _apiService.baseUrl.split('/')[2]),
          _buildInfoRow("حالة الاتصال:", _dataService.errorMessage.isEmpty ? "متصل" : "غير متصل"),
          _buildInfoRow("حالة التوكن:", TokenRefreshService().isActive ? "يتم تجديده تلقائياً" : "بحاجة للتفعيل"),
          _buildInfoRow("آخر تحديث منذ:", _getLastUpdateTimeFormatted()),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 800.ms)
        .slideY(begin: 0.3, end: 0);
  }

  // تنسيق وقت آخر تحديث
  String _getLastUpdateTimeFormatted() {
    final Duration difference = DateTime.now().difference(_dataService.lastUpdateTime);
    
    if (difference.inMinutes < 1) {
      return "الآن";
    } else if (difference.inMinutes < 60) {
      return "${difference.inMinutes} دقيقة";
    } else {
      return "${(difference.inMinutes / 60).floor()} ساعة و ${difference.inMinutes % 60} دقيقة";
    }
  }

  // Build info row for connection info
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: _textColor.withOpacity(0.7),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: _textColor,
                fontSize: 14,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}