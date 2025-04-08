import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui';
import '../services/company_configs.dart';
import '../services/api_service.dart';
import '../services/global_company.dart';
import '../styles/app_colors.dart';

class CompanySelector extends StatefulWidget {
  final Function(String)? onCompanySelected;

  const CompanySelector({Key? key, this.onCompanySelected}) : super(key: key);

  @override
  State<CompanySelector> createState() => _CompanySelectorState();
}

class _CompanySelectorState extends State<CompanySelector>
    with SingleTickerProviderStateMixin {
  // ========== الثوابت ==========
  static const String _prefsKey = 'selected_company';
  static const Duration _statusMessageDuration = Duration(seconds: 3);

  // ========== متغيرات الحالة ==========
  String _selectedCompany = availableCompanies.first.name;
  bool _isLoading = true;
  String _connectionStatus = '';
  bool _showConnectionStatus = false;

  // ========== متغيرات الرسوم المتحركة ==========
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadSelectedCompany();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // ========== إعداد الرسوم المتحركة ==========
  void _setupAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
  }

  // ========== إدارة البيانات ==========
  Future<void> _loadSelectedCompany() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCompany = prefs.getString(_prefsKey);

      debugPrint("🔍 محاولة تحميل الشركة المحفوظة: $savedCompany");

      if (savedCompany != null && savedCompany.isNotEmpty) {
        setState(() {
          _selectedCompany = savedCompany;
          _isLoading = false;
        });

        // تحديث الشركة العالمية
        final company = findCompanyByName(savedCompany);
        if (company != null) {
          GlobalCompany.setCompany(company);
          debugPrint("✅ تم تحديث الشركة العالمية: ${company.name}");
        }
      } else {
        // استخدام الشركة الأولى
        final company = availableCompanies.first;
        GlobalCompany.setCompany(company);
        await prefs.setString(_prefsKey, company.name);
        setState(() {
          _selectedCompany = company.name;
          _isLoading = false;
        });
        debugPrint("ℹ️ تم استخدام الشركة الافتراضية: ${company.name}");
      }

      // بدء الرسوم المتحركة
      _animationController.forward();
    } catch (e) {
      debugPrint("❌ خطأ أثناء تحميل الشركة: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSelectedCompany(String companyName) async {
    if (companyName == _selectedCompany) {
      // إذا كانت نفس الشركة المختارة بالفعل، انتقل مباشرة إلى الصفحة التالية
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _isLoading = true;
      _showConnectionStatus = true;
      _connectionStatus = 'جاري حفظ الشركة...';
    });

    try {
      final company = findCompanyByName(companyName);
      if (company == null) {
        debugPrint("⚠️ لم يتم العثور على الشركة: $companyName");
        setState(() {
          _isLoading = false;
          _connectionStatus = 'خطأ: الشركة غير موجودة';
        });
        return;
      }

      // تعيين الشركة عالمياً
      GlobalCompany.setCompany(company);

      // حفظ في التخزين المشترك
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, companyName);

      // إنشاء ApiService واختبار الاتصال
      final apiService = ApiService.fromCompanyConfig(company);
      apiService.printServiceInfo();

      await apiService.saveSelectedCompany();

      if (widget.onCompanySelected != null) {
        widget.onCompanySelected!(companyName);
      }

      setState(() {
        _selectedCompany = companyName;
        _isLoading = false;
        _connectionStatus = 'تم حفظ الشركة بنجاح';
      });

      debugPrint("✅ تم حفظ الشركة المحددة: $companyName");
      
      // انتقل مباشرة إلى صفحة تسجيل الدخول بعد الانتهاء من الحفظ
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _connectionStatus = 'خطأ: $e';
      });
      debugPrint("❌ خطأ أثناء حفظ الشركة: $e");
      
      // إخفاء رسالة الخطأ بعد 3 ثوانٍ
      Future.delayed(_statusMessageDuration, () {
        if (mounted) {
          setState(() {
            _showConnectionStatus = false;
          });
        }
      });
    }
  }

  // ========== بناء واجهة المستخدم ==========
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: _isLoading ? _buildLoadingScreen() : _buildMainScreen(),
    );
  }

  // شاشة التحميل
  Widget _buildLoadingScreen() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.blue.withOpacity(0.9),
            AppColors.blue.withOpacity(0.6),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "جاري تحميل البيانات...",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // الشاشة الرئيسية
  Widget _buildMainScreen() {
    return Stack(
      children: [
        // الخلفية
        _buildBackground(),

        // المحتوى الرئيسي
        SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: _buildContent(),
              ),
            ],
          ),
        ),

        // رسالة الحالة
        if (_showConnectionStatus) _buildStatusMessage(),
      ],
    );
  }

  // بناء خلفية الشاشة
  Widget _buildBackground() {
    return Stack(
      children: [
        // خلفية متدرجة
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.blue.withOpacity(0.1),
                Colors.white,
              ],
              stops: const [0.0, 0.3],
            ),
          ),
        ),

        // زخارف الخلفية
        Positioned(
          top: -80,
          right: -60,
          child: Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              color: AppColors.blue.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Positioned(
          top: 60,
          left: -60,
          child: Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: AppColors.blue.withOpacity(0.06),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Positioned(
          bottom: 100,
          right: -40,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.blue.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Positioned(
          bottom: -40,
          left: 60,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.blue.withOpacity(0.07),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }

  // بناء شريط التطبيق المخصص
  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildBackButton(),
          _buildAppBarTitle(),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  // زر الرجوع
  Widget _buildBackButton() {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(true),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(
          Icons.arrow_back_ios_rounded,
          color: Colors.black87,
          size: 20,
        ),
      ),
    );
  }

  // عنوان شريط التطبيق
  Widget _buildAppBarTitle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.blue.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.business_center_rounded,
              color: AppColors.blue,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            "اختيار الشركة المزوّدة",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  // بناء محتوى الشاشة
  Widget _buildContent() {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // عنوان رئيسي
              _buildMainTitle(),

              const SizedBox(height: 10),

              // وصف
              _buildDescription(),

              const SizedBox(height: 40),

              // قائمة الشركات
              _buildPremiumCompanyList(),

              const SizedBox(height: 30),

              // معلومات الشركة
              _buildCompanyDetails(),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // عنوان رئيسي
  Widget _buildMainTitle() {
    return Text(
      "اختر الشركة المزوّدة",
      style: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: Colors.grey.shade800,
        height: 1.3,
      ),
      textAlign: TextAlign.center,
    );
  }

  // وصف
  Widget _buildDescription() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        "يرجى اختيار الشركة المزودة للخدمة من القائمة أدناه للتمتع بأفضل الخدمات",
        style: TextStyle(
          fontSize: 15,
          color: Colors.grey.shade600,
          height: 1.5,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  // قائمة الشركات المزودة بتصميم حصري
  Widget _buildPremiumCompanyList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            spreadRadius: 2,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            // عنوان القائمة
            _buildListTitle(),

            // عناصر القائمة
            _buildCompanyListItems(),
          ],
        ),
      ),
    );
  }

  // عنوان القائمة
  Widget _buildListTitle() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.blue.withOpacity(0.03),
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.shade100,
            width: 1,
          ),
        ),
      ),
      child: Center(
        child: Text(
          "الشركات المزودة للخدمة",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.blue,
          ),
        ),
      ),
    );
  }

  // عناصر القائمة
  Widget _buildCompanyListItems() {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: availableCompanies.length,
      separatorBuilder: (_, __) => Divider(
        color: Colors.grey.shade100,
        height: 1,
        indent: 80,
        endIndent: 20,
      ),
      itemBuilder: (context, index) {
        final company = availableCompanies[index];
        final isSelected = company.name == _selectedCompany;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              if (!isSelected) {
                _saveSelectedCompany(company.name);
              } else {
                // إذا كانت الشركة المختارة بالفعل، انتقل مباشرة إلى الصفحة التالية
                Navigator.of(context).pop(true);
              }
            },
            child: Container(
              color: isSelected ? AppColors.blue.withOpacity(0.05) : null,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: [
                  Icon(
                    Icons.radio_button_checked,
                    color: isSelected ? AppColors.blue : Colors.grey.shade400,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          company.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        if (company.description != null)
                          Text(
                            company.description!,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // إضافة أيقونة السهم لتوضيح أن النقر سينتقل للصفحة التالية
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: isSelected ? AppColors.blue : Colors.grey.shade400,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // معلومات الشركة
  Widget _buildCompanyDetails() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            spreadRadius: 2,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // عنوان القسم
          Text(
            "معلومات الشركة",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 16),

          // معلومات الاتصال
          _buildContactInfo(),
        ],
      ),
    );
  }

  // معلومات الاتصال
  Widget _buildContactInfo() {
    final company = findCompanyByName(_selectedCompany);
    if (company == null) {
      return const Text("لم يتم العثور على معلومات الشركة.");
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildContactItem(
            icon: Icons.dns, title: "عنوان الخادم", value: company.ipAddress),
        if (company.customKey != null)
          _buildContactItem(
              icon: Icons.vpn_key, title: "المفتاح المخصص", value: company.customKey!),
        if (company.description != null)
          _buildContactItem(
              icon: Icons.info, title: "الوصف", value: company.description!),
      ],
    );
  }

  // عنصر معلومات الاتصال
  Widget _buildContactItem({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.blue, size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // رسالة الحالة
  Widget _buildStatusMessage() {
    return Positioned(
      bottom: 20,
      left: 20,
      right: 20,
      child: AnimatedOpacity(
        opacity: _showConnectionStatus ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: _connectionStatus.contains('نجاح')
                ? Colors.green.shade100
                : _connectionStatus.contains('خطأ')
                    ? Colors.red.shade100
                    : Colors.blue.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                _connectionStatus.contains('نجاح')
                    ? Icons.check_circle_outline
                    : _connectionStatus.contains('خطأ')
                        ? Icons.error_outline
                        : Icons.info_outline,
                color: _connectionStatus.contains('نجاح')
                    ? Colors.green.shade800
                    : _connectionStatus.contains('خطأ')
                        ? Colors.red.shade800
                        : Colors.blue.shade800,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _connectionStatus,
                  style: TextStyle(
                    color: _connectionStatus.contains('نجاح')
                        ? Colors.green.shade800
                        : _connectionStatus.contains('خطأ')
                            ? Colors.red.shade800
                            : Colors.blue.shade800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}