import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/debt_model.dart';
import '../services/database_service.dart';
import '../services/api_service.dart';
import '../services/global_company.dart';
import 'add_debt_screen.dart';

class DebtManagementScreen extends StatefulWidget {
  final String token;

  const DebtManagementScreen({Key? key, required this.token}) : super(key: key);

  @override
  _DebtManagementScreenState createState() => _DebtManagementScreenState();
}

class _DebtManagementScreenState extends State<DebtManagementScreen> {
  final DatabaseService _databaseService = DatabaseService.instance;
  late ApiService _apiService; // إضافة مرجعية إلى خدمة API
  bool isLoading = true;
  List<DebtModel> allDebts = [];
  List<DebtModel> filteredDebts = [];

  // استخدام مجموعات مستخدمين موحدة حسب userId
  Map<int, List<DebtModel>> debtsByUserId = {};
  Map<int, String> usernameByUserId = {};
  Map<int, double> totalAmountByUserId = {};

  // عرض قائمة المستخدمين الفريدة (بدون تكرار)
  List<int> uniqueUserIds = [];

  // معلومات المستخدمين المخزنة من API
  Map<int, Map<String, dynamic>> userDetailsCache = {};

  double totalUnpaid = 0.0;
  String sortOption = 'dueDate';

  final Color _primaryColor = const Color(0xFFFF6B35);
  final Color _secondaryColor = const Color(0xFFF9F2E7);
  final Color _accentColor = const Color(0xFF2EC4B6);
  final Color _backgroundColor = Colors.white;
  final Color _textColor = Colors.black87;

  @override
  void initState() {
    super.initState();
    _initApiService();
    _loadDebts();
  }

  // تهيئة خدمة API
  void _initApiService() {
    try {
      if (GlobalCompany.isCompanySet()) {
        print("استخدام الشركة العالمية: ${GlobalCompany.getCompanyName()}");
        _apiService = ApiService.fromCompanyConfig(GlobalCompany.getCompany());
      } else {
        print("الشركة العالمية غير محددة، استخدام الافتراضية");
        _apiService = ApiService(serverDomain: '');
      }
      
      _apiService.printServiceInfo();
    } catch (e) {
      print("خطأ في تهيئة ApiService: $e");
      _apiService = ApiService(serverDomain: '');
    }
  }

  // دالة لجلب جميع بيانات المستخدمين من API وتخزينها للاستخدام اللاحق
  Future<void> _fetchUserDetails() async {
    try {
      print("جلب بيانات المستخدمين من API...");
      final usersList = await _apiService.getAllUsers(widget.token);
      
      for (var user in usersList) {
        if (user['id'] != null) {
          userDetailsCache[user['id']] = user;
        }
      }
      
      print("تم جلب بيانات ${userDetailsCache.length} مستخدم من API.");
    } catch (e) {
      print("خطأ في جلب بيانات المستخدمين: $e");
    }
  }

  // الحصول على رقم هاتف المستخدم من البيانات المخزنة
  String? _getUserPhoneNumber(int userId) {
    if (userDetailsCache.containsKey(userId)) {
      final userData = userDetailsCache[userId]!;
      // البحث في كل الحقول المحتملة للهاتف
      return userData['phone'] ?? 
             userData['phoneNumber'] ?? 
             userData['mobile'] ?? '';
    }
    return null;
  }

  Future<void> _loadDebts() async {
    setState(() {
      isLoading = true;
    });

    try {
      // جلب بيانات المستخدمين من API أولاً
      await _fetchUserDetails();

      final allDebtsFromDb = await _databaseService.getAllDebts();
      final unPaidDebts = allDebtsFromDb.where((debt) => !debt.isPaid).toList();

      // تجميع الديون حسب معرف المستخدم
      Map<int, List<DebtModel>> groupedDebts = {};
      Map<int, String> usernames = {};
      Map<int, double> userTotals = {};
      Set<int> userIdSet = {};

      for (var debt in unPaidDebts) {
        // تخطي الديون التي ليس لها معرف مستخدم
        if (debt.userId == null) continue;

        final userId = debt.userId!;
        if (!groupedDebts.containsKey(userId)) {
          groupedDebts[userId] = [];
          userTotals[userId] = 0;
          usernames[userId] = debt.username;
          userIdSet.add(userId);
        }

        // تحديث رقم الهاتف من بيانات API إذا كان غير متوفر
        DebtModel updatedDebt = debt;
        if ((debt.phoneNumber == null || debt.phoneNumber!.isEmpty) && userDetailsCache.containsKey(debt.userId)) {
          String? phoneFromApi = _getUserPhoneNumber(debt.userId!);
          if (phoneFromApi != null && phoneFromApi.isNotEmpty) {
            updatedDebt = DebtModel(
              id: debt.id,
              userId: debt.userId,
              username: debt.username,
              amount: debt.amount,
              dueDate: debt.dueDate,
              phoneNumber: phoneFromApi,
              notes: debt.notes,
              isPaid: debt.isPaid,
              createdAt: debt.createdAt,
            );
            print("تم تحديث رقم هاتف المستخدم ${debt.username} من API: $phoneFromApi");
          }
        }

        groupedDebts[userId]!.add(updatedDebt);
        userTotals[userId] = (userTotals[userId] ?? 0) + updatedDebt.amount;
      }

      // تحويل مجموعة المعرفات إلى قائمة
      List<int> uniqueIds = userIdSet.toList();

      final total = await _databaseService.getTotalUnpaidDebts();

      setState(() {
        allDebts = unPaidDebts;
        filteredDebts = unPaidDebts;
        debtsByUserId = groupedDebts;
        usernameByUserId = usernames;
        totalAmountByUserId = userTotals;
        uniqueUserIds = uniqueIds;
        totalUnpaid = total;
        isLoading = false;
        _sortDebts();
      });
    } catch (e) {
      print("خطأ في تحميل الديون: $e");
      setState(() {
        isLoading = false;
      });
      _showErrorSnackBar("حدث خطأ أثناء تحميل الديون");
    }
  }

  void _filterDebts(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredDebts = allDebts;
      } else {
        filteredDebts = allDebts.where((debt) {
          return debt.username.toLowerCase().contains(query.toLowerCase()) ||
              (debt.notes != null &&
                  debt.notes!.toLowerCase().contains(query.toLowerCase()));
        }).toList();
      }
      _sortDebts();
    });
  }

  void _sortDebts() {
    setState(() {
      switch (sortOption) {
        case 'dueDate':
          filteredDebts.sort((a, b) => a.dueDate.compareTo(b.dueDate));
          break;
        case 'amount':
          filteredDebts.sort((a, b) => b.amount.compareTo(a.amount));
          break;
        case 'name':
          filteredDebts.sort((a, b) => a.username.compareTo(b.username));
          break;
      }
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _accentColor,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // الحصول على الدين الرئيسي للمستخدم
  DebtModel? _getMainDebtForUser(int userId) {
    if (!debtsByUserId.containsKey(userId) || debtsByUserId[userId]!.isEmpty) {
      return null;
    }

    final userDebts = List<DebtModel>.from(debtsByUserId[userId]!);
    userDebts.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return userDebts.first;
  }

  // الحصول على معرف المستخدم من اسم المستخدم
  int? _getUserIdByUsername(String username) {
    for (var entry in usernameByUserId.entries) {
      if (entry.value.toLowerCase() == username.toLowerCase()) {
        return entry.key;
      }
    }
    return null;
  }

  // التحقق من وجود مستخدم بالاسم
  bool _isUserExists(String username) {
    return usernameByUserId.values
        .any((name) => name.toLowerCase() == username.toLowerCase());
  }

  // دالة ارسال اشعار واتساب محدثة
  Future<void> _sendWhatsAppMessage(DebtModel debt, double paidAmount, {bool isFullPayment = true}) async {
    // محاولة الحصول على رقم الهاتف من الدين أو من API
    String? phoneNumber = debt.phoneNumber;
    
    // إذا كان رقم الهاتف غير متوفر، حاول الحصول عليه من API
    if ((phoneNumber == null || phoneNumber.isEmpty) && debt.userId != null) {
      String? phoneFromApi = _getUserPhoneNumber(debt.userId!);
      if (phoneFromApi != null && phoneFromApi.isNotEmpty) {
        phoneNumber = phoneFromApi;
        print("تم استخدام رقم الهاتف من API: $phoneNumber");
      }
    }
    
    // إذا استمر عدم توفر رقم الهاتف، أظهر إشعارًا وارجع
    if (phoneNumber == null || phoneNumber.isEmpty) {
      _showSuccessSnackBar(
          "تم تسديد الدين بنجاح، ولكن لم يتم إرسال إشعار (رقم الهاتف غير متوفر)");
      return;
    }

    // تنظيف وتنسيق رقم الهاتف
    phoneNumber = phoneNumber.replaceAll(RegExp(r'\s+'), '');
    phoneNumber = phoneNumber.replaceAll(RegExp(r'[+()-]'), '');
    
    if (phoneNumber.startsWith('0')) {
      phoneNumber = '964' + phoneNumber.substring(1);
    } else if (!phoneNumber.startsWith('964')) {
      phoneNumber = '964' + phoneNumber;
    }

    // إنشاء رسالة مخصصة حسب نوع التسديد
    String message;
    if (isFullPayment) {
      message = 'مرحباً ${debt.username}،\n'
                'نشكرك على تسديد مبلغ الاشتراك  البالغ ${paidAmount.toStringAsFixed(2)} د.ع بتاريخ ${DateFormat('yyyy/MM/dd').format(DateTime.now())}.\n'
                'نتمنى لك تجربة ممتازة مع خدماتنا ونشكرك على ثقتك بنا!';
    } else {
      final remainingAmount = debt.amount - paidAmount;
      message = 'مرحباً ${debt.username}،\n'
                'نؤكد استلام دفعة جزئية بقيمة ${paidAmount.toStringAsFixed(2)} د.ع بتاريخ ${DateFormat('yyyy/MM/dd').format(DateTime.now())}.\n'
                'المبلغ المتبقي: ${remainingAmount.toStringAsFixed(2)} د.ع.\n'
                'شكراً لتعاونكم.';
    }

    // محاولة فتح واتساب مباشرة
    final Uri whatsappUriDirect = Uri.parse(
      "whatsapp://send?phone=$phoneNumber&text=${Uri.encodeComponent(message)}"
    );
    
    try {
      bool launched = await launchUrl(
        whatsappUriDirect, 
        mode: LaunchMode.externalNonBrowserApplication,
      );
      
      if (launched) {
        print("تم فتح واتساب بنجاح في الوضع المباشر");
        _showSuccessSnackBar("تم إرسال إشعار عبر الواتساب");
      } else {
        // طريقة بديلة عبر المتصفح
        final Uri whatsappUriFallback = Uri.parse(
          "https://api.whatsapp.com/send?phone=$phoneNumber&text=${Uri.encodeComponent(message)}"
        );
        
        if (await canLaunchUrl(whatsappUriFallback)) {
          await launchUrl(whatsappUriFallback, mode: LaunchMode.externalApplication);
          print("تم فتح واتساب بالطريقة البديلة");
          _showSuccessSnackBar("تم إرسال إشعار عبر الواتساب");
        } else {
          throw 'لا يمكن فتح واتساب';
        }
      }
    } catch (e) {
      print("خطأ أثناء فتح واتساب: $e");
      _showErrorSnackBar("تعذر فتح واتساب. الرجاء التأكد من تثبيت التطبيق.");
    }
  }

  Future<void> _markAsPaid(DebtModel debt) async {
    try {
      if (debt.id == null) {
        _showErrorSnackBar("معرف الدين غير متوفر");
        return;
      }

      // الاحتفاظ بقيمة الدين الأصلية قبل الحذف من القائمة
      double originalAmount = debt.amount;

      // تحديث حالة الدين إلى مدفوع
      await _databaseService.updateDebtStatus(debt.id!, true);

      // تحديث القائمة بإزالة الدين المسدد
      setState(() {
        allDebts.removeWhere((item) => item.id == debt.id);
        filteredDebts.removeWhere((item) => item.id == debt.id);

        // تحديث مجموعات المستخدمين
        if (debt.userId != null && debtsByUserId.containsKey(debt.userId)) {
          debtsByUserId[debt.userId!]!
              .removeWhere((item) => item.id == debt.id);
          totalAmountByUserId[debt.userId!] =
              (totalAmountByUserId[debt.userId!] ?? debt.amount) - debt.amount;

          if (debtsByUserId[debt.userId!]!.isEmpty) {
            debtsByUserId.remove(debt.userId);
            usernameByUserId.remove(debt.userId);
            totalAmountByUserId.remove(debt.userId);
            uniqueUserIds.remove(debt.userId);
          }
        }
      });

      // إعادة حساب إجمالي الديون غير المسددة
      final total = await _databaseService.getTotalUnpaidDebts();
      setState(() {
        totalUnpaid = total;
      });

      // إرسال رسالة واتساب مع تحديد أنه تسديد كامل
      await _sendWhatsAppMessage(debt, originalAmount, isFullPayment: true);
    } catch (e) {
      print("خطأ في تحديث حالة الدين: $e");
      _showErrorSnackBar("حدث خطأ أثناء تحديث حالة الدين");
    }
  }

  Future<void> _markPartiallyPaid(DebtModel debt, double amountPaid) async {
    try {
      if (debt.id == null) {
        _showErrorSnackBar("معرف الدين غير متوفر");
        return;
      }

      // الاحتفاظ بقيمة الدين الأصلية قبل التعديل
      final originalAmount = debt.amount;
      final remainingAmount = originalAmount - amountPaid;

      // تحقق مما إذا كان المبلغ المدفوع يغطي الدين بالكامل
      if (remainingAmount <= 0) {
        await _markAsPaid(debt);
        return;
      }

      // تحديث قيمة الدين المتبقية
      await _databaseService.updateDebtAmount(debt.id!, remainingAmount);

      // إضافة ملاحظة بخصوص الدفعة الجزئية
      String updatedNotes;
      if (debt.notes != null && debt.notes!.isNotEmpty) {
        updatedNotes =
            "${debt.notes} (تم تسديد ${amountPaid.toStringAsFixed(2)} د.ع بتاريخ ${DateFormat('yyyy/MM/dd').format(DateTime.now())})";
      } else {
        updatedNotes =
            "(تم تسديد ${amountPaid.toStringAsFixed(2)} د.ع بتاريخ ${DateFormat('yyyy/MM/dd').format(DateTime.now())})";
      }

      await _databaseService.updateDebtNotes(debt.id!, updatedNotes);
      
      // إعادة تحميل الديون لتحديث العرض
      await _loadDebts();
      
      // إرسال رسالة واتساب للإشعار بالدفعة الجزئية
      await _sendWhatsAppMessage(
        DebtModel(
          id: debt.id,
          userId: debt.userId,
          username: debt.username,
          amount: originalAmount,  // استخدام المبلغ الكلي الأصلي
          dueDate: debt.dueDate,
          phoneNumber: debt.phoneNumber,
          notes: debt.notes,
          isPaid: false,
          createdAt: debt.createdAt,
        ), 
        amountPaid, 
        isFullPayment: false
      );

      _showSuccessSnackBar(
          "تم تسديد $amountPaid د.ع من الدين بنجاح. المبلغ المتبقي: $remainingAmount د.ع");
    } catch (e) {
      print("خطأ في تسديد جزء من الدين: $e");
      _showErrorSnackBar("حدث خطأ أثناء تسديد جزء من الدين");
    }
  }

  Future<void> _showConfirmationDialog(DebtModel debt) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('تأكيد العملية'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('اختر طريقة التسديد:'),
                SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accentColor,
                    minimumSize: Size(double.infinity, 50),
                  ),
                  child: Text(
                      'تسديد المبلغ كاملاً (${debt.amount.toStringAsFixed(2)} د.ع)'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    _markAsPaid(debt);
                  },
                ),
                SizedBox(height: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _accentColor,
                    side: BorderSide(color: _accentColor),
                    minimumSize: Size(double.infinity, 50),
                  ),
                  child: Text('تسديد جزء من المبلغ'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    _showPartialPaymentDialog(debt);
                  },
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('إلغاء'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showPartialPaymentDialog(DebtModel debt) async {
    final TextEditingController amountController = TextEditingController();

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('تسديد جزء من الدين'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('المبلغ الكلي: ${debt.amount.toStringAsFixed(2)} د.ع'),
                SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'المبلغ المراد تسديده',
                    hintText: 'أدخل المبلغ',
                    border: OutlineInputBorder(),
                    suffixText: 'د.ع',
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('إلغاء'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentColor,
              ),
              child: Text('تسديد'),
              onPressed: () {
                Navigator.of(context).pop();

                try {
                  final amountPaid = double.parse(amountController.text);

                  if (amountPaid <= 0) {
                    _showErrorSnackBar("يجب أن يكون المبلغ أكبر من صفر");
                    return;
                  }

                  if (amountPaid > debt.amount) {
                    _showErrorSnackBar("المبلغ المدخل أكبر من المبلغ المطلوب");
                    return;
                  }

                  _markPartiallyPaid(debt, amountPaid);
                } catch (e) {
                  _showErrorSnackBar("الرجاء إدخال مبلغ صحيح");
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _addOrUpdateDebt(String? existingUsername) async {
    if (existingUsername != null) {
      // تحويل اسم المستخدم إلى حروف صغيرة للمقارنة
      final lowerUsername = existingUsername.toLowerCase();
      // البحث عن معرف المستخدم باستخدام اسم المستخدم (بغض النظر عن حالة الأحرف)
      int? userId;

      for (var entry in usernameByUserId.entries) {
        if (entry.value.toLowerCase() == lowerUsername) {
          userId = entry.key;
          break;
        }
      }

      if (userId != null) {
        // إذا كان المستخدم موجودًا، اعرض خيارات تحديث الدين
        _showExistingUserOptions(existingUsername, userId);
      } else {
        // المستخدم جديد، أضف دين جديد
        _addNewDebt(existingUsername);
      }
    } else {
      // لم يتم تقديم اسم مستخدم، أضف دين جديد
      _addNewDebt(null);
    }
  }

  Future<void> _showExistingUserOptions(String username, int userId) async {
    final mainDebt = _getMainDebtForUser(userId);

    if (mainDebt == null) {
      _addNewDebt(username);
      return;
    }

    final totalDebt = totalAmountByUserId[userId] ?? 0.0;

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('ديون موجودة لـ $username'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(
                  'يوجد لدى هذا المستخدم ديون مسجلة بالفعل بقيمة ${totalDebt.toStringAsFixed(2)} د.ع',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                Text('اختر الإجراء المطلوب:'),
                SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accentColor,
                    minimumSize: Size(double.infinity, 50),
                  ),
                  child: Text('تحديث الدين الحالي (إضافة إلى المبلغ)'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    _updateExistingDebt(username, mainDebt);
                  },
                ),
                SizedBox(height: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _primaryColor,
                    side: BorderSide(color: _primaryColor),
                    minimumSize: Size(double.infinity, 50),
                  ),
                  child: Text('إضافة دين منفصل جديد'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    _addNewDebt(username, userId);
                  },
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('إلغاء'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

 Future<void> _updateExistingDebt(
    String username, DebtModel existingDebt) async {
  final TextEditingController amountController = TextEditingController();

  return showDialog<void>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('إضافة مبلغ إلى الدين الحالي'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  'المبلغ الحالي: ${existingDebt.amount.toStringAsFixed(2)} د.ع'),
              SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'المبلغ المراد إضافته',
                  hintText: 'أدخل المبلغ الإضافي',
                  border: OutlineInputBorder(),
                  suffixText: 'د.ع',
                ),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: Text('إلغاء'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentColor,
            ),
            child: Text('إضافة'),
            onPressed: () async {
              Navigator.of(context).pop();

              try {
                if (existingDebt.id == null) {
                  _showErrorSnackBar("معرف الدين غير متوفر");
                  return;
                }

                final additionalAmount =
                    double.parse(amountController.text);

                if (additionalAmount <= 0) {
                  _showErrorSnackBar("يجب أن يكون المبلغ أكبر من صفر");
                  return;
                }

                final updatedAmount =
                    existingDebt.amount + additionalAmount;
                await _databaseService.updateDebtAmount(
                    existingDebt.id!, updatedAmount);

                String updateNote;
                if (existingDebt.notes != null &&
                    existingDebt.notes!.isNotEmpty) {
                  updateNote =
                      "${existingDebt.notes} (تمت إضافة ${additionalAmount.toStringAsFixed(2)} د.ع بتاريخ ${DateFormat('yyyy/MM/dd').format(DateTime.now())})";
                } else {
                  updateNote =
                      "(تمت إضافة ${additionalAmount.toStringAsFixed(2)} د.ع بتاريخ ${DateFormat('yyyy/MM/dd').format(DateTime.now())})";
                }

                await _databaseService.updateDebtNotes(
                    existingDebt.id!, updateNote);
                await _loadDebts();
                _showSuccessSnackBar(
                    "تم تحديث الدين بنجاح. المبلغ الجديد: ${updatedAmount.toStringAsFixed(2)} د.ع");
              } catch (e) {
                _showErrorSnackBar("الرجاء إدخال مبلغ صحيح");
              }
            },
          ),
        ],
      );
    },
  );
}

Future<void> _addNewDebt(String? prefilledUsername, [int? userId]) async {
final result = await Navigator.push(
 context,
 MaterialPageRoute(
   builder: (context) => AddDebtScreen(
     token: widget.token,
     existingUsername: prefilledUsername,
     isAddingToExisting: userId != null,
     existingUserId: userId,
   ),
 ),
);

if (result == true) {
 await _loadDebts();
}
}

void _showSortOptions() {
showModalBottomSheet(
 context: context,
 shape: RoundedRectangleBorder(
   borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
 ),
 builder: (context) => Container(
   padding: EdgeInsets.all(16),
   child: Column(
     mainAxisSize: MainAxisSize.min,
     crossAxisAlignment: CrossAxisAlignment.start,
     children: [
       Text(
         'ترتيب حسب',
         style: TextStyle(
           fontSize: 18,
           fontWeight: FontWeight.bold,
           color: _textColor,
         ),
       ),
       SizedBox(height: 16),
       ListTile(
         leading: Icon(
           Icons.calendar_today,
           color: sortOption == 'dueDate' ? _primaryColor : Colors.grey,
         ),
         title: Text('تاريخ الاستحقاق'),
         selected: sortOption == 'dueDate',
         onTap: () {
           setState(() {
             sortOption = 'dueDate';
             _sortDebts();
           });
           Navigator.pop(context);
         },
       ),
       ListTile(
         leading: Icon(
           Icons.attach_money,
           color: sortOption == 'amount' ? _primaryColor : Colors.grey,
         ),
         title: Text('المبلغ (من الأعلى للأقل)'),
         selected: sortOption == 'amount',
         onTap: () {
           setState(() {
             sortOption = 'amount';
             _sortDebts();
           });
           Navigator.pop(context);
         },
       ),
       ListTile(
         leading: Icon(
           Icons.sort_by_alpha,
           color: sortOption == 'name' ? _primaryColor : Colors.grey,
         ),
         title: Text('اسم المستخدم (أبجديًا)'),
         selected: sortOption == 'name',
         onTap: () {
           setState(() {
             sortOption = 'name';
             _sortDebts();
           });
           Navigator.pop(context);
         },
       ),
     ],
   ),
 ),
);
}

@override
Widget build(BuildContext context) {
// الحصول على أبعاد الشاشة
final mediaQuery = MediaQuery.of(context);
final screenWidth = mediaQuery.size.width;
final screenHeight = mediaQuery.size.height;

// حساب الأحجام النسبية
final summaryCardHeight = screenHeight * 0.15; // تقليل الارتفاع قليلاً

return Scaffold(
 backgroundColor: _backgroundColor,
 appBar: AppBar(
   title: Text(
     "إدارة الديون",
     style: TextStyle(
       color: Colors.white,
       fontWeight: FontWeight.bold,
       fontSize: 18,
     ),
   ),
   backgroundColor: _primaryColor,
   elevation: 0,
   shape: const RoundedRectangleBorder(
     borderRadius: BorderRadius.vertical(
       bottom: Radius.circular(16),
     ),
   ),
   actions: [
     IconButton(
       icon: const Icon(Icons.sort, color: Colors.white),
       tooltip: 'ترتيب الديون',
       onPressed: _showSortOptions,
     ),
     IconButton(
       icon: const Icon(Icons.refresh, color: Colors.white),
       tooltip: 'تحديث البيانات',
       onPressed: _loadDebts,
     ),
   ],
 ),
 body: Column(
   children: [
     _buildSummaryCard(summaryCardHeight),
     _buildSearchBar(),
     if (isLoading)
       Container(
         padding: EdgeInsets.symmetric(vertical: 8),
         child: Center(
           child: CircularProgressIndicator(color: _primaryColor),
         ),
       ),
     Expanded(
       child: isLoading
           ? Center(child: Text("جاري تحميل البيانات..."))
           : filteredDebts.isEmpty
               ? _buildEmptyState()
               : _buildUserDebtsList(),
     ),
   ],
 ),
 floatingActionButton: FloatingActionButton(
   backgroundColor: _accentColor,
   child: Icon(Icons.add, size: 24),
   onPressed: () {
     final TextEditingController usernameController =
         TextEditingController();
     showDialog(
       context: context,
       builder: (context) => AlertDialog(
         title: Text('إضافة دين جديد'),
         content: Column(
           mainAxisSize: MainAxisSize.min,
           children: [
             Text('أدخل اسم المستخدم للتحقق من وجود ديون سابقة'),
             SizedBox(height: 10),
             TextField(
               controller: usernameController,
               decoration: InputDecoration(
                 labelText: 'اسم المستخدم',
                 border: OutlineInputBorder(),
               ),
             ),
           ],
         ),
         actions: [
           TextButton(
             onPressed: () {
               Navigator.pop(context);
             },
             child: Text('إلغاء'),
           ),
           ElevatedButton(
             style: ElevatedButton.styleFrom(
               backgroundColor: _accentColor,
             ),
             onPressed: () {
               Navigator.pop(context);
               final username = usernameController.text.trim();
               if (username.isNotEmpty) {
                 _addOrUpdateDebt(username);
               } else {
                 _addOrUpdateDebt(null);
               }
             },
             child: Text('متابعة'),
           ),
         ],
       ),
     );
   },
   tooltip: 'إضافة دين جديد',
 ),
);
}
// إنشاء بطاقة ملخص
Widget _buildSummaryCard(double height) {
  final overdueDebts =
      allDebts.where((debt) => debt.dueDate.isBefore(DateTime.now())).length;

  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    height: height,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [_primaryColor, _primaryColor.withOpacity(0.8)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: _primaryColor.withOpacity(0.2),
          blurRadius: 6,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // إجمالي الديون المستحقة
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "إجمالي الديون المستحقة:",
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              "${totalUnpaid.toStringAsFixed(2)} د.ع",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        SizedBox(height: 4),

        // عدد الديون غير المسددة
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "عدد الديون غير المسددة:",
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 12,
              ),
            ),
            Text(
              "${allDebts.length}",
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        SizedBox(height: 4),

        // عدد المستخدمين
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "عدد المستخدمين:",
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 12,
              ),
            ),
            Text(
              "${uniqueUserIds.length}",
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        SizedBox(height: 4),

        // ديون متأخرة - إصلاح التنسيق
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                "ديون متأخرة:",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 11, // أصغر
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding:
                  EdgeInsets.symmetric(horizontal: 6, vertical: 1), // أصغر
              decoration: BoxDecoration(
                color: overdueDebts > 0 ? Colors.red : Colors.green,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                "$overdueDebts",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11, // أصغر
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

Widget _buildSearchBar() {
  return Padding(
    padding: const EdgeInsets.symmetric(
        horizontal: 12, vertical: 6), // تقليل البطانة
    child: Container(
      height: 40, // تحديد ارتفاع ثابت للبحث
      child: TextField(
        decoration: InputDecoration(
          hintText: "البحث عن مستخدم أو ملاحظات...",
          hintStyle: TextStyle(fontSize: 12), // تصغير حجم خط التلميح
          prefixIcon: Icon(Icons.search,
              color: _primaryColor, size: 18), // تصغير أيقونة البحث
          suffixIcon: Icon(Icons.filter_list,
              color: _primaryColor, size: 18), // تصغير أيقونة الفلتر
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: _primaryColor, width: 1),
          ),
          filled: true,
          fillColor: _secondaryColor,
          contentPadding: EdgeInsets.symmetric(
              vertical: 0, horizontal: 10), // تقليل التباعد الداخلي
        ),
        style: TextStyle(fontSize: 13), // تصغير حجم خط الإدخال
        onChanged: _filterDebts,
      ),
    ),
  );
}

// عرض قائمة المستخدمين الفريدة
Widget _buildUserDebtsList() {
  // عرض قائمة المستخدمين الفريدة فقط (بدون تكرار)
  final usersToShow = uniqueUserIds.toList();

  return ListView.builder(
    padding: const EdgeInsets.all(10),
    itemCount: usersToShow.length,
    itemBuilder: (context, index) {
      final userId = usersToShow[index];
      final username = usernameByUserId[userId] ?? "مستخدم غير معروف";
      final userDebts = debtsByUserId[userId] ?? [];

      if (userDebts.isEmpty) return SizedBox.shrink();

      // استخدم الدين الأحدث للعرض الرئيسي
      userDebts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final mainDebt = userDebts.first;

      return _buildDebtCard(mainDebt, userDebts, userId);
    },
  );
}

Widget _buildDebtCard(
    DebtModel mainDebt, List<DebtModel> allUserDebts, int userId) {
  final isPastDue = mainDebt.dueDate.isBefore(DateTime.now());
  final daysLeft = mainDebt.dueDate.difference(DateTime.now()).inDays;
  final hasMultipleDebts = allUserDebts.length > 1;
  final totalUserDebt = totalAmountByUserId[userId] ?? mainDebt.amount;

  return Card(
    margin: const EdgeInsets.only(bottom: 8),
    elevation: 2, // تقليل الظل
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: isPastDue
          ? BorderSide(color: Colors.red, width: 1)
          : BorderSide.none,
    ),
    child: Padding(
      padding: const EdgeInsets.all(10), // تقليل البطانة
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    backgroundColor: _primaryColor,
                    radius: 16, // تصغير الصورة الرمزية
                    child: Text(
                      mainDebt.username.isNotEmpty
                          ? mainDebt.username[0].toUpperCase()
                          : "?",
                      style: TextStyle(
                        fontSize: 14, // تصغير حجم الخط
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (hasMultipleDebts)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: EdgeInsets.all(2), // تقليل البطانة
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1),
                        ),
                        child: Text(
                          "${allUserDebts.length}",
                          style: TextStyle(
                            fontSize: 8, // تصغير حجم الخط
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mainDebt.username,
                      style: TextStyle(
                        fontSize: 14, // تصغير حجم الخط
                        fontWeight: FontWeight.bold,
                        color: _textColor,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          "تاريخ الإنشاء: ${DateFormat('yyyy/MM/dd').format(mainDebt.createdAt)}",
                          style: TextStyle(
                            fontSize: 10, // تصغير حجم الخط
                            color: Colors.grey.shade600,
                          ),
                        ),
                        if (hasMultipleDebts)
                          Text(
                            " • له ديون متعددة",
                            style: TextStyle(
                              fontSize: 10, // تصغير حجم الخط
                              color: Colors.amber.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isPastDue
                      ? Colors.red.withOpacity(0.2)
                      : daysLeft <= 7 && daysLeft >= 0
                          ? Colors.amber.withOpacity(0.2)
                          : _primaryColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isPastDue
                      ? "متأخر"
                      : daysLeft <= 7 && daysLeft >= 0
                          ? "قريب"
                          : "مستحق",
                  style: TextStyle(
                    fontSize: 10, // تصغير حجم الخط
                    fontWeight: FontWeight.bold,
                    color: isPastDue
                        ? Colors.red
                        : daysLeft <= 7 && daysLeft >= 0
                            ? Colors.amber.shade800
                            : _primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8), // تقليل البطانة
            decoration: BoxDecoration(
              color: _secondaryColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      hasMultipleDebts ? "إجمالي المبلغ:" : "المبلغ المستحق:",
                      style: TextStyle(
                        fontSize: 12, // تصغير حجم الخط
                        color: Colors.grey.shade700,
                      ),
                    ),
                    Text(
                      hasMultipleDebts
                          ? "${totalUserDebt.toStringAsFixed(2)} د.ع"
                          : "${mainDebt.amount.toStringAsFixed(2)} د.ع",
                      style: TextStyle(
                        fontSize: 14, // تصغير حجم الخط
                        fontWeight: FontWeight.bold,
                        color: _textColor,
                      ),
                    ),
                  ],
                ),
                if (hasMultipleDebts) ...[
                  const SizedBox(height: 2), // تقليل المسافة
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "المبلغ الحالي:",
                        style: TextStyle(
                          fontSize: 10, // تصغير حجم الخط
                          color: Colors.grey.shade700,
                        ),
                      ),
                      Text(
                        "${mainDebt.amount.toStringAsFixed(2)} د.ع",
                        style: TextStyle(
                          fontSize: 10, // تصغير حجم الخط
                          color: _textColor,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 4), // تقليل المسافة
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "تاريخ الاستحقاق:",
                      style: TextStyle(
                        fontSize: 12, // تصغير حجم الخط
                        color: Colors.grey.shade700,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          DateFormat('yyyy/MM/dd').format(mainDebt.dueDate),
                          style: TextStyle(
                            fontSize: 12, // تصغير حجم الخط
                            fontWeight: FontWeight.bold,
                            color: isPastDue ? Colors.red : _textColor,
                          ),
                        ),
                        if (!isPastDue && daysLeft <= 14)
                          Container(
                            margin: EdgeInsets.only(right: 4),
                            padding: EdgeInsets.symmetric(
                                horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: daysLeft <= 3
                                  ? Colors.red.withOpacity(0.2)
                                  : daysLeft <= 7
                                      ? Colors.amber.withOpacity(0.2)
                                      : Colors.green.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              "متبقي $daysLeft يوم",
                              style: TextStyle(
                                fontSize: 8, // تصغير حجم الخط
                                fontWeight: FontWeight.bold,
                                color: daysLeft <= 3
                                    ? Colors.red
                                    : daysLeft <= 7
                                        ? Colors.amber.shade800
                                        : Colors.green,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                if (mainDebt.phoneNumber != null &&
                    mainDebt.phoneNumber!.isNotEmpty) ...[
                  const SizedBox(height: 4), // تقليل المسافة
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "رقم الهاتف:",
                        style: TextStyle(
                          fontSize: 12, // تصغير حجم الخط
                          color: Colors.grey.shade700,
                        ),
                      ),
                      Text(
                        mainDebt.phoneNumber!,
                        style: TextStyle(
                          fontSize: 12, // تصغير حجم الخط
                          color: _textColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (mainDebt.notes != null && mainDebt.notes!.isNotEmpty) ...[
            const SizedBox(height: 6), // تقليل المسافة
            ExpansionTile(
              title: Text(
                "ملاحظات",
                style: TextStyle(
                  fontSize: 12, // تصغير حجم الخط
                  fontWeight: FontWeight.bold,
                  color: _textColor,
                ),
              ),
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              children: [
                Container(
                  padding: EdgeInsets.all(8), // تقليل البطانة
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    mainDebt.notes!,
                    style: TextStyle(
                      fontSize: 12, // تصغير حجم الخط
                      color: _textColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (hasMultipleDebts) ...[
            const SizedBox(height: 6), // تقليل المسافة
            ExpansionTile(
              title: Text(
                "ديون أخرى لنفس المستخدم",
                style: TextStyle(
                  fontSize: 12, // تصغير حجم الخط
                  fontWeight: FontWeight.bold,
                  color: Colors.amber.shade800,
                ),
              ),
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              children: [
                Container(
                  padding: EdgeInsets.all(8), // تقليل البطانة
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    children: allUserDebts
                        .where((d) => d.id != mainDebt.id)
                        .map((otherDebt) => Container(
                              margin:
                                  EdgeInsets.only(bottom: 6), // تقليل المسافة
                              padding: EdgeInsets.all(6), // تقليل البطانة
                              decoration: BoxDecoration(
                                border:
                                    Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "المبلغ: ${otherDebt.amount.toStringAsFixed(2)} د.ع",
                                        style: TextStyle(
                                          fontSize: 11, // تصغير حجم الخط
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 4, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: otherDebt.dueDate
                                                  .isBefore(DateTime.now())
                                              ? Colors.red.withOpacity(0.2)
                                              : Colors.green.withOpacity(0.2),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          otherDebt.dueDate
                                                  .isBefore(DateTime.now())
                                              ? "متأخر"
                                              : "مستحق",
                                          style: TextStyle(
                                            fontSize: 8, // تصغير حجم الخط
                                            fontWeight: FontWeight.bold,
                                            color: otherDebt.dueDate
                                                    .isBefore(DateTime.now())
                                                ? Colors.red
                                                : Colors.green,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    "تاريخ الاستحقاق: ${DateFormat('yyyy/MM/dd').format(otherDebt.dueDate)}",
                                    style: TextStyle(
                                        fontSize: 10), // تصغير حجم الخط
                                  ),
                                  if (otherDebt.notes != null &&
                                      otherDebt.notes!.isNotEmpty)
                                    Text(
                                      "ملاحظات: ${otherDebt.notes}",
                                      style: TextStyle(
                                        fontSize: 10, // تصغير حجم الخط
                                        color: Colors.grey.shade600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  SizedBox(height: 4), // تقليل المسافة
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton.icon(
                                        onPressed: () =>
                                            _showConfirmationDialog(
                                                otherDebt),
                                        icon: Icon(Icons.paid,
                                            size: 14), // تصغير حجم الأيقونة
                                        label: Text(
                                          "تسديد هذا الدين",
                                          style: TextStyle(
                                              fontSize: 10), // تصغير حجم الخط
                                        ),
                                        style: TextButton.styleFrom(
                                          foregroundColor: _accentColor,
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2), // تقليل البطانة
                                          tapTargetSize: MaterialTapTargetSize
                                              .shrinkWrap,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showConfirmationDialog(mainDebt),
                  icon: const Icon(Icons.check_circle,
                      size: 16), // تصغير حجم الأيقونة
                  label: const Text(
                    "تسديد الدين",
                    style: TextStyle(fontSize: 12), // تصغير حجم الخط
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        vertical: 8), // تقليل البطانة
                    minimumSize: Size(0, 36), // تقليل الحجم الأدنى
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 6),
              SizedBox(
                width: 36, // تحديد عرض ثابت
                height: 36, // تحديد ارتفاع ثابت
                child: IconButton(
                  onPressed: () async {
                    if (mainDebt.phoneNumber == null ||
                        mainDebt.phoneNumber!.isEmpty) {
                      _showErrorSnackBar("رقم الهاتف غير متوفر لإرسال تذكير");
                      return;
                    }

                    final message =
                        "تذكير بالدين المستحق بقيمة ${mainDebt.amount.toStringAsFixed(2)} د.ع بتاريخ ${DateFormat('yyyy/MM/dd').format(mainDebt.dueDate)}";
                    String phoneNumber = mainDebt.phoneNumber!;

                    // تنظيف رقم الهاتف بنفس طريقة _sendWhatsAppMessage
                    phoneNumber = phoneNumber.replaceAll(RegExp(r'\s+'), '');
                    phoneNumber = phoneNumber.replaceAll(RegExp(r'[+()-]'), '');
                    
                    if (phoneNumber.startsWith('0')) {
                      phoneNumber = '964' + phoneNumber.substring(1);
                    } else if (!phoneNumber.startsWith('964')) {
                      phoneNumber = '964' + phoneNumber;
                    }

                    final encodedMessage = Uri.encodeComponent(message);
                    final whatsappUri = Uri.parse(
                      "whatsapp://send?phone=$phoneNumber&text=$encodedMessage"
                    );

                    try {
                      bool launched = await launchUrl(
                        whatsappUri,
                        mode: LaunchMode.externalNonBrowserApplication,
                      );
                      
                      if (launched) {
                        _showSuccessSnackBar("تم فتح تطبيق واتساب");
                      } else {
                        final whatsappUriFallback = Uri.parse(
                          "https://api.whatsapp.com/send?phone=$phoneNumber&text=$encodedMessage"
                        );
                        
                        if (await canLaunchUrl(whatsappUriFallback)) {
                          await launchUrl(whatsappUriFallback, mode: LaunchMode.externalApplication);
                          _showSuccessSnackBar("تم فتح تطبيق واتساب");
                        } else {
                          _showErrorSnackBar("لا يمكن فتح تطبيق واتساب");
                        }
                      }
                    } catch (e) {
                      _showErrorSnackBar("حدث خطأ أثناء محاولة فتح واتساب");
                    }
                  },
                  icon: Icon(Icons.notifications_active,
                      size: 18), // تصغير حجم الأيقونة
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.amber.shade700,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.zero, // إزالة البطانة الداخلية
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ),
              if (mainDebt.phoneNumber != null &&
                  mainDebt.phoneNumber!.isNotEmpty) ...[
                SizedBox(width: 6),
                SizedBox(
                  width: 36, // تحديد عرض ثابت
                  height: 36, // تحديد ارتفاع ثابت
                  child: IconButton(
                    onPressed: () async {
                      String phoneNumber = mainDebt.phoneNumber!;
                      final Uri phoneUri =
                          Uri(scheme: 'tel', path: phoneNumber);
                      try {
                        if (await canLaunchUrl(phoneUri)) {
                          await launchUrl(phoneUri);
                        } else {
                          _showErrorSnackBar("لا يمكن الاتصال بالرقم");
                        }
                      } catch (e) {
                        _showErrorSnackBar("حدث خطأ أثناء محاولة الاتصال");
                      }
                    },
                    icon: Icon(Icons.phone, size: 18), // تصغير حجم الأيقونة
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.zero, // إزالة البطانة الداخلية
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    ),
  );
}

Widget _buildEmptyState() {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.money_off,
          size: 48, // تصغير حجم الأيقونة
          color: Colors.grey.shade300,
        ),
        const SizedBox(height: 12),
        Text(
          "لا توجد ديون مسجلة",
          style: TextStyle(
            fontSize: 16, // تصغير حجم الخط
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          "سيتم عرض الديون المسجلة للمشتركين هنا",
          style: TextStyle(
            fontSize: 12, // تصغير حجم الخط
            color: Colors.grey.shade500,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          icon: Icon(Icons.add, size: 16), // تصغير حجم الأيقونة
          label: Text(
            "إضافة دين جديد",
            style: TextStyle(fontSize: 14), // تصغير حجم الخط
          ),
          onPressed: () => _addOrUpdateDebt(null),
          style: ElevatedButton.styleFrom(
            backgroundColor: _accentColor,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8), // تقليل البطانة
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
      ],
    ),
  );
}
}
