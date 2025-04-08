import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/database_service.dart';
import '../models/debt_model.dart';

/// **?? شاشة تفاصيل المستخدم**
/// تعرض معلومات المستخدم المفصلة وديونه المستحقة
class UserDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final String token;

  const UserDetailsScreen({
    Key? key,
    required this.user,
    required this.token,
  }) : super(key: key);

  @override
  _UserDetailsScreenState createState() => _UserDetailsScreenState();
}

class _UserDetailsScreenState extends State<UserDetailsScreen> {
  // ????????????????????????????????????????
  // ?? خصائص الحالة
  // ????????????????????????????????????????
  final DatabaseService _databaseService = DatabaseService.instance;
  List<DebtModel> _userDebts = [];
  bool _isLoadingDebts = true;
  bool _hasError = false;

  // ألوان ثابتة للواجهة
  final Color _primaryColor = Colors.indigo.shade600;
  final Color _accentColor = Colors.green.shade600;
  final Color _warningColor = Colors.amber.shade700;
  final Color _errorColor = Colors.red.shade700;
  final Color _textPrimaryColor = Colors.black87;
  final Color _textSecondaryColor = Colors.grey.shade600;
  final Color _backgroundColor = Colors.grey.shade50;

  // ????????????????????????????????????????
  // ?? دوال دورة الحياة
  // ????????????????????????????????????????
  @override
  void initState() {
    super.initState();
    _loadUserDebts();
  }

  // ????????????????????????????????????????
  // ?? دوال جلب وتحميل البيانات
  // ????????????????????????????????????????

  /// تحميل ديون المستخدم من قاعدة البيانات
  Future<void> _loadUserDebts() async {
    setState(() {
      _isLoadingDebts = true;
      _hasError = false;
    });

    try {
      final username = widget.user['username'] ?? '';
      if (username.isEmpty) {
        setState(() {
          _userDebts = [];
          _isLoadingDebts = false;
        });
        return;
      }

      // استخدام دالة getAllDebts ثم فلترة النتائج حسب اسم المستخدم
      final allDebts = await _databaseService.getAllDebts();
      final userDebts = allDebts.where((debt) => 
        debt.username.toLowerCase() == username.toLowerCase()
      ).toList();
      
      setState(() {
        _userDebts = userDebts.where((debt) => !debt.isPaid).toList();
        _isLoadingDebts = false;
      });
    } catch (e) {
      debugPrint("? خطأ في تحميل ديون المستخدم: $e");
      setState(() {
        _hasError = true;
        _isLoadingDebts = false;
      });
    }
  }

  // ????????????????????????????????????????
  // ?? دوال المساعدة والحسابات
  // ????????????????????????????????????????

  /// الحصول على لون حالة المستخدم بناءً على تاريخ انتهاء الاشتراك
  Color _getUserStatus(String? expirationDate) {
    if (expirationDate == null || expirationDate.isEmpty) return Colors.grey;

    try {
      DateTime expiryDate = DateFormat("yyyy-MM-dd HH:mm:ss").parse(expirationDate);
      DateTime now = DateTime.now();
      int daysRemaining = expiryDate.difference(now).inDays;
      
      if (now.isAfter(expiryDate)) {
        return Colors.red.shade400; // Expired
      } else if (daysRemaining <= 7) {
        return Colors.orange.shade400; // Expiring soon
      } else {
        return Colors.green.shade400; // Active
      }
    } catch (e) {
      return Colors.grey.shade400;
    }
  }

  /// الحصول على نص حالة المستخدم بناءً على تاريخ انتهاء الاشتراك
  String _getStatusText(String? expirationDate) {
    if (expirationDate == null || expirationDate.isEmpty) return "غير محدد";

    try {
      DateTime expiryDate = DateFormat("yyyy-MM-dd HH:mm:ss").parse(expirationDate);
      DateTime now = DateTime.now();
      int daysRemaining = expiryDate.difference(now).inDays;
      
      if (now.isAfter(expiryDate)) {
        return "منتهي";
      } else if (daysRemaining <= 7) {
        return "ينتهي قريباً";
      } else {
        return "نشط";
      }
    } catch (e) {
      return "غير محدد";
    }
  }

  /// تنسيق التاريخ بشكل مقروء
  String _getFormattedDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "—";
    
    try {
      DateTime date = DateFormat("yyyy-MM-dd HH:mm:ss").parse(dateStr);
      return DateFormat("yyyy/MM/dd").format(date);
    } catch (e) {
      return "—";
    }
  }

  /// حساب الأيام المتبقية حتى انتهاء الاشتراك
  String _getRemainingDays(String? expirationDate) {
    if (expirationDate == null || expirationDate.isEmpty) return "";

    try {
      DateTime expiryDate = DateFormat("yyyy-MM-dd HH:mm:ss").parse(expirationDate);
      DateTime now = DateTime.now();
      int daysRemaining = expiryDate.difference(now).inDays;
      
      if (now.isAfter(expiryDate)) {
        return "منتهي منذ ${now.difference(expiryDate).inDays} يوم";
      } else {
        return "متبقي $daysRemaining يوم";
      }
    } catch (e) {
      return "";
    }
  }

  /// حساب إجمالي الديون المستحقة
  String _calculateTotalDebt() {
    double total = 0.0;
    for (var debt in _userDebts) {
      total += debt.amount;
    }
    return total.toStringAsFixed(2);
  }

  // ????????????????????????????????????????
  // ?? دوال الاتصال
  // ????????????????????????????????????????

  /// إجراء مكالمة هاتفية
  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    await launchUrl(launchUri);
  }

  /// إرسال رسالة عبر WhatsApp
  Future<void> _sendWhatsAppMessage(String phoneNumber) async {
    // تنظيف رقم الهاتف
    String cleanedPhone = phoneNumber.replaceAll(RegExp(r'\s+'), '');
    cleanedPhone = cleanedPhone.replaceAll(RegExp(r'[+()-]'), '');
    
    // تنسيق رقم الهاتف للعراق
    if (cleanedPhone.startsWith('0')) {
      cleanedPhone = '964' + cleanedPhone.substring(1);
    } else if (!cleanedPhone.startsWith('964')) {
      cleanedPhone = '964' + cleanedPhone;
    }

    try {
      final Uri whatsappUri = Uri.parse("https://wa.me/$cleanedPhone");
      await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("فشل فتح واتساب: $e"),
          backgroundColor: _errorColor,
        ),
      );
    }
  }

  /// إرسال رسالة نصية SMS
  Future<void> _sendSMS(String phoneNumber) async {
    final Uri smsUri = Uri(
      scheme: 'sms',
      path: phoneNumber,
    );
    await launchUrl(smsUri);
  }

  // ????????????????????????????????????????
  // ?? بناء الواجهة الرئيسية
  // ????????????????????????????????????????
  @override
  Widget build(BuildContext context) {
    // استخراج بيانات المستخدم
    final fullName = "${widget.user['firstname'] ?? ''} ${widget.user['lastname'] ?? ''}".trim();
    final username = widget.user['username'] ?? "غير معروف";
    final phoneNumber = widget.user['phone'] ?? "";
    final userType = widget.user['userType'] ?? "قياسي";
    final expiryDate = widget.user['expiration'];
    
    // معالجة بيانات الحالة
    final statusColor = _getUserStatus(expiryDate);
    final statusText = _getStatusText(expiryDate);
    final formattedExpiryDate = _getFormattedDate(expiryDate);
    final remainingDays = _getRemainingDays(expiryDate);
    
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildUserHeader(fullName, username, statusColor, statusText),
            const SizedBox(height: 24),
            _buildSubscriptionSection(formattedExpiryDate, remainingDays, statusColor, userType),
            const SizedBox(height: 24),
            if (phoneNumber.isNotEmpty) _buildContactSection(phoneNumber),
            const SizedBox(height: 24),
            _buildDebtsSection(),
          ],
        ),
      ),
    );
  }

  // ????????????????????????????????????????
  // ?? مكونات واجهة المستخدم
  // ????????????????????????????????????????

  /// بناء شريط التطبيق
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(
        "تفاصيل المشترك",
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
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
          icon: const Icon(Icons.refresh, color: Colors.white),
          onPressed: _loadUserDebts,
          tooltip: 'تحديث البيانات',
        ),
      ],
    );
  }

  /// بناء رأس معلومات المستخدم
  Widget _buildUserHeader(String fullName, String username, Color statusColor, String statusText) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // صورة المستخدم
            CircleAvatar(
              backgroundColor: Colors.indigo.shade100,
              radius: 40,
              child: Text(
                fullName.isNotEmpty && fullName.length > 0 ? fullName[0].toUpperCase() : 
                  username.isNotEmpty && username.length > 0 ? username[0].toUpperCase() : "؟",
                style: TextStyle(
                  color: Colors.indigo.shade800,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 20),
            // معلومات المستخدم
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // اسم المستخدم
                  Text(
                    fullName.isEmpty ? "غير معروف" : fullName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // اسم المستخدم في النظام
                  Text(
                    "@$username",
                    style: TextStyle(
                      fontSize: 16,
                      color: _textSecondaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // حالة المستخدم
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor.withOpacity(0.5), width: 1),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor.withOpacity(0.8),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// بناء قسم معلومات الاشتراك
  Widget _buildSubscriptionSection(String expiryDate, String remainingDays, Color statusColor, String userType) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // عنوان القسم
            Row(
              children: [
                Icon(Icons.card_membership, color: _primaryColor),
                const SizedBox(width: 8),
                Text(
                  "معلومات الاشتراك",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _textPrimaryColor,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            // نوع الاشتراك
            _buildInfoRow("نوع الاشتراك:", userType, Icons.star_border),
            const SizedBox(height: 16),
            // تاريخ انتهاء الاشتراك
            _buildInfoRow("تاريخ الانتهاء:", expiryDate, Icons.calendar_today),
            // الأيام المتبقية
            if (remainingDays.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                margin: const EdgeInsets.only(right: 32),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withOpacity(0.3), width: 1),
                ),
                child: Text(
                  remainingDays,
                  style: TextStyle(
                    color: statusColor.withOpacity(0.8),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// بناء قسم معلومات الاتصال
  Widget _buildContactSection(String phoneNumber) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // عنوان القسم
            Row(
              children: [
                Icon(Icons.contact_phone, color: _primaryColor),
                const SizedBox(width: 8),
                Text(
                  "معلومات الاتصال",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _textPrimaryColor,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            // رقم الهاتف
            _buildInfoRow("رقم الهاتف:", phoneNumber, Icons.phone),
            const SizedBox(height: 16),
            // أزرار الاتصال
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildContactButton(
                  icon: Icons.phone,
                  text: "اتصال",
                  color: _accentColor,
                  onPressed: () => _makePhoneCall(phoneNumber),
                ),
                _buildContactButton(
                  icon: Icons.message,
                  text: "رسالة",
                  color: _warningColor,
                  onPressed: () => _sendSMS(phoneNumber),
                ),
                _buildContactButton(
                  icon: Icons.chat,
                  text: "واتساب",
                  color: _accentColor,
                  onPressed: () => _sendWhatsAppMessage(phoneNumber),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// بناء زر الاتصال
  Widget _buildContactButton({
    required IconData icon,
    required String text,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(text),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  /// بناء قسم الديون المستحقة
  Widget _buildDebtsSection() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // عنوان القسم مع عدد الديون
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.account_balance_wallet, color: _primaryColor),
                    const SizedBox(width: 8),
                    Text(
                      "الديون المستحقة",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _textPrimaryColor,
                      ),
                    ),
                  ],
                ),
                // عدد الديون
                if (!_isLoadingDebts && !_hasError && _userDebts.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      "${_userDebts.length}",
                      style: TextStyle(
                        color: _errorColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const Divider(height: 24),
            
            // عرض محتوى القسم حسب الحالة
            if (_isLoadingDebts)
              _buildLoadingDebtState()
            else if (_hasError)
              _buildErrorDebtState()
            else if (_userDebts.isEmpty)
              _buildEmptyDebtState()
            else
              _buildDebtList(),
          ],
        ),
      ),
    );
  }

  /// حالة جاري تحميل الديون
  Widget _buildLoadingDebtState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: CircularProgressIndicator(color: _primaryColor),
      ),
    );
  }

  /// حالة وجود خطأ في تحميل الديون
  Widget _buildErrorDebtState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(Icons.error_outline, color: _errorColor, size: 48),
            const SizedBox(height: 16),
            Text(
              "حدث خطأ أثناء تحميل البيانات",
              style: TextStyle(color: _errorColor),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _loadUserDebts,
              icon: const Icon(Icons.refresh),
              label: const Text("إعادة المحاولة"),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// حالة عدم وجود ديون مستحقة
  Widget _buildEmptyDebtState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(Icons.check_circle, color: _accentColor, size: 48),
            const SizedBox(height: 16),
            Text(
              "لا توجد ديون مستحقة لهذا المستخدم",
              style: TextStyle(
                color: _accentColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// بناء قائمة الديون
  Widget _buildDebtList() {
    return Column(
      children: [
        // عرض كل دين في بطاقة منفصلة
        ..._userDebts.map((debt) => _buildDebtCard(debt)).toList(),
        const SizedBox(height: 16),
        // عرض المجموع النهائي
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "المجموع:",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _textPrimaryColor,
                ),
              ),
              Text(
                "${_calculateTotalDebt()} د.ع",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _errorColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// بناء بطاقة الدين
  Widget _buildDebtCard(DebtModel debt) {
    final isPastDue = debt.dueDate.isBefore(DateTime.now());
    final formattedDueDate = DateFormat('yyyy/MM/dd').format(debt.dueDate);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isPastDue ? Colors.red.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isPastDue ? Colors.red.shade200 : Colors.grey.shade300,
        ),
      ),
      child: Column(
        children: [
          // المبلغ المستحق
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "المبلغ:",
                style: TextStyle(
                  fontSize: 14,
                  color: _textSecondaryColor,
                ),
              ),
              Text(
                "${debt.amount.toStringAsFixed(2)} د.ع",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isPastDue ? _errorColor : _textPrimaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // تاريخ الاستحقاق
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "تاريخ الاستحقاق:",
                style: TextStyle(
                  fontSize: 14,
                  color: _textSecondaryColor,
                ),
              ),
              Row(
                children: [
                  Text(
                    formattedDueDate,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isPastDue ? _errorColor : _textPrimaryColor,
                    ),
                  ),
                  // ملصق "متأخر" إذا كان الدين متأخرًا
                  if (isPastDue) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        "متأخر",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _errorColor,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          // الملاحظات إذا وجدت
          if (debt.notes != null && debt.notes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Divider(height: 8),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "ملاحظات:",
                  style: TextStyle(
                    fontSize: 14,
                    color: _textSecondaryColor,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    debt.notes!,
                    style: TextStyle(
                      fontSize: 14,
                      color: _textPrimaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// بناء صف معلومات (عنوان، قيمة)
  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.indigo.shade300),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            color: _textSecondaryColor,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _textPrimaryColor,
            ),
            textAlign: TextAlign.left,
          ),
        ),
      ],
    );
  }
}